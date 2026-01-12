# shellcheck shell=bash

# Parse .gitcommitizen configuration from stdin
# Sets associative arrays: CFG_TYPES, CFG_SCOPES, CFG_SETTINGS
parse_config() {
	CFG_TYPES=()
	CFG_SCOPES=()
	CFG_SETTINGS=()

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

			case "$section" in
				settings)
					# Normalize key (replace - with _)
					CFG_SETTINGS["${key//-/_}"]="$value"
					;;
				scopes)
					CFG_SCOPES["$key"]="$value"
					;;
				types)
					CFG_TYPES["$key"]="$value"
					;;
			esac
		fi
	done
}
