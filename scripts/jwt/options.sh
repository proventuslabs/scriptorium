# shellcheck shell=sh disable=SC2034

# @bundle keep
VERSION=0.1.0 # x-release-please-version
# @bundle end

parser_definition() {
	setup   REST help:usage abbr:true -- \
		"Usage: jwt [options...] [token]"
	msg -- '' 'Decode and verify JSON Web Tokens'
	msg -- 'Reads token from argument or stdin if not provided.' ''
	msg -- 'Options:'
	msg -- '  Output selection (mutually exclusive):'
	flag    OUTPUT  -H --header    init:=payload on:header   -- "Display JWT header"
	flag    OUTPUT  -P --payload                  on:payload -- "Display JWT payload (default)"
	flag    OUTPUT  -S --signature                on:sig     -- "Display raw signature"
	flag    OUTPUT  -A --all                      on:all     -- "Display all parts as JSON"
	msg -- ''
	msg -- '  Verification:'
	param   VERIFY  -k --key -- "Verify signature (secret, @file, or @-/- for stdin)"
	msg -- ''
	msg -- '  General:'
	flag    QUIET   -q --quiet -- "Suppress warnings"
	disp    :usage  -h --help
	disp    VERSION -V --version
}
