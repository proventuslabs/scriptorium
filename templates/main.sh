#!/usr/bin/env bash
# <name> - <description>

set -euo pipefail

# @bundle source
. ./options.sh

# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
eval "$(getoptions parser_definition parse)"
# @bundle end

parse "$@"
eval set -- "$REST"

# TODO: Implement your script here
echo "Hello from <name>!"
