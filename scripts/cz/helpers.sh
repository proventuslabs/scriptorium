# shellcheck shell=bash

# Shared helper functions for cz

# @bundle source
. ./error_codes.sh

# Output helpers - respect QUIET flag
_err() {
	[[ -n "${QUIET:-}" ]] && return
	local code="$1"
	shift
	local msg="${ERR_CODES[$code]}"
	if [[ -n "$msg" ]]; then
		# shellcheck disable=SC2059 # intentional printf format from registry
		printf -v msg "$msg" "$@"
		echo "cz: error: $msg [$code]" >&2
	else
		echo "cz: error: $code $* [unknown]" >&2
	fi
}
_hint() { [[ -n "${QUIET:-}" ]] || echo "$1" >&2; }

# Trim leading/trailing whitespace from variable
# Usage: _trim varname
_trim() {
	local v="${!1}"
	v="${v#"${v%%[![:space:]]*}"}"
	printf -v "$1" '%s' "${v%"${v##*[![:space:]]}"}"
}
