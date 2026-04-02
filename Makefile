PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share
APPLICATIONS_DIR = $(SHAREDIR)/applications
ICON_DIR = $(SHAREDIR)/icons/hicolor/scalable/apps
SHELL_INSTALL_DIR = $(SHAREDIR)/quickshell/inir
DOC_DIR = $(SHAREDIR)/doc/inir-shell
SYSTEMD_USER_DIR ?= $(PREFIX)/lib/systemd/user

.PHONY: all build test-local install install-bin install-shell install-systemd install-icon install-desktop install-docs uninstall uninstall-bin uninstall-shell uninstall-systemd uninstall-icon uninstall-desktop uninstall-docs

all: build

build:
	@chmod +x scripts/inir
	@chmod +x scripts/test-local-distribution.sh
	@chmod +x setup
	@find scripts -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} +

test-local: build
	@bash scripts/test-local-distribution.sh

install-bin:
	@install -Dm755 scripts/inir $(BINDIR)/inir

install-shell:
	@mkdir -p $(SHELL_INSTALL_DIR)
	@for file in *.qml; do install -Dm644 "$$file" "$(SHELL_INSTALL_DIR)/$$file"; done
	@while IFS= read -r file; do \
		[ -n "$$file" ] || continue; \
		if [ "$$file" = "setup" ]; then \
			install -Dm755 "$$file" "$(SHELL_INSTALL_DIR)/$$file"; \
		else \
			install -Dm644 "$$file" "$(SHELL_INSTALL_DIR)/$$file"; \
		fi; \
	done < sdata/runtime-root-files.txt
	@while IFS= read -r dir; do \
		[ -n "$$dir" ] || continue; \
		mkdir -p "$(SHELL_INSTALL_DIR)/$$dir"; \
		cp -a "$$dir"/. "$(SHELL_INSTALL_DIR)/$$dir/"; \
	done < sdata/runtime-payload-dirs.txt
	@find $(SHELL_INSTALL_DIR)/scripts -type f \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} +
	@printf '{\n  "version": "%s",\n  "commit": "manual",\n  "installed_at": "%s",\n  "installedAt": "%s",\n  "source": "make-install",\n  "repo_path": "",\n  "repoPath": "",\n  "install_mode": "package-managed",\n  "installMode": "package-managed",\n  "update_strategy": "package-manager",\n  "updateStrategy": "package-manager",\n  "package_manager": "manual",\n  "packageManager": "manual",\n  "package_name": "source-install",\n  "packageName": "source-install",\n  "package_update_hint": "sudo make install",\n  "packageUpdateHint": "sudo make install"\n}\n' "$$(cat VERSION)" "$$(date -Iseconds)" "$$(date -Iseconds)" > $(SHELL_INSTALL_DIR)/version.json

install-systemd:
	@mkdir -p $(SYSTEMD_USER_DIR)
	@sed 's|^ExecStart=.*|ExecStart=$(BINDIR)/inir run --session|' assets/systemd/inir.service > $(SYSTEMD_USER_DIR)/inir.service
	@chmod 644 $(SYSTEMD_USER_DIR)/inir.service

install-icon:
	@install -Dm644 assets/icons/desktop-symbolic.svg $(ICON_DIR)/inir.svg
	@gtk-update-icon-cache -q $(SHAREDIR)/icons/hicolor 2>/dev/null || true

install-desktop:
	@install -Dm644 assets/applications/inir.desktop $(APPLICATIONS_DIR)/inir.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true

install-docs:
	@install -Dm644 README.md $(DOC_DIR)/README.md
	@install -Dm644 docs/SETUP.md $(DOC_DIR)/SETUP.md
	@install -Dm644 docs/IPC.md $(DOC_DIR)/IPC.md

install: build install-bin install-shell install-systemd install-icon install-desktop install-docs

uninstall-bin:
	@rm -f $(BINDIR)/inir

uninstall-shell:
	@rm -rf $(SHELL_INSTALL_DIR)

uninstall-systemd:
	@rm -f $(SYSTEMD_USER_DIR)/inir.service

uninstall-icon:
	@rm -f $(ICON_DIR)/inir.svg
	@gtk-update-icon-cache -q $(SHAREDIR)/icons/hicolor 2>/dev/null || true

uninstall-desktop:
	@rm -f $(APPLICATIONS_DIR)/inir.desktop
	@update-desktop-database -q $(APPLICATIONS_DIR) 2>/dev/null || true

uninstall-docs:
	@rm -rf $(DOC_DIR)

uninstall: uninstall-systemd uninstall-desktop uninstall-icon uninstall-docs uninstall-shell uninstall-bin
