#!/usr/bin/env bash
# cz - interactive conventional commit builder

set -euo pipefail

# Option parsing (runtime: uses getoptions, bundle: inlines generated parser)
# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
. ./options.sh
eval "$(getoptions parser_definition parse)"
# @bundle end

# @bundle source
. ./cmd_parse.sh
# @bundle source
. ./cmd_init.sh
# @bundle source
. ./cmd_hook.sh
# @bundle source
. ./cmd_lint.sh
# @bundle source
. ./cmd_create.sh

# Parse global options
parse "$@" || exit 2
eval "set -- $REST"

# Get subcommand (default based on TTY)
if [[ $# -gt 0 ]]; then
	cmd=$1
	shift
else
	# Default: create if TTY, lint if stdin
	if [[ -t 0 ]]; then
		cmd=create
	else
		cmd=lint
	fi
fi

# Dispatch to subcommand
case $cmd in
	parse)
		cmd_parse
		;;
	create)
		# @bundle cmd gengetoptions parser -f ./options.sh parser_definition_create parse_create
		eval "$(getoptions parser_definition_create parse_create)"
		# @bundle end
		parse_create "$@" || exit 2
		eval "set -- $REST"
		cmd_create
		;;
	lint)
		# @bundle cmd gengetoptions parser -f ./options.sh parser_definition_lint parse_lint
		eval "$(getoptions parser_definition_lint parse_lint)"
		# @bundle end
		parse_lint "$@" || exit 2
		eval "set -- $REST"
		cmd_lint
		;;
	init)
		# @bundle cmd gengetoptions parser -f ./options.sh parser_definition_init parse_init
		eval "$(getoptions parser_definition_init parse_init)"
		# @bundle end
		parse_init "$@" || exit 2
		eval "set -- $REST"
		cmd_init
		;;
	hook)
		# @bundle cmd gengetoptions parser -f ./options.sh parser_definition_hook parse_hook
		eval "$(getoptions parser_definition_hook parse_hook)"
		# @bundle end
		parse_hook "$@" || exit 2
		eval "set -- $REST"
		cmd_hook "$@"
		;;
	--)
		# No subcommand, just arguments
		;;
	*)
		echo "cz: unknown command '$cmd'" >&2
		exit 2
		;;
esac
