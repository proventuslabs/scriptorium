# shellcheck shell=bash

# Shared helper functions for cz

# Trim leading/trailing whitespace from variable
# Usage: _trim varname
_trim() {
	local v="${!1}"
	v="${v#"${v%%[![:space:]]*}"}"
	printf -v "$1" '%s' "${v%"${v##*[![:space:]]}"}"
}
