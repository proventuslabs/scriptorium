# shellcheck shell=bash

# Find and load .gitcommitizen configuration

# @bundle source
. ./helpers.sh
# @bundle source
. ./config_defaults.sh
# @bundle source
. ./config_parser.sh
# Sets associative arrays: CFG_TYPES, CFG_SCOPES, CFG_SETTINGS

# Ensure config is loaded (idempotent)
ensure_config() {
	[[ -n "${CFG_TYPES+x}" && ${#CFG_TYPES[@]} -gt 0 ]] && return
	[[ -z "${CONFIG_FILE:-}" ]] && { find_config || true; }
	load_config
}

# Find config file by walking up directory tree
# Usage: find_config [start_dir]
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
# Usage: load_config
# Requires: CONFIG_FILE to be set (empty = use defaults)
# Exits with error if CONFIG_FILE is set but file doesn't exist
load_config() {
	if [[ -n "$CONFIG_FILE" ]]; then
		if [[ ! -f "$CONFIG_FILE" ]]; then
			_err "config file not found: $CONFIG_FILE"
			exit 1
		fi

		parse_config <"$CONFIG_FILE"

		# If no types defined, use default types but preserve settings/scopes
		if [[ ${#CFG_TYPES[@]} -eq 0 ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: warning: no [types] in $CONFIG_FILE, using defaults" >&2
			_set_default_types
		fi
	else
		default_config
	fi
}
