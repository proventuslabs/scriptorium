#!/usr/bin/env bash
# theme discovery - discovers providers and handlers by function prefix

# XDG config directory
THEME_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/theme"

# Discover provider function by prefix
# Sets THEME_PROVIDER to the first discovered provider function name
theme_discover_provider() {
	THEME_PROVIDER=""

	# Find functions matching theme_provider_* prefix, sorted alphabetically
	# grep returns 1 when no matches, so use || true to handle empty results
	local provider
	provider=$(declare -F | awk '{print $3}' | grep '^theme_provider_' | sort | head -1) || true

	if [[ -n "$provider" ]]; then
		THEME_PROVIDER="$provider"
		return 0
	fi

	return 1
}

# Discover detector functions by prefix
# Sets THEME_DETECTORS array with all discovered detector function names
theme_discover_detectors() {
	THEME_DETECTORS=()

	# Find functions matching theme_detector_* prefix, sorted alphabetically
	# grep returns 1 when no matches, so use || true to handle empty results
	local detectors
	detectors=$(declare -F | awk '{print $3}' | grep '^theme_detector_' | sort) || true

	if [[ -n "$detectors" ]]; then
		while IFS= read -r detector; do
			THEME_DETECTORS+=("$detector")
		done <<<"$detectors"
	fi

	return 0
}

# Discover handler functions by prefix
# Sets THEME_HANDLERS array with all discovered handler function names
theme_discover_handlers() {
	THEME_HANDLERS=()

	# Find functions matching theme_handler_* prefix, sorted alphabetically
	# grep returns 1 when no matches, so use || true to handle empty results
	local handlers
	handlers=$(declare -F | awk '{print $3}' | grep '^theme_handler_' | sort) || true

	if [[ -n "$handlers" ]]; then
		while IFS= read -r handler; do
			THEME_HANDLERS+=("$handler")
		done <<<"$handlers"
	fi

	return 0
}

# Source handler files from a directory
# Usage: theme_source_handlers_dir <directory>
theme_source_handlers_dir() {
	local dir="$1"

	# Handle non-existent directory gracefully
	if [[ ! -d "$dir" ]]; then
		return 0
	fi

	# Source all .sh files in the directory
	local f
	for f in "$dir"/*.sh; do
		if [[ -f "$f" ]]; then
			# shellcheck source=/dev/null
			if ! source "$f" 2>/dev/null; then
				theme_warn "failed to source '$f'"
			fi
		fi
	done

	return 0
}

# Source user configuration files
# Sources: detectors.d/*.sh, config.sh, provider.sh, handlers.d/*.sh
theme_source_config() {
	local config_dir="${1:-$THEME_CONFIG_DIR}"

	# Source detectors first (needed before detection)
	theme_source_handlers_dir "$config_dir/detectors.d"

	# Source user config if exists
	if [[ -f "$config_dir/config.sh" ]]; then
		# shellcheck source=/dev/null
		source "$config_dir/config.sh"
	fi

	# Source custom provider if exists
	if [[ -f "$config_dir/provider.sh" ]]; then
		# shellcheck source=/dev/null
		source "$config_dir/provider.sh"
	fi

	# Source handler files from handlers.d
	theme_source_handlers_dir "$config_dir/handlers.d"

	return 0
}

# List discovered detectors, provider, and handlers
theme_list() {
	theme_discover_detectors
	theme_discover_provider || true
	theme_discover_handlers

	echo "Detectors:"
	if [[ ${#THEME_DETECTORS[@]} -gt 0 ]]; then
		local d
		for d in "${THEME_DETECTORS[@]}"; do
			echo "  $d"
		done
	else
		echo "  (none found)"
	fi

	echo ""
	echo "Provider:"
	if [[ -n "$THEME_PROVIDER" ]]; then
		echo "  $THEME_PROVIDER"
	else
		echo "  (none found)"
	fi

	echo ""
	echo "Handlers:"
	if [[ ${#THEME_HANDLERS[@]} -gt 0 ]]; then
		local h
		for h in "${THEME_HANDLERS[@]}"; do
			echo "  $h"
		done
	else
		echo "  (none found)"
	fi

	return 0
}
