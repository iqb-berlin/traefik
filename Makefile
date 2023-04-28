BASE_DIR := $(shell git rev-parse --show-toplevel)
MK_FILE_DIR := $(BASE_DIR)/scripts/make

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

prod-ramp-up:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-shut-down:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-start:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-stop:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-status:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-logs:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-config:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-system-prune:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-volumes-prune:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@
prod-images-clean:
	$(MAKE) -f $(MK_FILE_DIR)/prod.mk -C $(MK_FILE_DIR) $@

scan-all:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-traefik:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-prometheus:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
scan-grafana:
	$(MAKE) -f $(MK_FILE_DIR)/scan.mk -C $(MK_FILE_DIR) $@
