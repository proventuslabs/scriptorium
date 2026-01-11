# shellcheck shell=bash disable=SC2034

# cz lint - validate a commit message from stdin

# @bundle source
. ./config.sh

cmd_lint() {
	local message
	message="$(cat)"

	if [[ -z "$message" ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: empty commit message" >&2
		return 1
	fi

	# Load config if not already loaded
	if [[ -z "${TYPES+x}" || ${#TYPES[@]} -eq 0 ]]; then
		if [[ -z "${CONFIG_FILE:-}" ]]; then
			find_config || true
		fi
		load_config
	fi

	# Parse first line: type[(scope)][!]: description
	local first_line="${message%%$'\n'*}"
	local pattern='^([a-z]+)(\(([a-zA-Z0-9_@/-]+)\))?(!)?: (.+)$'

	if [[ ! "$first_line" =~ $pattern ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: invalid commit format" >&2
		[[ -z "${QUIET:-}" ]] && echo "Expected: <type>[(scope)]: <description>" >&2
		return 1
	fi

	local type="${BASH_REMATCH[1]}"
	local scope="${BASH_REMATCH[3]}"
	local breaking="${BASH_REMATCH[4]}"
	local description="${BASH_REMATCH[5]}"

	# Validate type
	local type_valid=false
	local type_index=-1
	for i in "${!TYPES[@]}"; do
		if [[ "${TYPES[$i]}" == "$type" ]]; then
			type_valid=true
			type_index=$i
			break
		fi
	done

	if [[ "$type_valid" != true ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: unknown type '$type'" >&2
		[[ -z "${QUIET:-}" ]] && echo "Allowed types: ${TYPES[*]}" >&2
		return 1
	fi

	# Validate scope if present
	if [[ -n "$scope" ]]; then
		local allowed_scopes="${SCOPES[$type_index]}"

		# If scopes are defined for this type, validate against them
		if [[ -n "$allowed_scopes" ]]; then
			local scope_valid=false
			for allowed in $allowed_scopes; do
				if [[ "$allowed" == "$scope" ]]; then
					scope_valid=true
					break
				fi
			done

			if [[ "$scope_valid" != true ]]; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: invalid scope '$scope' for type '$type'" >&2
				[[ -z "${QUIET:-}" ]] && echo "Allowed scopes: $allowed_scopes" >&2
				return 1
			fi
		fi
	fi

	# Validate description is not empty
	if [[ -z "$description" || "$description" =~ ^[[:space:]]*$ ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: description cannot be empty" >&2
		return 1
	fi

	# Validate breaking change has BREAKING CHANGE footer
	if [[ -n "$breaking" ]]; then
		if [[ ! "$message" =~ BREAKING[[:space:]]CHANGE: ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: error: breaking change (!) requires 'BREAKING CHANGE:' footer" >&2
			return 1
		fi
	fi

	return 0
}
