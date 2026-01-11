# shellcheck shell=bash

# Parse INI-style .gitcommitizen configuration from stdin
# Sets variables: INI_SETTINGS_*, INI_SCOPES_*, INI_TYPES_*
# Also sets arrays: INI_SCOPE_NAMES, INI_TYPE_NAMES
parse_ini() {
	# Clear previous state
	unset "${!INI_SETTINGS_@}" "${!INI_SCOPES_@}" "${!INI_TYPES_@}"
	INI_SCOPE_NAMES=()
	INI_TYPE_NAMES=()

	[[ -t 0 ]] && return 0

	local section="" line key value

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and blank lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# Section header
		if [[ "$line" =~ ^\[([a-z]+)\]$ ]]; then
			section="${BASH_REMATCH[1]}"
			continue
		fi

		# Key = value
		if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"

			# Trim whitespace
			key="${key#"${key%%[![:space:]]*}"}"
			key="${key%"${key##*[![:space:]]}"}"
			value="${value#"${value%%[![:space:]]*}"}"
			value="${value%"${value##*[![:space:]]}"}"

			# Normalize key (replace - with _)
			local norm_key="${key//-/_}"

			case "$section" in
				settings)
					declare -g "INI_SETTINGS_$norm_key=$value"
					;;
				scopes)
					declare -g "INI_SCOPES_$key=$value"
					INI_SCOPE_NAMES+=("$key")
					;;
				types)
					declare -g "INI_TYPES_$key=$value"
					INI_TYPE_NAMES+=("$key")
					;;
			esac
		fi
	done
}

# Get setting value with default
# Usage: get_setting <key> [default]
get_setting() {
	local key="${1//-/_}"
	local default="${2:-}"
	local var="INI_SETTINGS_$key"
	echo "${!var:-$default}"
}

# Check if scope exists
# Usage: scope_exists <name>
scope_exists() {
	local var="INI_SCOPES_$1"
	[[ -n "${!var+x}" ]]
}

# Get scope patterns
# Usage: get_scope_patterns <name>
get_scope_patterns() {
	local var="INI_SCOPES_$1"
	echo "${!var:-}"
}

# Check if type exists
# Usage: type_exists <name>
type_exists() {
	local var="INI_TYPES_$1"
	[[ -n "${!var+x}" ]]
}
