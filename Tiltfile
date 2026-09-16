###############################################################################
# TILT DEVELOPMENT ENVIRONMENT
#
# This file is a table of contents. Each tier lives in tilt/<tier>.tilt and is
# included only when the selected profile reaches it:
#
#   --profile=minimal        tilt/core.tilt
#   --profile=observability  + tilt/observability.tilt
#   --profile=gitops         + tilt/gitops.tilt
#   --profile=full           + tilt/apps.tilt
#
#   tilt up -- --profile=observability
#   PROFILE=full ./scripts/platform.sh up
#
# Tiers are cumulative and each depends only on the tiers below it, so a lower
# profile is always a strict subset. Shared helpers (sh, CONFIG, PLATFORM, ...)
# are in tilt/lib.tilt and must be load()ed by any tier that uses them —
# include() does not share the root scope.
#
# Configuration for toggleable apps is in tilt-config.json (see tilt/apps.tilt).
###############################################################################

config.define_string("profile", args=False, usage="minimal | observability | gitops | full")
cfg = config.parse()

PROFILES = ["minimal", "observability", "gitops", "full"]
PROFILE = cfg.get("profile", "minimal")
if PROFILE not in PROFILES:
    fail("unknown --profile=%s; expected one of %s" % (PROFILE, ", ".join(PROFILES)))
RANK = PROFILES.index(PROFILE)
print("Profile: %s (%d/%d tiers)" % (PROFILE, RANK + 1, len(PROFILES)))

include("./tilt/core.tilt")
if RANK >= 1:
    include("./tilt/observability.tilt")
if RANK >= 2:
    include("./tilt/gitops.tilt")
if RANK >= 3:
    include("./tilt/apps.tilt")
