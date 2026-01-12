# Scriptorium Makefile
# A collection of useful shell functions, scripts and utilities targeting Bash 4+

.PHONY: help build install clean test lint fmt new-script

# Directories
SCRIPTS_DIR := scripts
DIST_DIR := dist
TEMPLATES_DIR := templates

# Find all script directories with main.sh
SCRIPT_DIRS := $(dir $(wildcard $(SCRIPTS_DIR)/*/main.sh))
SCRIPT_NAMES := $(notdir $(patsubst %/,%,$(SCRIPT_DIRS)))

# Lint/format excludes and options
SHFMT_EXCLUDES := ! -name '*_spec.sh' ! -name '*options.sh'
SHFMT_OPTS := -i 0 -ci
SHELLCHECK_FORMAT ?=

help:
	@echo "Scriptorium - Shell Script Collection"
	@echo ""
	@echo "Available targets:"
	@echo "  build [NAME=x]         - Build all scripts or a specific one to dist/"
	@echo "  install DESTDIR=x [NAME=y] - Install scripts to DESTDIR"
	@echo "  clean                  - Remove generated files in dist/"
	@echo "  test [NAME=x]          - Run tests (all, or specific script)"
	@echo "  lint [NAME=x]          - Run shellcheck and shfmt check"
	@echo "  fmt [NAME=x]           - Format shell scripts with shfmt"
	@echo "  new-script NAME=x      - Create a new script from templates"

# Build: all scripts or single script
build:
ifdef NAME
	@if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Building $(NAME) -> $(DIST_DIR)/$(NAME)/"
	@mkdir -p $(DIST_DIR)/$(NAME)/bin
	@mkdir -p $(DIST_DIR)/$(NAME)/man/man1 $(DIST_DIR)/$(NAME)/man/man5
	@mkdir -p $(DIST_DIR)/$(NAME)/completions/bash $(DIST_DIR)/$(NAME)/completions/zsh
	@if [ -f "$(SCRIPTS_DIR)/$(NAME)/main.sh" ]; then \
		echo "  Bundling -> $(DIST_DIR)/$(NAME)/bin/$(NAME)"; \
		utils/bundle.sh "$(SCRIPTS_DIR)/$(NAME)/main.sh" > "$(DIST_DIR)/$(NAME)/bin/$(NAME)"; \
		chmod +x "$(DIST_DIR)/$(NAME)/bin/$(NAME)"; \
	fi
	@for adoc in $(SCRIPTS_DIR)/$(NAME)/docs/*.adoc; do \
		[ -f "$$adoc" ] || continue; \
		filename=$$(basename "$$adoc" .adoc); \
		section=$$(grep -m1 '^= .*([0-9])$$' "$$adoc" | sed 's/.*(\([0-9]\))$$/\1/' || echo "1"); \
		[ -z "$$section" ] && section=1; \
		echo "  $$adoc -> $(DIST_DIR)/$(NAME)/man/man$$section/$$filename.$$section"; \
		asciidoctor -b manpage -D $(DIST_DIR)/$(NAME)/man/man$$section "$$adoc"; \
	done
	@if [ -d "$(SCRIPTS_DIR)/$(NAME)/completions" ]; then \
		for f in $(SCRIPTS_DIR)/$(NAME)/completions/*.bash; do \
			[ -f "$$f" ] && cp "$$f" $(DIST_DIR)/$(NAME)/completions/bash/ && echo "  $$f -> $(DIST_DIR)/$(NAME)/completions/bash/$$(basename $$f)"; \
		done; \
		for f in $(SCRIPTS_DIR)/$(NAME)/completions/_*; do \
			[ -f "$$f" ] && cp "$$f" $(DIST_DIR)/$(NAME)/completions/zsh/ && echo "  $$f -> $(DIST_DIR)/$(NAME)/completions/zsh/$$(basename $$f)"; \
		done; \
	fi
else
	@echo "Building all scripts..."
	@for name in $(SCRIPT_NAMES); do \
		$(MAKE) --no-print-directory build NAME=$$name; \
	done
	@echo "Done."
endif

# Install: all scripts or single script to DESTDIR
install:
ifndef DESTDIR
	$(error DESTDIR is required. Usage: make install DESTDIR=<path> [NAME=<script>])
endif
ifdef NAME
	@$(MAKE) --no-print-directory build NAME=$(NAME)
	@echo "Installing $(NAME) to $(DESTDIR)..."
	@mkdir -p $(DESTDIR)/bin
	@mkdir -p $(DESTDIR)/share/man/man1 $(DESTDIR)/share/man/man5
	@mkdir -p $(DESTDIR)/share/bash-completion/completions
	@mkdir -p $(DESTDIR)/share/zsh/site-functions
	@install -m755 $(DIST_DIR)/$(NAME)/bin/* $(DESTDIR)/bin/
	@for section in 1 5; do \
		if [ -d "$(DIST_DIR)/$(NAME)/man/man$$section" ] && [ -n "$$(ls -A $(DIST_DIR)/$(NAME)/man/man$$section 2>/dev/null)" ]; then \
			install -m644 $(DIST_DIR)/$(NAME)/man/man$$section/* $(DESTDIR)/share/man/man$$section/; \
		fi; \
	done
	@if [ -d "$(DIST_DIR)/$(NAME)/completions/bash" ] && [ -n "$$(ls -A $(DIST_DIR)/$(NAME)/completions/bash 2>/dev/null)" ]; then \
		for f in $(DIST_DIR)/$(NAME)/completions/bash/*.bash; do \
			[ -f "$$f" ] && install -m644 "$$f" "$(DESTDIR)/share/bash-completion/completions/$$(basename "$$f" .bash)"; \
		done; \
	fi
	@if [ -d "$(DIST_DIR)/$(NAME)/completions/zsh" ] && [ -n "$$(ls -A $(DIST_DIR)/$(NAME)/completions/zsh 2>/dev/null)" ]; then \
		install -m644 $(DIST_DIR)/$(NAME)/completions/zsh/_* $(DESTDIR)/share/zsh/site-functions/ 2>/dev/null || true; \
	fi
	@echo "Done."
else
	@$(MAKE) --no-print-directory build
	@echo "Installing to $(DESTDIR)..."
	@mkdir -p $(DESTDIR)/bin
	@mkdir -p $(DESTDIR)/share/man/man1 $(DESTDIR)/share/man/man5
	@mkdir -p $(DESTDIR)/share/bash-completion/completions
	@mkdir -p $(DESTDIR)/share/zsh/site-functions
	@mkdir -p $(DESTDIR)/share/scriptorium
	@for name in $(SCRIPT_NAMES); do \
		if [ -d "$(DIST_DIR)/$$name/bin" ]; then \
			install -m755 $(DIST_DIR)/$$name/bin/* $(DESTDIR)/bin/ 2>/dev/null || true; \
		fi; \
		for section in 1 5; do \
			if [ -d "$(DIST_DIR)/$$name/man/man$$section" ] && [ -n "$$(ls -A $(DIST_DIR)/$$name/man/man$$section 2>/dev/null)" ]; then \
				install -m644 $(DIST_DIR)/$$name/man/man$$section/* $(DESTDIR)/share/man/man$$section/; \
			fi; \
		done; \
		if [ -d "$(DIST_DIR)/$$name/completions/bash" ] && [ -n "$$(ls -A $(DIST_DIR)/$$name/completions/bash 2>/dev/null)" ]; then \
			for f in $(DIST_DIR)/$$name/completions/bash/*.bash; do \
				[ -f "$$f" ] && install -m644 "$$f" "$(DESTDIR)/share/bash-completion/completions/$$(basename "$$f" .bash)"; \
			done; \
		fi; \
		if [ -d "$(DIST_DIR)/$$name/completions/zsh" ] && [ -n "$$(ls -A $(DIST_DIR)/$$name/completions/zsh 2>/dev/null)" ]; then \
			install -m644 $(DIST_DIR)/$$name/completions/zsh/_* $(DESTDIR)/share/zsh/site-functions/ 2>/dev/null || true; \
		fi; \
	done
	@install -m644 scriptorium.plugin.sh $(DESTDIR)/share/scriptorium/
	@install -m644 scriptorium.plugin.zsh $(DESTDIR)/share/scriptorium/
	@echo "Done."
endif

clean:
	@echo "Cleaning generated files..."
	@rm -rf $(DIST_DIR)/*
	@echo "Done."

# Test: all, specific script, or utils
test:
ifdef NAME
	@if [ "$(NAME)" = "utils" ]; then \
		echo "Running tests for utils..."; \
		shellspec --shell bash utils; \
	else \
		if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
			echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
			exit 1; \
		fi; \
		echo "Running tests for $(NAME)..."; \
		shellspec --shell bash --helperdir scripts --require spec_helper $(SCRIPTS_DIR)/$(NAME); \
	fi
else
	@echo "Running all tests..."
	@shellspec --shell bash --helperdir scripts --require spec_helper scripts
	@shellspec --shell bash utils
endif

# Lint: all, specific script, or utils
lint:
ifdef NAME
	@if [ "$(NAME)" = "utils" ]; then \
		echo "Linting utils..."; \
		find utils/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT); \
		find utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS); \
	else \
		if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
			echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
			exit 1; \
		fi; \
		echo "Linting $(NAME)..."; \
		find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT); \
		find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS); \
	fi
	@echo "All checks passed."
else
	@echo "Running shellcheck..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT)
	@echo "Checking formatting with shfmt..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS)
	@echo "All checks passed."
endif

# Format: all, specific script, or utils
fmt:
ifdef NAME
	@if [ "$(NAME)" = "utils" ]; then \
		echo "Formatting utils..."; \
		find utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS); \
	else \
		if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
			echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
			exit 1; \
		fi; \
		echo "Formatting $(NAME)..."; \
		find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS); \
	fi
	@echo "Done."
else
	@echo "Formatting shell scripts..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS)
	@echo "Done."
endif

# Create a new script from templates
new-script:
ifndef NAME
	$(error NAME is required. Usage: make new-script NAME=<script-name>)
endif
	@if [ -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' already exists in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Creating new script: $(NAME)"
	@mkdir -p $(SCRIPTS_DIR)/$(NAME)/docs $(SCRIPTS_DIR)/$(NAME)/completions
	@sed 's|<name>|$(NAME)|g' $(TEMPLATES_DIR)/main.sh > $(SCRIPTS_DIR)/$(NAME)/main.sh
	@sed 's|<name>|$(NAME)|g' $(TEMPLATES_DIR)/options.sh > $(SCRIPTS_DIR)/$(NAME)/options.sh
	@sed 's|<name>|$(NAME)|g; s|<version>|0.1.0|g; s|<description>|TODO: Add description|g' $(TEMPLATES_DIR)/default.nix > $(SCRIPTS_DIR)/$(NAME)/default.nix
	@NAME_UPPER=$$(echo $(NAME) | tr '[:lower:]' '[:upper:]'); \
		sed "s|<name>|$(NAME)|g; s|<NAME>|$$NAME_UPPER|g; s|<description>|TODO: Add description|g" $(TEMPLATES_DIR)/docs/command.adoc > $(SCRIPTS_DIR)/$(NAME)/docs/$(NAME).adoc
	@sed 's|<name>|$(NAME)|g' $(TEMPLATES_DIR)/completions/command.bash > $(SCRIPTS_DIR)/$(NAME)/completions/$(NAME).bash
	@sed 's|<name>|$(NAME)|g' $(TEMPLATES_DIR)/completions/_command > $(SCRIPTS_DIR)/$(NAME)/completions/_$(NAME)
	@sed 's|<name>|$(NAME)|g' $(TEMPLATES_DIR)/main_spec.sh > $(SCRIPTS_DIR)/$(NAME)/main_spec.sh
	@echo "Created $(SCRIPTS_DIR)/$(NAME)/"
	@echo ""
	@echo "See CONTRIBUTING.md for next steps."
