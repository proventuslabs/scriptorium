# shellcheck shell=bash

# Shared helper functions for cz

# Output helpers - respect QUIET flag
_err() { [[ -n "${QUIET:-}" ]] || echo "cz: error: $1" >&2; }
_hint() { [[ -n "${QUIET:-}" ]] || echo "$1" >&2; }

# Trim leading/trailing whitespace from variable
# Usage: _trim varname
_trim() {
	local v="${!1}"
	v="${v#"${v%%[![:space:]]*}"}"
	printf -v "$1" '%s' "${v%"${v##*[![:space:]]}"}"
}
