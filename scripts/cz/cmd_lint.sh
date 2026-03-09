# shellcheck shell=bash disable=SC2034

# cz lint - validate a commit message from stdin

# @bundle source
. ./config.sh
# @bundle source
. ./path_validator.sh

_scope_err() {
	_err scope-enum "$1"
	_hint "Defined scopes: ${!CFG_SCOPES[*]}"
}
_show_errors() {
	local e
	for e in "$@"; do _hint "  $e"; done
}

# Check all scopes in a multi-scope string exist
# Usage: _check_scopes_exist <scope_str>
# Sets: _scopes array (trimmed scope names)
_check_scopes_exist() {
	local IFS=","
	local s
	read -ra _scopes <<<"$1"
	for s in "${_scopes[@]}"; do
		_trim s
		[[ "$s" == "*" ]] && continue
		[[ -v CFG_SCOPES["$s"] ]] || {
			_scope_err "$s"
			return 1
		}
	done
}

cmd_lint() {
	local message
	message="$(cat)"

	[[ -z "$message" ]] && {
		_err empty-message
		return 1
	}

	# Load config if not already loaded
	ensure_config

	# Parse first line: type[(scope)][!]: description
	local first_line="${message%%$'\n'*}"
	# Conventional Commits compliant regex (conventionalcommits.org/en/v1.0.0)
	local pattern='^([a-z]+)(\(([a-zA-Z0-9_@/,*-]+)\))?(!)?: (.+)$'

	if [[ ! "$first_line" =~ $pattern ]]; then
		# Spec #1: commits MUST be prefixed with a type, followed by colon and space
		_err header-format
		_hint "Expected: <type>[(<scope>)][!]: <description>"
		return 1
	fi

	local type="${BASH_REMATCH[1]}" scope="${BASH_REMATCH[3]}"
	local breaking="${BASH_REMATCH[4]}" description="${BASH_REMATCH[5]}"

	# Validate type
	if [[ ! -v CFG_TYPES["$type"] ]]; then
		_err type-enum "$type"
		_hint "Allowed types: ${!CFG_TYPES[*]}"
		return 1
	fi

	# Spec #5: description MUST immediately follow the colon and space
	[[ -z "$description" || "$description" =~ ^[[:space:]]*$ ]] && {
		_err description-empty
		return 1
	}

	# Determine breaking-footer mode
	if [[ "${BREAKING_FOOTER-unset}" == "1" ]]; then
		breaking_footer=true
	elif [[ "${BREAKING_FOOTER-unset}" == "" ]]; then
		breaking_footer=false
	else
		breaking_footer="${CFG_SETTINGS[breaking_footer]:-true}"
	fi

	# Spec #13: if included in the type/scope prefix, breaking changes MUST
	# be indicated by a BREAKING CHANGE footer
	# Spec #16: BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE
	# Spec #15: BREAKING CHANGE MUST be uppercase
	[[ "$breaking_footer" == "true" && -n "$breaking" && ! "$message" =~ BREAKING[\ -]CHANGE: ]] && {
		_err breaking-footer
		return 1
	}

	# Path validation for INI format with files provided
	validate_paths_if_needed "$scope"
}

# Get list of files to validate
# Usage: get_files_to_validate
# Returns file list (one per line) or empty string
get_files_to_validate() {
	[[ -z "${PATHS:-}" ]] && return
	echo "$PATHS" | tr ' ' '\n' | grep -v '^$'
}

# Check if scope contains multi-scope separator
is_multi_scope() { [[ "$1" == *","* ]]; }

# Validate paths against scope(s) if files provided
# Usage: validate_paths_if_needed <scope>
validate_paths_if_needed() {
	local scope="$1"
	local require_scope defined_scope enforce_patterns multi_scope

	# Determine require-scope mode
	if [[ "${REQUIRE_SCOPE-unset}" == "1" ]]; then
		require_scope=true
	elif [[ "${REQUIRE_SCOPE-unset}" == "" ]]; then
		require_scope=false
	else
		require_scope="${CFG_SETTINGS[require_scope]:-false}"
	fi

	# Determine defined-scope mode
	if [[ "${DEFINED_SCOPE-unset}" == "1" ]]; then
		defined_scope=true
	elif [[ "${DEFINED_SCOPE-unset}" == "" ]]; then
		defined_scope=false
	else
		defined_scope="${CFG_SETTINGS[defined_scope]:-false}"
	fi

	# Determine enforce-patterns mode
	if [[ "${ENFORCE_PATTERNS-unset}" == "1" ]]; then
		enforce_patterns=true
	elif [[ "${ENFORCE_PATTERNS-unset}" == "" ]]; then
		enforce_patterns=false
	else
		enforce_patterns="${CFG_SETTINGS[enforce_patterns]:-false}"
	fi

	# Determine multi-scope mode
	if [[ "${MULTI_SCOPE-unset}" == "1" ]]; then
		multi_scope=true
	elif [[ "${MULTI_SCOPE-unset}" == "" ]]; then
		multi_scope=false
	else
		multi_scope="${CFG_SETTINGS[multi_scope]:-false}"
	fi

	# -r: require scope to be present
	if [[ "$require_scope" == "true" && -z "$scope" ]]; then
		_err scope-required
		return 1
	fi

	# -d: validate scope exists in config (if scope provided)
	if [[ "$defined_scope" == "true" && -n "$scope" ]]; then
		[[ ${#CFG_SCOPES[@]} -eq 0 ]] && {
			_err scope-missing-config "$scope"
			return 1
		}
		if is_multi_scope "$scope"; then
			_check_scopes_exist "$scope" || return 1
		elif [[ "$scope" != "*" && ! -v CFG_SCOPES["$scope"] ]]; then
			_scope_err "$scope"
			return 1
		fi
	fi

	# Early exit if enforce-patterns not enabled
	[[ "$enforce_patterns" != "true" ]] && return 0
	[[ ${#CFG_SCOPES[@]} -eq 0 ]] && return 0
	local -a files=()
	mapfile -t files < <(get_files_to_validate)
	[[ ${#files[@]} -eq 0 ]] && return 0

	# -e: enforce pattern matching
	# No scope provided - check if files match any pattern
	if [[ -z "$scope" ]]; then
		if ! validate_strict_no_scope "${files[@]}"; then
			_err scope-file-required
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
		[[ "$multi_scope" != "true" ]] && {
			_err multi-scope-disabled
			_hint "Use --multi-scope flag or set multi-scope = true in [settings]"
			return 1
		}
		# Validate scopes exist
		_check_scopes_exist "$scope" || return 1
		if ! validate_files_against_scopes "$scope" "${files[@]}"; then
			_err files-scopes-mismatch "$scope"
			_show_errors "${VALIDATION_ERRORS[@]}"
			return 1
		fi
		return 0
	fi

	# Single scope validation
	[[ -v CFG_SCOPES["$scope"] ]] || {
		_scope_err "$scope"
		return 1
	}
	if ! validate_files_against_scope "$scope" "${files[@]}"; then
		_err files-scope-mismatch "$scope"
		_show_errors "${VALIDATION_ERRORS[@]}"
		return 1
	fi
}
