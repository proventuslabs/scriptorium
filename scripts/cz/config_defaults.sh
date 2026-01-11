# shellcheck shell=bash

# Format current config as .gitcommitizen file content
# Requires: TYPES, DESCRIPTIONS, GLOBAL_SCOPES arrays to be set
format_config() {
	echo "# Conventional Commits configuration"
	echo "# See: gitcommitizen(5) or https://www.conventionalcommits.org"
	echo

	if ((${#GLOBAL_SCOPES[@]} > 0)); then
		local IFS=','
		echo "# Global scopes (inherited by all types)"
		echo "*||${GLOBAL_SCOPES[*]}"
		echo
	fi

	echo "# Commit types: type|description|scopes"
	for i in "${!TYPES[@]}"; do
		echo "${TYPES[$i]}|${DESCRIPTIONS[$i]}|"
	done
}

# Load default Conventional Commits (Angular) configuration
# Sets arrays: TYPES, DESCRIPTIONS, GLOBAL_SCOPES, SCOPES
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

	return 0
}
