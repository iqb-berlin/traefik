TRAEFIK_BASE_DIR := $(shell git rev-parse --show-toplevel)

# prevents collisions of make target names with possible file names
.PHONY: lint-all lint-json lint-makefile lint-shellscript lint-yaml

# Run all linters
lint-all: lint-json lint-makefile lint-shellscript lint-yaml

# Run json-file linter
lint-json:
	docker run --rm -it -v $(TRAEFIK_BASE_DIR):/data cytopia/jsonlint:latest *\.json

# Run Makefile linter
lint-makefile:
	docker run --rm -v $(TRAEFIK_BASE_DIR):/data --entrypoint=find\
	  cytopia/checkmake . \( -name 'Makefile' -o -name '*.mk' \) -exec checkmake {} \;

# Run shellscript file linter
lint-shellscript:
	docker run --rm -v $(TRAEFIK_BASE_DIR):/mnt koalaman/shellcheck:stable **/*.sh

# Run yaml-file linter
lint-yaml:
	docker run --rm -it -v $(TRAEFIK_BASE_DIR):/data cytopia/yamllint .
