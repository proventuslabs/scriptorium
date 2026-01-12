# shellcheck shell=bash

# Find and load .gitcommitizen configuration

# @bundle source
. ./config_defaults.sh
# @bundle source
. ./config_parser.sh
# Sets: TYPES, DESCRIPTIONS, SCOPES, GLOBAL_SCOPES, CONFIG_FILE

# Ensure config is loaded (idempotent)
ensure_config() {
	[[ -n "${TYPES+x}" && ${#TYPES[@]} -gt 0 ]] && return
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
			echo "cz: error: config file not found: $CONFIG_FILE" >&2
			exit 1
		fi

		parse_config <"$CONFIG_FILE"

		# If no types defined, fall back to defaults
		if [[ ${#CFG_TYPE_NAMES[@]} -eq 0 ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: warning: no [types] in $CONFIG_FILE, using defaults" >&2
			default_config
			return
		fi

		# Build TYPES/DESCRIPTIONS arrays from parsed config
		TYPES=()
		DESCRIPTIONS=()
		SCOPES=()
		GLOBAL_SCOPES=()
		for type in "${CFG_TYPE_NAMES[@]}"; do
			TYPES+=("$type")
			local desc_var="CFG_TYPES_$type"
			DESCRIPTIONS+=("${!desc_var:-}")
			SCOPES+=("")
		done
	else
		default_config
	fi
}
