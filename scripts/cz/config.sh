# shellcheck shell=bash

# Find and load .gitcommitizen configuration

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
			echo "cz: error: config file not found: $CONFIG_FILE" >&2
			exit 1
		fi

		parse_config <"$CONFIG_FILE"

		# If no types defined, use default types but preserve settings/scopes
		if [[ ${#CFG_TYPES[@]} -eq 0 ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: warning: no [types] in $CONFIG_FILE, using defaults" >&2
			# Only set default types, preserve parsed settings and scopes
			declare -gA CFG_TYPES=(
				[feat]="A new feature"
				[fix]="A bug fix"
				[docs]="Documentation only changes"
				[style]="Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)"
				[refactor]="A code change that neither fixes a bug nor adds a feature"
				[perf]="A code change that improves performance"
				[test]="Adding missing tests or correcting existing tests"
				[build]="Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)"
				[ci]="Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)"
				[chore]="Other changes that don't modify src or test files"
				[revert]="Reverts a previous commit"
			)
		fi
	else
		default_config
	fi
}
