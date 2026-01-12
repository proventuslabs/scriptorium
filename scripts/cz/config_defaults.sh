# shellcheck shell=bash

# Format current config as .gitcommitizen file content (INI format)
# Requires: TYPES, DESCRIPTIONS arrays to be set
format_config() {
	echo "# Conventional Commits configuration"
	echo "# See: gitcommitizen(5)"
	echo
	echo "[settings]"
	echo "# strict = false"
	echo "# multi-scope = false"
	echo "# multi-scope-separator = ,"
	echo
	echo "[scopes]"
	echo "# Define scopes and their file patterns"
	echo "# example = src/example/**"
	echo
	echo "[types]"
	for i in "${!TYPES[@]}"; do
		echo "${TYPES[$i]} = ${DESCRIPTIONS[$i]}"
	done
}

# Load default Conventional Commits (Angular) configuration
# Sets arrays: TYPES, DESCRIPTIONS, GLOBAL_SCOPES, SCOPES, CFG_TYPE_NAMES, CFG_SCOPE_NAMES
default_config() {
	# Initialize arrays with Angular/Conventional Commits standard types
	export TYPES=(
		"feat"
		"fix"
		"docs"
		"style"
		"refactor"
		"perf"
		"test"
		"build"
		"ci"
		"chore"
		"revert"
	)

	export DESCRIPTIONS=(
		"A new feature"
		"A bug fix"
		"Documentation only changes"
		"Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)"
		"A code change that neither fixes a bug nor adds a feature"
		"A code change that improves performance"
		"Adding missing tests or correcting existing tests"
		"Changes that affect the build system or external dependencies (example scopes: gulp, broccoli, npm)"
		"Changes to our CI configuration files and scripts (example scopes: Travis, Circle, BrowserStack, SauceLabs)"
		"Other changes that don't modify src or test files"
		"Reverts a previous commit"
	)

	# No global scopes by default
	export GLOBAL_SCOPES=()

	# No type-specific scopes by default
	export SCOPES=()
	for _ in "${!TYPES[@]}"; do
		SCOPES+=("")
	done

	# Set CFG_ arrays for compatibility with parse_config consumers
	# shellcheck disable=SC2034 # used by config.sh consumers
	CFG_TYPE_NAMES=("${TYPES[@]}")
	# shellcheck disable=SC2034 # used by config.sh consumers
	CFG_SCOPE_NAMES=()

	return 0
}
