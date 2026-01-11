# shellcheck shell=sh disable=SC2034

# @bundle keep
VERSION=0.1.0 # x-release-please-version
# @bundle end

parser_definition() {
	setup   REST help:usage abbr:true -- \
		"Usage: theme [options...] [dark|light]"
	msg -- '' 'Extensible theme orchestrator for shell environments'
	msg -- 'Detects system appearance and applies theme via provider/handlers.' ''
	msg -- 'Options:'
	flag    DETECT     --detect  -- "Only detect appearance, do not run handlers"
	flag    LIST       --list    -- "List discovered provider and handlers"
	msg -- ''
	msg -- '  General:'
	flag    QUIET   -q --quiet -- "Suppress warnings"
	disp    :usage  -h --help
	disp    VERSION    --version
}
