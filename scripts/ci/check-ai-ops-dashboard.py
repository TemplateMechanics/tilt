#!/usr/bin/env python3
"""Keep the AI Ops dashboard useful without recurring query cancellation.

The dashboard deliberately reviews every namespace over a shared one-hour
window. Automatically re-running that query fan-out caused Grafana to cancel
still-pending Loki requests, producing error-level observability noise on an
otherwise healthy cluster. This check keeps refresh manual while preserving
the broad training view and its namespace guardrail.
"""
import json
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")


DEFAULT_DASHBOARD = "helm/prometheus/dashboards/ai-ops-logs.yaml"
CONFIG_MAP = "grafana-dashboard-ai-ops-logs"
DATA_KEY = "ai-ops-logs.json"
NAMESPACE_SELECTOR = '{namespace=~"$namespace"}'


def fail(errors, message):
    errors.append(message)


def load_dashboard(path, errors):
    try:
        with open(path, encoding="utf-8") as fh:
            docs = [doc for doc in yaml.safe_load_all(fh) if isinstance(doc, dict)]
    except (OSError, yaml.YAMLError) as exc:
        fail(errors, "%s could not be parsed: %s" % (path, exc))
        return None

    matches = [doc for doc in docs if doc.get("kind") == "ConfigMap"
               and (doc.get("metadata") or {}).get("name") == CONFIG_MAP]
    if len(matches) != 1:
        fail(errors, "expected exactly one ConfigMap named %s; found %d"
             % (CONFIG_MAP, len(matches)))
        return None

    raw = (matches[0].get("data") or {}).get(DATA_KEY)
    if not isinstance(raw, str):
        fail(errors, "%s data must contain the string %s" % (CONFIG_MAP, DATA_KEY))
        return None
    try:
        dashboard = json.loads(raw)
    except json.JSONDecodeError as exc:
        fail(errors, "%s contains invalid JSON: %s" % (DATA_KEY, exc))
        return None
    if not isinstance(dashboard, dict):
        fail(errors, "%s must decode to a JSON object" % DATA_KEY)
        return None
    return dashboard


def panel_targets(panels):
    for panel in panels or []:
        if not isinstance(panel, dict):
            continue
        panel_datasource = panel.get("datasource") or {}
        for target in panel.get("targets") or []:
            if isinstance(target, dict):
                yield panel, target, target.get("datasource") or panel_datasource
        yield from panel_targets(panel.get("panels"))


def validate(dashboard, errors):
    if dashboard.get("uid") != "ai-ops-logs":
        fail(errors, "dashboard uid must be ai-ops-logs")
    if dashboard.get("refresh") != "":
        fail(errors, "dashboard refresh must be empty (manual refresh only)")
    if dashboard.get("time") != {"from": "now-1h", "to": "now"}:
        fail(errors, "dashboard time range must remain now-1h through now")

    variables = (dashboard.get("templating") or {}).get("list") or []
    namespaces = [item for item in variables
                  if isinstance(item, dict) and item.get("name") == "namespace"]
    if len(namespaces) != 1:
        fail(errors, "expected exactly one namespace variable; found %d" % len(namespaces))
    else:
        namespace = namespaces[0]
        if namespace.get("refresh") != 1:
            fail(errors, "namespace variable must refresh on dashboard load only (refresh=1)")
        if namespace.get("includeAll") is not True:
            fail(errors, "namespace variable must retain includeAll=true")
        if namespace.get("allValue") != ".+":
            fail(errors, "namespace variable All value must remain .+")

    loki_targets = 0
    for panel, target, datasource in panel_targets(dashboard.get("panels")):
        if not isinstance(datasource, dict) or datasource.get("type") != "loki":
            continue
        loki_targets += 1
        expression = target.get("expr")
        if not isinstance(expression, str) or NAMESPACE_SELECTOR not in expression:
            fail(errors, "Loki target %s/%s is not scoped by %s"
                 % (panel.get("title", "<untitled>"),
                    target.get("refId", "<no refId>"), NAMESPACE_SELECTOR))
    if loki_targets == 0:
        fail(errors, "dashboard must contain at least one Loki target")

    return loki_targets


def main():
    if len(sys.argv) > 2:
        sys.exit("usage: %s [dashboard-yaml]" % sys.argv[0])
    path = sys.argv[1] if len(sys.argv) == 2 else DEFAULT_DASHBOARD
    errors = []
    dashboard = load_dashboard(path, errors)
    loki_targets = validate(dashboard, errors) if dashboard else 0

    if errors:
        print("FAIL: AI Ops dashboard contract")
        for error in errors:
            print("  - %s" % error)
        return 1

    print("AI Ops dashboard: manual refresh, load-only namespace variable, "
          "%d namespace-scoped Loki targets" % loki_targets)
    return 0


if __name__ == "__main__":
    sys.exit(main())
