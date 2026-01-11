#!/usr/bin/env bash
# theme - extensible theme orchestrator for shell environments

set -euo pipefail

# Option parsing (runtime: uses getoptions, bundle: inlines generated parser)
# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
. ./options.sh
eval "$(getoptions parser_definition parse)"
# @bundle end

# @bundle source
. ./detect.sh
# @bundle source
. ./discover.sh
# @bundle source
. ./run.sh

# Parse options
parse "$@" || exit 2
eval "set -- $REST"

# Set globals for theme functions
THEME_QUIET="${QUIET:-}"

# Handle flags
if [[ "${DETECT:-}" == "1" ]]; then
	theme_detect "${1:-}"
	printf '%s\n' "$THEME_APPEARANCE"
	exit 0
fi

if [[ "${LIST:-}" == "1" ]]; then
	theme_source_config
	theme_list
	exit 0
fi

# Run main orchestration
theme_run "${1:-}"
