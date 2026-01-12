# shellcheck shell=bash disable=SC2034

# cz lint - validate a commit message from stdin

# @bundle source
. ./config.sh
# @bundle source
. ./path_validator.sh

# Output helpers - respect QUIET flag
_err() { [[ -n "${QUIET:-}" ]] || echo "cz: error: $1" >&2; }
_hint() { [[ -n "${QUIET:-}" ]] || echo "$1" >&2; }
_scope_err() {
	_err "unknown scope '$1'"
	_hint "Defined scopes: ${CFG_SCOPE_NAMES[*]}"
}
_show_errors() {
	local e
	for e in "$@"; do _hint "  $e"; done
}

# Get multi-scope separator
_get_sep() { get_setting multi-scope-separator ","; }

# Check all scopes in a multi-scope string exist
# Usage: _check_scopes_exist <scope_str>
# Sets: _scopes array (trimmed scope names)
_check_scopes_exist() {
	local IFS s
	IFS="$(_get_sep)"
	read -ra _scopes <<<"$1"
	for s in "${_scopes[@]}"; do
		_trim s
		[[ "$s" == "*" ]] && continue
		scope_exists "$s" || {
			_scope_err "$s"
			return 1
		}
	done
}

cmd_lint() {
	local message
	message="$(cat)"

	[[ -z "$message" ]] && {
		_err "empty commit message"
		return 1
	}

	# Load config if not already loaded
	ensure_config

	# Parse first line: type[(scope)][!]: description
	local first_line="${message%%$'\n'*}"
	local pattern='^([a-z]+)(\(([a-zA-Z0-9_@/,*-]+)\))?(!)?: (.+)$'

	if [[ ! "$first_line" =~ $pattern ]]; then
		_err "invalid commit format"
		_hint "Expected: <type>[(scope)]: <description>"
		return 1
	fi

	local type="${BASH_REMATCH[1]}" scope="${BASH_REMATCH[3]}"
	local breaking="${BASH_REMATCH[4]}" description="${BASH_REMATCH[5]}"

	# Validate type
	local type_index=-1
	for i in "${!TYPES[@]}"; do
		[[ "${TYPES[$i]}" == "$type" ]] && {
			type_index=$i
			break
		}
	done

	if [[ $type_index -lt 0 ]]; then
		_err "unknown type '$type'"
		_hint "Allowed types: ${TYPES[*]}"
		return 1
	fi

	# Validate scope if present and scopes defined for this type
	if [[ -n "$scope" && -n "${SCOPES[$type_index]}" ]]; then
		local scope_valid=false allowed
		for allowed in ${SCOPES[$type_index]}; do
			[[ "$allowed" == "$scope" ]] && {
				scope_valid=true
				break
			}
		done
		if [[ "$scope_valid" != true ]]; then
			_err "invalid scope '$scope' for type '$type'"
			_hint "Allowed scopes: ${SCOPES[$type_index]}"
			return 1
		fi
	fi

	# Validate description is not empty
	[[ -z "$description" || "$description" =~ ^[[:space:]]*$ ]] && {
		_err "description cannot be empty"
		return 1
	}

	# Validate breaking change has BREAKING CHANGE footer
	[[ -n "$breaking" && ! "$message" =~ BREAKING[[:space:]]CHANGE: ]] && {
		_err "breaking change (!) requires 'BREAKING CHANGE:' footer"
		return 1
	}

	# Path validation for INI format with files provided
	validate_paths_if_needed "$scope"
}

# Get list of files to validate
# Usage: get_files_to_validate
# Returns file list (one per line) or empty string
get_files_to_validate() {
	[[ -z "${FILES:-}" ]] && return
	echo "$FILES" | tr ' ' '\n' | grep -v '^$'
}

# Check if scope contains multi-scope separator
is_multi_scope() { [[ "$1" == *"$(_get_sep)"* ]]; }

# Validate paths against scope(s) if INI format and files provided
# Usage: validate_paths_if_needed <scope>
validate_paths_if_needed() {
	local scope="$1" strict_mode

	# Determine strict mode (--no-strict > --strict > config)
	if [[ -n "${NO_STRICT:-}" ]]; then
		strict_mode=false
	elif [[ -n "${STRICT:-}" ]]; then
		strict_mode=true
	else strict_mode="$(get_setting strict false)"; fi

	# In strict mode with scope, validate scope exists
	if [[ "$strict_mode" == "true" && -n "$scope" ]]; then
		[[ ${#CFG_SCOPE_NAMES[@]} -eq 0 ]] && {
			_err "scope '$scope' used but no scopes defined in config"
			return 1
		}
		if is_multi_scope "$scope"; then
			_check_scopes_exist "$scope" || return 1
		elif [[ "$scope" != "*" ]] && ! scope_exists "$scope"; then
			_scope_err "$scope"
			return 1
		fi
	fi

	# Early exit if no scopes defined or no files to validate
	[[ ${#CFG_SCOPE_NAMES[@]} -eq 0 ]] && return 0
	local -a files=()
	mapfile -t files < <(get_files_to_validate)
	[[ ${#files[@]} -eq 0 ]] && return 0

	# No scope provided - strict mode check
	if [[ -z "$scope" ]]; then
		[[ "$strict_mode" != "true" ]] && return 0
		if ! validate_strict_no_scope "${files[@]}"; then
			_err "strict mode requires scope for scoped files"
			_show_errors "${STRICT_MATCHES[@]}"
			_hint "Hint: add a scope that matches these files"
			return 1
		fi
		return 0
	fi

	# Wildcard scope matches any files
	[[ "$scope" == "*" ]] && return 0

	# Multi-scope validation
	if is_multi_scope "$scope"; then
		[[ "$(get_setting multi-scope false)" != "true" ]] && {
			_err "multi-scope not enabled in config"
			_hint "Set multi-scope = true in [settings] to use multiple scopes"
			return 1
		}
		_check_scopes_exist "$scope" || return 1
		if ! validate_files_against_scopes "$scope" "${files[@]}"; then
			_err "files do not match scopes '$scope'"
			_show_errors "${VALIDATION_ERRORS[@]}"
			return 1
		fi
		return 0
	fi

	# Single scope validation
	scope_exists "$scope" || {
		_scope_err "$scope"
		return 1
	}
	if ! validate_files_against_scope "$scope" "${files[@]}"; then
		_err "files do not match scope '$scope'"
		_show_errors "${VALIDATION_ERRORS[@]}"
		return 1
	fi
}
