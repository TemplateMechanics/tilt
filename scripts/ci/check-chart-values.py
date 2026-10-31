#!/usr/bin/env python3
"""Fail when a pinned chart cannot render, or ignores a value it is given.

Charts accept any values and silently drop the ones they do not read. A key
left over from an older chart version therefore looks exactly like
configuration and does nothing. Every one of these was found by this check:

- policy-reporter set kyvernoPlugin.enabled, the 2.x key. Chart 3.10.0 ignored
  it and the Kyverno plugin was never installed.
- langfuse set postgresql.enabled / clickhouse.enabled / redis.enabled; 1.5.41
  switches on `deploy`. It also set top-level resources the chart never reads,
  so the 1Gi limit they described was never applied.
- opentelemetry-collector 0.98.0 refuses to render without image.repository.
  The release had never installed at all, on any cluster.
- qdrant, dapr, kyverno, flagger, falco and kube-prometheus-stack each carried
  keys their pinned chart does not read.

A value is a CANDIDATE when the chart's defaults (its values.yaml merged with
its subcharts') do not contain its path. A candidate is INERT when rendering
with it removed AND rendering with it changed both give the same manifests as
the original. Removal alone is not enough: a value restating a subchart default
also renders the same without it. Lines that differ between two renders of the
same input (generated passwords, checksums) are ignored.

Pulls every chart, so this needs the network; it is not part of the offline
`platform.sh ci`. Run it with: python scripts/ci/check-chart-values.py
Only helm/ and apps/ are read. Kustomize patches that set values are not
expanded (two exist: metrics-server args, cert-manager servicemonitor.enabled;
both are keys the charts read).
"""
import copy
import glob
import os
import subprocess
import sys
import tarfile
import tempfile

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

SKIP_SUBSTR = ("/node_modules/", "archive/")
# Capabilities the platform provides; without them some charts skip the very
# resources (ServiceMonitors, Gateway routes) whose values are being checked.
RENDER_ARGS = ["--kube-version", "1.36.1",
               "--api-versions", "monitoring.coreos.com/v1",
               "--api-versions", "gateway.networking.k8s.io/v1",
               "--api-versions", "cert-manager.io/v1"]


def inventory():
    repos, releases = {}, []
    for path in sorted(glob.glob("helm/**/*.yaml", recursive=True) + glob.glob("apps/**/*.yaml", recursive=True)):
        norm = path.replace("\\", "/")
        if any(s in norm for s in SKIP_SUBSTR):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                docs = [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]
        except Exception:
            continue
        for d in docs:
            kind, spec = d.get("kind"), d.get("spec") or {}
            if kind == "HelmRepository":
                repos[d["metadata"]["name"]] = spec["url"]
            elif kind == "HelmRelease" and "chart" in spec:
                c = spec["chart"]["spec"]
                releases.append(dict(file=norm, name=d["metadata"]["name"], ns=d["metadata"].get("namespace", "default"),
                                     chart=c["chart"], version=str(c.get("version")), repo=c["sourceRef"]["name"],
                                     values=spec.get("values") or {}))
            elif kind == "DevApplication":
                c = spec["chart"]
                releases.append(dict(file=norm, name=d["metadata"]["name"], ns=spec["name"], chart=c["name"],
                                     version=str(c.get("version")), repo=c["repository"], values=c.get("values") or {}))
    return repos, releases


def run(cmd, env):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)


def deep_merge(base, over):
    # A shallow update was a false positive: langfuse's own
    # postgresql.primary.service replaced the subchart's whole primary block,
    # so primary.persistence looked unknown.
    out = copy.deepcopy(base)
    for k, v in over.items():
        out[k] = deep_merge(out[k], v) if isinstance(out.get(k), dict) and isinstance(v, dict) else v
    return out


def defaults(chart):
    path = os.path.join(chart, "values.yaml")
    vals = (yaml.safe_load(open(path, encoding="utf-8")) or {}) if os.path.exists(path) else {}
    meta = yaml.safe_load(open(os.path.join(chart, "Chart.yaml"), encoding="utf-8"))
    alias = {dep["name"]: dep.get("alias", dep["name"]) for dep in meta.get("dependencies") or []}
    for sub in glob.glob(os.path.join(chart, "charts", "*", "Chart.yaml")):
        name = yaml.safe_load(open(sub, encoding="utf-8"))["name"]
        key = alias.get(name, name)
        sub_defaults = defaults(os.path.dirname(sub))
        if isinstance(vals.get(key), dict):
            vals[key] = deep_merge(sub_defaults, vals[key])
        elif vals.get(key) is None:
            vals[key] = sub_defaults
    return vals


