#!/usr/bin/env bash
# theme orchestration - runs provider and handlers

# @bundle source
. ./detect.sh
# @bundle source
. ./discover.sh

# Main orchestration function
# Usage: theme_run [--detect|--list|dark|light]
theme_run() {
	local arg="${1:-}"

	# Handle --detect: only detect and print, no provider/handlers
	if [[ "$arg" == "--detect" ]]; then
		theme_detect
		printf '%s\n' "$THEME_APPEARANCE"
		return 0
	fi

	# Handle --list: list provider and handlers
	if [[ "$arg" == "--list" ]]; then
		theme_list
		return 0
	fi

	# Source user configuration (provider.sh, handlers.d/*.sh)
	theme_source_config

	# Discover provider
	if ! theme_discover_provider; then
		echo "theme: no provider found (define a theme_provider_* function)" >&2
		return 2
	fi

	# Detect appearance (with optional override)
	local override=""
	if [[ "$arg" == "dark" || "$arg" == "light" ]]; then
		override="$arg"
	fi

	if ! theme_detect "$override"; then
		return 1
	fi

	# Call provider with appearance and source
	"$THEME_PROVIDER" "$THEME_APPEARANCE" "$THEME_SOURCE"

	# Discover and run handlers
	theme_discover_handlers

	local handler
	for handler in "${THEME_HANDLERS[@]}"; do
		"$handler"
	done

	return 0
}
