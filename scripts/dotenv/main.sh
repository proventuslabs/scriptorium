#!/usr/bin/env bash
# dotenv - load environment from .env files and execute command

set -euo pipefail

# Option parsing (runtime: uses getoptions, bundle: inlines generated parser)
# @start-kcov-exclude
# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
. ./options.sh
eval "$(getoptions parser_definition parse)"
# @bundle end
# @end-kcov-exclude

# @bundle source
. ./dotenv.sh

# Parse options
parse "$@" || exit 2
eval "set -- $REST"

# Require command
if [[ $# -eq 0 ]]; then
	echo "dotenv: error: command required" >&2
	exit 2
fi

# Default to .env if no -e specified
[[ ${#ENV_FILES[@]} -eq 0 ]] && ENV_FILES=(.env)

# Set globals for dotenv functions
DOTENV_STRICT="$STRICT"
DOTENV_QUIET="$QUIET"
DOTENV_EXEC="$EXEC_MODE"
DOTENV_OVERRIDE="$OVERRIDE"

# Load environment and execute command
dotenv_exec "${#ENV_FILES[@]}" "${ENV_FILES[@]}" "$@"
