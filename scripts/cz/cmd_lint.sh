# shellcheck shell=bash disable=SC2034

# cz lint - validate a commit message from stdin

# @bundle source
. ./config.sh
# @bundle source
. ./path_validator.sh

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
	local pattern='^([a-z]+)(\(([a-zA-Z0-9_@/,*-]+)\))?(!)?: (.+)$'

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

	# Path validation for INI format with files provided
	if ! validate_paths_if_needed "$scope"; then
		return 1
	fi

	return 0
}

# Get list of files to validate
# Usage: get_files_to_validate
# Returns file list or empty string
get_files_to_validate() {
	if [[ -n "${FILES:-}" ]]; then
		echo "$FILES"
	elif [[ -n "${STAGED:-}" ]]; then
		git diff --cached --name-only 2>/dev/null
	fi
}

# Check if scope contains multi-scope separator
# Usage: is_multi_scope <scope>
is_multi_scope() {
	local scope="$1"
	local separator
	separator="$(get_setting multi-scope-separator ",")"
	[[ "$scope" == *"$separator"* ]]
}

# Validate paths against scope(s) if INI format and files provided
# Usage: validate_paths_if_needed <scope>
validate_paths_if_needed() {
	local scope="$1"
	local files_str
	local multi_scope_enabled strict_mode

	# Only validate for INI format
	[[ "${CONFIG_FORMAT:-}" != "ini" ]] && return 0

	# Get files to validate
	files_str="$(get_files_to_validate)"
	[[ -z "$files_str" ]] && return 0

	# Convert to array
	local -a files=()
	while IFS= read -r file; do
		[[ -n "$file" ]] && files+=("$file")
	done <<<"$files_str"

	[[ ${#files[@]} -eq 0 ]] && return 0

	# Check multi-scope setting
	multi_scope_enabled="$(get_setting multi-scope "false")"

	# Check strict mode (--no-strict overrides --strict overrides config)
	if [[ -n "${NO_STRICT:-}" ]]; then
		strict_mode="false"
	elif [[ -n "${STRICT:-}" ]]; then
		strict_mode="true"
	else
		strict_mode="$(get_setting strict "false")"
	fi

	# If scope provided, validate files against scope(s)
	if [[ -n "$scope" ]]; then
		# Check if multi-scope used
		if is_multi_scope "$scope"; then
			if [[ "$multi_scope_enabled" != "true" ]]; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: multi-scope not enabled in config" >&2
				[[ -z "${QUIET:-}" ]] && echo "Set multi-scope = true in [settings] to use multiple scopes" >&2
				return 1
			fi

			# Validate each scope exists
			local separator
			separator="$(get_setting multi-scope-separator ",")"
			local IFS="$separator"
			read -ra scope_arr <<<"$scope"
			for s in "${scope_arr[@]}"; do
				s="${s#"${s%%[![:space:]]*}"}"
				s="${s%"${s##*[![:space:]]}"}"
				if ! scope_exists "$s" && [[ "$s" != "*" ]]; then
					[[ -z "${QUIET:-}" ]] && echo "cz: error: unknown scope '$s'" >&2
					[[ -z "${QUIET:-}" ]] && echo "Defined scopes: ${INI_SCOPE_NAMES[*]}" >&2
					return 1
				fi
			done

			# Validate files match any of the scopes
			if ! validate_files_against_scopes "$scope" "${files[@]}"; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: files do not match scopes '$scope'" >&2
				for err in "${VALIDATION_ERRORS[@]}"; do
					[[ -z "${QUIET:-}" ]] && echo "  $err" >&2
				done
				return 1
			fi
		else
			# Single scope - validate it exists (unless wildcard)
			if [[ "$scope" != "*" ]] && ! scope_exists "$scope"; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: unknown scope '$scope'" >&2
				[[ -z "${QUIET:-}" ]] && echo "Defined scopes: ${INI_SCOPE_NAMES[*]}" >&2
				return 1
			fi

			# Wildcard scope matches any files
			if [[ "$scope" == "*" ]]; then
				return 0
			fi

			# Validate files match the scope
			if ! validate_files_against_scope "$scope" "${files[@]}"; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: files do not match scope '$scope'" >&2
				for err in "${VALIDATION_ERRORS[@]}"; do
					[[ -z "${QUIET:-}" ]] && echo "  $err" >&2
				done
				return 1
			fi
		fi
	else
		# No scope provided - check strict mode
		if [[ "$strict_mode" == "true" ]]; then
			# Files must NOT match any defined scope
			if ! validate_strict_no_scope "${files[@]}"; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: strict mode requires scope for scoped files" >&2
				for match in "${STRICT_MATCHES[@]}"; do
					[[ -z "${QUIET:-}" ]] && echo "  $match" >&2
				done
				[[ -z "${QUIET:-}" ]] && echo "Hint: add a scope that matches these files" >&2
				return 1
			fi
		fi
	fi

	return 0
}
