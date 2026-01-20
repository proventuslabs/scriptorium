# shellcheck shell=bash

# Format current config as .gitcommitizen file content (INI format)
# Requires: CFG_TYPES associative array to be set
format_config() {
	echo "# Conventional Commits configuration"
	echo "# See: gitcommitizen(5)"
	echo
	echo "[settings]"
	echo "# require-scope = false"
	echo "# multi-scope = false"
	echo "# multi-scope-separator = ,"
	echo
	echo "[scopes]"
	echo "# Define scopes and their file patterns"
	echo "# example = src/example/**"
	echo
	echo "[types]"
	local type
	for type in "${!CFG_TYPES[@]}"; do
		echo "$type = ${CFG_TYPES[$type]}"
	done
}

# Load default Conventional Commits (Angular) configuration
# Sets associative arrays: CFG_TYPES, CFG_SCOPES, CFG_SETTINGS
default_config() {
	# Note: =() initialization required for set -u compatibility
	unset CFG_TYPES CFG_SCOPES CFG_SETTINGS
	# shellcheck disable=SC2034 # used by other modules
	declare -gA CFG_SCOPES=() CFG_SETTINGS=()
	declare -gA CFG_TYPES=(
		[feat]="A new feature"
		[fix]="A bug fix"
		[docs]="Documentation only changes"
		[style]="Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)"
		[refactor]="A code change that neither fixes a bug nor adds a feature"
		[perf]="A code change that improves performance"
		[test]="Adding missing tests or correcting existing tests"
		[build]="Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)"
		[ci]="Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)"
		[chore]="Other changes that don't modify src or test files"
		[revert]="Reverts a previous commit"
	)

	return 0
}
