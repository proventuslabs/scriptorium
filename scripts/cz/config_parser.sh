# shellcheck shell=bash

# Parse .gitcommitizen configuration from stdin
# Sets variables: CFG_SETTINGS_*, CFG_SCOPES_*, CFG_TYPES_*
# Also sets arrays: CFG_SCOPE_NAMES, CFG_TYPE_NAMES
parse_config() {
	# Clear previous state
	unset "${!CFG_SETTINGS_@}" "${!CFG_SCOPES_@}" "${!CFG_TYPES_@}"
	CFG_SCOPE_NAMES=()
	CFG_TYPE_NAMES=()

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
					declare -g "CFG_SETTINGS_$norm_key=$value"
					;;
				scopes)
					declare -g "CFG_SCOPES_$key=$value"
					CFG_SCOPE_NAMES+=("$key")
					;;
				types)
					declare -g "CFG_TYPES_$key=$value"
					CFG_TYPE_NAMES+=("$key")
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
	local var="CFG_SETTINGS_$key"
	echo "${!var:-$default}"
}

# Check if scope exists
# Usage: scope_exists <name>
scope_exists() {
	local var="CFG_SCOPES_$1"
	[[ -n "${!var+x}" ]]
}

# Get scope patterns
# Usage: get_scope_patterns <name>
get_scope_patterns() {
	local var="CFG_SCOPES_$1"
	echo "${!var:-}"
}

# Check if type exists
# Usage: type_exists <name>
type_exists() {
	local var="CFG_TYPES_$1"
	[[ -n "${!var+x}" ]]
}
