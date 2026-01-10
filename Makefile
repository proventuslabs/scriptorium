# Scriptorium Makefile
# A collection of useful shell functions, scripts and utilities targeting Bash 4+

.PHONY: help test-scripts test-utils test test-script build build-man build-bin build-completions build-script clean lint lint-script lint-utils fmt fmt-script fmt-utils new-script

# Directories
SCRIPTS_DIR := scripts
BIN_DIR := bin
MAN_DIR := man
COMPLETIONS_DIR := completions

# Find all script directories with main.sh
SCRIPT_DIRS := $(dir $(wildcard $(SCRIPTS_DIR)/*/main.sh))
SCRIPT_NAMES := $(notdir $(patsubst %/,%,$(SCRIPT_DIRS)))

# Find all adoc files in docs/ subdirectories
ADOC_FILES := $(wildcard $(SCRIPTS_DIR)/*/docs/*.adoc)

# Default target
help:
	@echo "Scriptorium - Shell Script Collection"
	@echo ""
	@echo "Available targets:"
	@echo "  build               - Build all (manpages, binaries, completions)"
	@echo "  build-script NAME=x - Build a specific script"
	@echo "  build-man           - Generate manpages from .adoc files"
	@echo "  build-bin           - Bundle scripts into bin/"
	@echo "  build-completions   - Copy completions to completions/"
	@echo "  clean               - Remove generated files"
	@echo "  test                - Run all tests"
	@echo "  test-scripts        - Run tests for scripts"
	@echo "  test-script NAME=x  - Run tests for a specific script"
	@echo "  test-utils          - Run tests for utils"
	@echo "  lint                - Run shellcheck and check formatting"
	@echo "  lint-script NAME=x  - Lint a specific script"
	@echo "  lint-utils          - Lint utils only"
	@echo "  fmt                 - Format shell scripts with shfmt"
	@echo "  fmt-script NAME=x   - Format a specific script"
	@echo "  fmt-utils           - Format utils only"
	@echo "  new-script NAME=x   - Create a new script from templates"

# Build targets
build: build-man build-bin build-completions

build-man:
	@echo "Generating manpages..."
	@mkdir -p $(MAN_DIR)/man1 $(MAN_DIR)/man5
	@for adoc in $(ADOC_FILES); do \
		filename=$$(basename "$$adoc" .adoc); \
		section=$$(grep -m1 '^= .*([0-9])$$' "$$adoc" | sed 's/.*(\([0-9]\))$$/\1/' || echo "1"); \
		if [ -z "$$section" ]; then section=1; fi; \
		echo "  $$adoc -> $(MAN_DIR)/man$$section/$$filename.$$section"; \
		asciidoctor -b manpage -D $(MAN_DIR)/man$$section "$$adoc"; \
	done

build-bin:
	@echo "Bundling scripts..."
	@mkdir -p $(BIN_DIR)
	@for dir in $(SCRIPT_DIRS); do \
		if [ -f "$${dir}main.sh" ]; then \
			name=$$(basename "$${dir%/}"); \
			echo "  Bundling $$name -> $(BIN_DIR)/$$name"; \
			utils/bundle.sh "$${dir}main.sh" > "$(BIN_DIR)/$$name"; \
			chmod +x "$(BIN_DIR)/$$name"; \
		fi \
	done

build-completions:
	@echo "Copying completions..."
	@mkdir -p $(COMPLETIONS_DIR)/bash $(COMPLETIONS_DIR)/zsh
	@for dir in $(SCRIPT_DIRS); do \
		if [ -d "$${dir}completions" ]; then \
			for f in "$${dir}completions"/*.bash; do \
				[ -f "$$f" ] && cp "$$f" $(COMPLETIONS_DIR)/bash/ && echo "  $$f -> $(COMPLETIONS_DIR)/bash/$$(basename $$f)"; \
			done; \
			for f in "$${dir}completions"/_*; do \
				[ -f "$$f" ] && cp "$$f" $(COMPLETIONS_DIR)/zsh/ && echo "  $$f -> $(COMPLETIONS_DIR)/zsh/$$(basename $$f)"; \
			done; \
		fi \
	done

clean:
	@echo "Cleaning generated files..."
	@rm -rf $(BIN_DIR)/* $(MAN_DIR)/man1/* $(MAN_DIR)/man5/* $(COMPLETIONS_DIR)/bash/* $(COMPLETIONS_DIR)/zsh/*
	@echo "Done."

# Build a specific script: make build-script NAME=cz
build-script:
ifndef NAME
	$(error NAME is required. Usage: make build-script NAME=<script-name>)
endif
	@if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Building $(NAME)..."
	@for adoc in $(SCRIPTS_DIR)/$(NAME)/docs/*.adoc; do \
		[ -f "$$adoc" ] || continue; \
		filename=$$(basename "$$adoc" .adoc); \
		section=$$(grep -m1 '^= .*([0-9])$$' "$$adoc" | sed 's/.*(\([0-9]\))$$/\1/' || echo "1"); \
		[ -z "$$section" ] && section=1; \
		mkdir -p $(MAN_DIR)/man$$section; \
		echo "  $$adoc -> $(MAN_DIR)/man$$section/$$filename.$$section"; \
		asciidoctor -b manpage -D $(MAN_DIR)/man$$section "$$adoc"; \
	done
	@if [ -f "$(SCRIPTS_DIR)/$(NAME)/main.sh" ]; then \
		mkdir -p $(BIN_DIR); \
		echo "  Bundling -> $(BIN_DIR)/$(NAME)"; \
		utils/bundle.sh "$(SCRIPTS_DIR)/$(NAME)/main.sh" > "$(BIN_DIR)/$(NAME)"; \
		chmod +x "$(BIN_DIR)/$(NAME)"; \
	fi
	@if [ -d "$(SCRIPTS_DIR)/$(NAME)/completions" ]; then \
		mkdir -p $(COMPLETIONS_DIR)/bash $(COMPLETIONS_DIR)/zsh; \
		for f in $(SCRIPTS_DIR)/$(NAME)/completions/*.bash; do \
			[ -f "$$f" ] && cp "$$f" $(COMPLETIONS_DIR)/bash/ && echo "  $$f -> $(COMPLETIONS_DIR)/bash/$$(basename $$f)"; \
		done; \
		for f in $(SCRIPTS_DIR)/$(NAME)/completions/_*; do \
			[ -f "$$f" ] && cp "$$f" $(COMPLETIONS_DIR)/zsh/ && echo "  $$f -> $(COMPLETIONS_DIR)/zsh/$$(basename $$f)"; \
		done; \
	fi
	@echo "Done."

# Test targets
test: test-scripts test-utils

test-scripts:
	@echo "Running tests for scripts..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec --shell bash --helperdir scripts --require spec_helper scripts; \
	else \
		echo "ShellSpec not found."; \
		exit 1; \
	fi

test-utils:
	@echo "Running tests for utils..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec --shell bash utils; \
	else \
		echo "ShellSpec not found."; \
		exit 1; \
	fi

# Test a specific script: make test-script NAME=cz
test-script:
ifndef NAME
	$(error NAME is required. Usage: make test-script NAME=<script-name>)
endif
	@if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Running tests for $(NAME)..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec --shell bash --helperdir scripts --require spec_helper $(SCRIPTS_DIR)/$(NAME); \
	else \
		echo "ShellSpec not found."; \
		exit 1; \
	fi

# Lint targets
# Excludes: *_spec.sh (ShellSpec DSL), *options.sh (getoptions DSL alignment)
SHFMT_EXCLUDES := ! -name '*_spec.sh' ! -name '*options.sh'
SHFMT_OPTS := -i 0 -ci
SHELLCHECK_FORMAT ?=

lint:
	@echo "Running shellcheck..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT)
	@echo "Checking formatting with shfmt..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS)
	@echo "All checks passed."

# Lint a specific script: make lint-script NAME=cz
lint-script:
ifndef NAME
	$(error NAME is required. Usage: make lint-script NAME=<script-name>)
endif
	@if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Running shellcheck on $(NAME)..."
	@find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT)
	@echo "Checking formatting with shfmt..."
	@find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS)
	@echo "All checks passed."

lint-utils:
	@echo "Running shellcheck on utils..."
	@find utils/ -name '*.sh' -type f | xargs shellcheck -x -P SCRIPTDIR -S info $(SHELLCHECK_FORMAT)
	@echo "Checking formatting with shfmt..."
	@find utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -d $(SHFMT_OPTS)
	@echo "All checks passed."

fmt:
	@echo "Formatting shell scripts..."
	@find $(SCRIPTS_DIR)/ utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS)
	@echo "Done."

# Format a specific script: make fmt-script NAME=cz
fmt-script:
ifndef NAME
	$(error NAME is required. Usage: make fmt-script NAME=<script-name>)
endif
	@if [ ! -d "$(SCRIPTS_DIR)/$(NAME)" ]; then \
		echo "Error: script '$(NAME)' not found in $(SCRIPTS_DIR)/"; \
		exit 1; \
	fi
	@echo "Formatting $(NAME)..."
	@find $(SCRIPTS_DIR)/$(NAME)/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS)
	@echo "Done."

fmt-utils:
	@echo "Formatting utils..."
	@find utils/ -name '*.sh' -type f $(SHFMT_EXCLUDES) | xargs shfmt -w $(SHFMT_OPTS)
	@echo "Done."

# Create a new script from templates: make new-script NAME=foo
TEMPLATES_DIR := templates

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
	@sed 's/<name>/$(NAME)/g' $(TEMPLATES_DIR)/main.sh > $(SCRIPTS_DIR)/$(NAME)/main.sh
	@sed 's/<name>/$(NAME)/g' $(TEMPLATES_DIR)/options.sh > $(SCRIPTS_DIR)/$(NAME)/options.sh
	@sed 's/<name>/$(NAME)/g; s/<version>/0.1.0/g; s/<description>/TODO: Add description/g' $(TEMPLATES_DIR)/default.nix > $(SCRIPTS_DIR)/$(NAME)/default.nix
	@echo "Created $(SCRIPTS_DIR)/$(NAME)/"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit $(SCRIPTS_DIR)/$(NAME)/main.sh - implement your script"
	@echo "  2. Edit $(SCRIPTS_DIR)/$(NAME)/options.sh - add CLI options"
	@echo "  3. Edit $(SCRIPTS_DIR)/$(NAME)/default.nix - update description"
	@echo "  4. Add component to release-please-config.json"
	@echo "  5. Import script in root flake.nix (add to let block and packages)"
	@echo "  6. Create $(SCRIPTS_DIR)/$(NAME)/docs/$(NAME).adoc for manpage"
	@echo "  7. Create $(SCRIPTS_DIR)/$(NAME)/*_spec.sh for tests"
