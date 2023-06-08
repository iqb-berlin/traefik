TRAEFIK_BASE_DIR := $(shell git rev-parse --show-toplevel)
MK_FILE_DIR := $(TRAEFIK_BASE_DIR)/scripts/make

dev-up:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-down:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-start:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-stop:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-status:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-logs:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-config:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-system-prune:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-volumes-prune:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-volumes-clean:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-images-clean:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@
dev-clean-all:
	$(MAKE) -f $(MK_FILE_DIR)/dev.mk -C $(MK_FILE_DIR) $@

lint-all:
	$(MAKE) -f $(MK_FILE_DIR)/lint.mk -C $(MK_FILE_DIR) $@
lint-json:
	$(MAKE) -f $(MK_FILE_DIR)/lint.mk -C $(MK_FILE_DIR) $@
lint-makefile:
	$(MAKE) -f $(MK_FILE_DIR)/lint.mk -C $(MK_FILE_DIR) $@
lint-shellscript:
	$(MAKE) -f $(MK_FILE_DIR)/lint.mk -C $(MK_FILE_DIR) $@
lint-yaml:
	$(MAKE) -f $(MK_FILE_DIR)/lint.mk -C $(MK_FILE_DIR) $@

traefik-up:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-down:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-start:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-stop:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-status:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-logs:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-config:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-system-prune:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-volumes-prune:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
traefik-images-clean:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@

scan-all:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-traefik:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-prometheus:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-grafana:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
