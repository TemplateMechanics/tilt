# Thin wrapper over scripts/platform.sh so `make up` works where make exists.
# On Windows Git Bash (no make), call the script directly:
#   ./scripts/platform.sh up
.PHONY: up down reset check ci hello help

help:      ## show targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

up:        ## create the kind cluster if missing, then tilt up
	@./scripts/platform.sh up

down:      ## tilt down (cluster and state remain)
	@./scripts/platform.sh down

reset:     ## destroy the kind cluster and rebuild it empty
	@./scripts/platform.sh reset

check:     ## render every service in a real browser and report
	@./scripts/platform.sh check

ci:        ## run the CI checks locally
	@./scripts/platform.sh ci

hello:     ## deploy examples/hello-world and prove it in a browser
	@./scripts/platform.sh hello
