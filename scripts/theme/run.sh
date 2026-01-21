#!/usr/bin/env bash
# theme orchestration - runs provider and handlers

# @bundle source
. ./detect.sh
# @bundle source
. ./discover.sh

# Warning helper
theme_warn() {
	[[ -n "${THEME_QUIET:-}" ]] && return 0
	echo "theme: warning: $1" >&2
	return 0
}

# Main orchestration function
# Usage: theme_run [--detect|--list|dark|light|auto]
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
		echo "theme: error: no provider found (define a theme_provider_* function)" >&2
		return 1
	fi

	# Detect appearance (with optional override)
	local override=""
	case "${arg,,}" in
		"" | auto)
			# Auto-detect, no override
			;;
		dark | light)
			override="$arg"
			;;
		*)
			echo "theme: error: invalid appearance '$arg' (must be 'dark', 'light', or 'auto')" >&2
			return 1
			;;
	esac

	if ! theme_detect "$override"; then
		return 1
	fi

	# Call provider with appearance and source
	"$THEME_PROVIDER" "$THEME_APPEARANCE" "$THEME_SOURCE"

	# Discover and run handlers
	theme_discover_handlers

	if [[ ${#THEME_HANDLERS[@]} -eq 0 ]]; then
		theme_warn "no handlers found"
	fi

	local handler
	for handler in "${THEME_HANDLERS[@]}"; do
		"$handler" || theme_warn "handler '$handler' failed"
	done

	return 0
}
