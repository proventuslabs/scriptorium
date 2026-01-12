# shellcheck shell=bash

# Path validator module for matching files against scope glob patterns

# @bundle source
. ./helpers.sh
# @bundle source
. ./config_parser.sh

# Check if file matches a glob pattern
# Usage: file_matches_pattern <file> <pattern>
# Handles: * (single segment), ** (recursive), exact match
file_matches_pattern() {
	local file="$1" pattern="$2"

	# Handle special wildcard-only patterns
	[[ "$pattern" == "*" || "$pattern" == "**" ]] && return 0

	# Convert glob pattern to extended regex
	local regex="^"
	local i=0 len=${#pattern}

	while ((i < len)); do
		local char="${pattern:i:1}"
		local next="${pattern:i+1:1}"

		if [[ "$char" == "*" && "$next" == "*" ]]; then
			# ** matches zero or more path segments (including /)
			# Check if followed by /
			if [[ "${pattern:i+2:1}" == "/" ]]; then
				regex+="(.*/)?"
				((i += 3))
			else
				regex+=".*"
				((i += 2))
			fi
		elif [[ "$char" == "*" ]]; then
			# * matches anything except /
			regex+="[^/]*"
			((i++))
		elif [[ "$char" =~ [].[^$+?{}\\|[()] ]]; then
			# Escape regex special chars (] must be first in bracket expr)
			regex+="\\$char"
			((i++))
		else
			regex+="$char"
			((i++))
		fi
	done

	regex+="$"

	[[ "$file" =~ $regex ]]
}

# Check if file matches any of a scope's patterns
# Usage: file_matches_scope <file> <scope>
file_matches_scope() {
	local file="$1" scope="$2" patterns pattern
	patterns="$(get_scope_patterns "$scope")"
	[[ -z "$patterns" ]] && return 1

	IFS=',' read -ra pattern_arr <<<"$patterns"
	for pattern in "${pattern_arr[@]}"; do
		_trim pattern
		file_matches_pattern "$file" "$pattern" && return 0
	done
	return 1
}

# Find which scope a file matches (skips wildcard)
find_matching_scope() {
	local file="$1" scope
	for scope in "${CFG_SCOPE_NAMES[@]}"; do
		[[ "$scope" == "*" ]] && continue
		file_matches_scope "$file" "$scope" && {
			echo "$scope"
			return 0
		}
	done
	return 1
}

# Validate all files match a scope
# Sets VALIDATION_ERRORS array with details on failures
validate_files_against_scope() {
	local scope="$1"
	shift
	VALIDATION_ERRORS=()
	for file in "$@"; do
		file_matches_scope "$file" "$scope" || VALIDATION_ERRORS+=("$file does not match scope '$scope'")
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
	local IFS
	IFS="$(get_setting multi-scope-separator ",")"
	VALIDATION_ERRORS=()

	read -ra scopes_arr <<<"$scopes_str"
	for file in "$@"; do
		matched=false
		for scope in "${scopes_arr[@]}"; do
			_trim scope
			file_matches_scope "$file" "$scope" && {
				matched=true
				break
			}
		done
		[[ "$matched" == false ]] && VALIDATION_ERRORS+=("$file does not match any scope in '$scopes_str'")
	done
	[[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# For strict mode: files must NOT match any scope
# Sets STRICT_MATCHES array with matches found
validate_strict_no_scope() {
	local file scope_match
	STRICT_MATCHES=()
	for file in "$@"; do
		scope_match="$(find_matching_scope "$file")" && STRICT_MATCHES+=("$file matches scope '$scope_match'")
	done
	[[ ${#STRICT_MATCHES[@]} -eq 0 ]]
}
