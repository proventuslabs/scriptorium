# shellcheck shell=bash

# Path validator module for matching files against scope glob patterns

# @bundle source
. ./config_parser.sh

# Check if file matches a glob pattern using bash pattern matching
# Usage: file_matches_pattern <file> <pattern>
file_matches_pattern() {
	local file="$1" pattern="$2"
	# shellcheck disable=SC2053 # pattern should not be quoted
	[[ "$file" == $pattern ]]
}

# Check if file matches any of a scope's patterns
# Usage: file_matches_scope <file> <scope>
file_matches_scope() {
	local file="$1" scope="$2"
	local patterns pattern

	patterns="$(get_scope_patterns "$scope")"
	[[ -z "$patterns" ]] && return 1

	# Split comma-separated patterns and check each
	IFS=',' read -ra pattern_arr <<<"$patterns"
	for pattern in "${pattern_arr[@]}"; do
		# Trim whitespace
		pattern="${pattern#"${pattern%%[![:space:]]*}"}"
		pattern="${pattern%"${pattern##*[![:space:]]}"}"
		file_matches_pattern "$file" "$pattern" && return 0
	done

	return 1
}

# Find which scope a file matches
# Usage: find_matching_scope <file>
# Outputs scope name if found, empty if none
# Skips wildcard scope (*)
find_matching_scope() {
	local file="$1" scope

	for scope in "${CFG_SCOPE_NAMES[@]}"; do
		# Skip wildcard scope
		[[ "$scope" == "*" ]] && continue
		if file_matches_scope "$file" "$scope"; then
			echo "$scope"
			return 0
		fi
	done

	echo ""
	return 1
}

# Validate all files match a scope
# Usage: validate_files_against_scope <scope> <file>...
# Sets VALIDATION_ERRORS array with details on failures
validate_files_against_scope() {
	local scope="$1"
	shift
	local file
	VALIDATION_ERRORS=()

	for file in "$@"; do
		if ! file_matches_scope "$file" "$scope"; then
			VALIDATION_ERRORS+=("$file does not match scope '$scope'")
		fi
	done

	[[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# Validate files match any of multiple scopes
# Usage: validate_files_against_scopes <scope,scope,...> <file>...
# Uses separator from settings (default: ,)
# Sets VALIDATION_ERRORS array on failures
validate_files_against_scopes() {
	local scopes_str="$1"
	shift
	local file scope matched
	local separator
	separator="$(get_setting multi-scope-separator ",")"

	VALIDATION_ERRORS=()

	# Split scopes by separator
	local IFS="$separator"
	read -ra scopes_arr <<<"$scopes_str"

	for file in "$@"; do
		matched=false
		for scope in "${scopes_arr[@]}"; do
			# Trim whitespace
			scope="${scope#"${scope%%[![:space:]]*}"}"
			scope="${scope%"${scope##*[![:space:]]}"}"
			if file_matches_scope "$file" "$scope"; then
				matched=true
				break
			fi
		done
		if [[ "$matched" == false ]]; then
			VALIDATION_ERRORS+=("$file does not match any scope in '$scopes_str'")
		fi
	done

	[[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# For strict mode: files must NOT match any scope
# Usage: validate_strict_no_scope <file>...
# Sets STRICT_MATCHES array with matches found
validate_strict_no_scope() {
	local file scope_match
	STRICT_MATCHES=()

	for file in "$@"; do
		scope_match="$(find_matching_scope "$file")"
		if [[ -n "$scope_match" ]]; then
			STRICT_MATCHES+=("$file matches scope '$scope_match'")
		fi
	done

	[[ ${#STRICT_MATCHES[@]} -eq 0 ]]
}
