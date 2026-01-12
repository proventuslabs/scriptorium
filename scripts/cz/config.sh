# shellcheck shell=bash

# Find and load .gitcommitizen configuration

# @bundle source
. ./config_defaults.sh
# @bundle source
. ./config_parser.sh

# Ensure config is loaded (idempotent)
ensure_config() {
	[[ ${#CFG_TYPES[@]} -gt 0 ]] && return
	[[ -z "${CONFIG_FILE:-}" ]] && { find_config || true; }
	load_config
}

# Find config file by walking up directory tree
# Returns: 0 if found (path in CONFIG_FILE), 1 if not found
find_config() {
	local dir="${1:-$PWD}"

	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.gitcommitizen" ]]; then
			CONFIG_FILE="$dir/.gitcommitizen"
			return 0
		fi
		dir="$(dirname "$dir")"
	done

	CONFIG_FILE=""
	return 1
}

# Load configuration from file or use defaults
# Requires: CONFIG_FILE to be set (empty = use defaults)
load_config() {
	if [[ -n "$CONFIG_FILE" ]]; then
		if [[ ! -f "$CONFIG_FILE" ]]; then
			echo "cz: error: config file not found: $CONFIG_FILE" >&2
			exit 1
		fi

		parse_config <"$CONFIG_FILE"

		# If no types defined, fall back to defaults
		if [[ ${#CFG_TYPES[@]} -eq 0 ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: warning: no [types] in $CONFIG_FILE, using defaults" >&2
			default_config
		fi
	else
		default_config
	fi
}
