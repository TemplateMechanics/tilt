#!/usr/bin/env python3
"""Report HelmRelease charts that are not pinned to an exact version.

Flux re-resolves a version range on every reconcile interval, so a range means
the platform you rebuild in six months is not the platform you built today.
"Destroy and rebuild from empty" then proves that whatever resolves *today*
works, which is a much weaker claim than it looks.

This is not hypothetical here: helm/loki was pinned "loki-stack >=2.10.0", which
quietly resolved to a chart shipping Loki 2.6.1 (built July 2022). It was old
enough that Grafana 13's datasource health probe sent LogQL its parser rejected,
so the datasource sat permanently red while queries still worked.

Exits non-zero only for the unbounded "*". Ranges are reported as warnings so
this can be adopted without a flag day; tighten to failing once they are pinned.
"""
import glob
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

SKIP_SUBSTR = ("/node_modules/", "archive/")


def main():
    unpinned, ranged, pinned = [], [], 0

    for path in glob.glob("helm/**/*.yaml", recursive=True):
        norm = path.replace("\\", "/")
        if any(s in norm for s in SKIP_SUBSTR):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                docs = [d for d in yaml.safe_load_all(fh) if isinstance(d, dict)]
        except Exception:
            continue

        for doc in docs:
            if doc.get("kind") != "HelmRelease":
                continue
            spec = (doc.get("spec") or {}).get("chart", {}).get("spec", {})
            chart, version = spec.get("chart"), spec.get("version")
            if not chart:
                continue
            if version in (None, "*"):
                unpinned.append((chart, version or "<unset>", path))
            elif any(c in str(version) for c in "><~^"):
                ranged.append((chart, version, path))
            else:
                pinned += 1

    print("Chart pinning: %d exact, %d range, %d unpinned" % (pinned, len(ranged), len(unpinned)))

    if ranged:
        print("\nWARN: version ranges re-resolve on every Flux reconcile:")
        for chart, version, path in sorted(ranged):
            print("  %-24s %-14s %s" % (chart, version, path))

    if unpinned:
        print("\nFAIL: unbounded chart versions:")
        for chart, version, path in sorted(unpinned):
            print("  %-24s %-14s %s" % (chart, version, path))
        print("\nPin these to an exact version.")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