def leaves(v, path=()):
    if isinstance(v, dict) and v:
        for k, x in v.items():
            yield from leaves(x, path + (k,))
    else:
        yield path


def known(dflt, path):
    cur = dflt
    for k in path:
        # Below a scalar, list, null or empty map the chart takes free-form
        # input (podAnnotations: {}, extraArgs: []), so nothing is checkable.
        if not isinstance(cur, dict) or not cur:
            return True
        if k not in cur:
            return False
        cur = cur[k]
    return True


def without(values, path):
    v = copy.deepcopy(values)
    cur = v
    for k in path[:-1]:
        cur = cur[k]
    del cur[path[-1]]
    return v


def changed(values, path):
    v = copy.deepcopy(values)
    cur = v
    for k in path[:-1]:
        cur = cur[k]
    x = cur[path[-1]]
    if isinstance(x, bool):
        x = not x
    elif isinstance(x, (int, float)):
        x = x + 7
    elif isinstance(x, str):
        x = x + "-changed"
    elif isinstance(x, list):
        x = x + ["changed"] if all(isinstance(i, str) for i in x) else []
    else:
        x = "changed"
    cur[path[-1]] = x
    return v


def main():
    repos, releases = inventory()
    work = tempfile.mkdtemp(prefix="chart-values-")
    env = dict(os.environ, **{k: os.path.join(work, "helm", k.lower()) for k in
                              ("HELM_CACHE_HOME", "HELM_CONFIG_HOME", "HELM_DATA_HOME")})
    failures = []

    def render(r, chart, values):
        f = os.path.join(work, "values.yaml")
        with open(f, "w", encoding="utf-8") as fh:
            yaml.safe_dump(values, fh)
        p = run(["helm", "template", r["name"], chart, "-n", r["ns"], "-f", f] + RENDER_ARGS, env)
        return p.stdout if p.returncode == 0 else None, p.stderr.strip()

    for r in releases:
        label = "%s (%s %s, %s)" % (r["name"], r["chart"], r["version"], r["file"])
        dest = os.path.join(work, "charts", "%s-%s" % (r["name"], r["version"]))
        os.makedirs(dest, exist_ok=True)
        p = run(["helm", "pull", r["chart"], "--repo", repos.get(r["repo"], ""), "--version", r["version"],
                 "--untar", "--untardir", dest], env)
        if p.returncode:
            failures.append("%s: could not pull: %s" % (label, p.stderr.strip()[:200]))
            continue
        chart = [x for x in glob.glob(os.path.join(dest, "*")) if os.path.isdir(x)][0]
        for tgz in glob.glob(os.path.join(chart, "charts", "*.tgz")):
            with tarfile.open(tgz) as t:
                t.extractall(os.path.join(chart, "charts"), filter="data")

        base, err = render(r, chart, r["values"])
        if base is None:
            failures.append("%s: does not render, so Flux cannot install it:\n      %s" % (label, err[-300:]))
            continue
        again, _ = render(r, chart, r["values"])
        noisy = {i for i, (x, y) in enumerate(zip(base.splitlines(), again.splitlines())) if x != y}

        def same(out):
            return (out is not None and len(out.splitlines()) == len(base.splitlines())
                    and all(x == y for i, (x, y) in enumerate(zip(out.splitlines(), base.splitlines())) if i not in noisy))

        dflt = defaults(chart)
        inert = [".".join(map(str, p)) for p in leaves(r["values"])
                 if p and not known(dflt, p)
                 and same(render(r, chart, without(r["values"], p))[0])
                 and same(render(r, chart, changed(r["values"], p))[0])]
        if inert:
            failures.append("%s: the chart ignores %s" % (label, ", ".join(inert)))
        print("  ok   %s" % label if not inert else "  FAIL %s" % label, flush=True)

    print("\nChart values: %d releases, %d problem(s)" % (len(releases), len(failures)))
    for f in failures:
        print("FAIL: " + f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
