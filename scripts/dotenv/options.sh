# shellcheck shell=bash disable=SC2034

# @bundle keep
VERSION=0.1.0 # x-release-please-version

# Initialize defaults
# Helper for array accumulation (used by parser)
append_env_file() {
	ENV_FILES+=("$OPTARG")
}
# @bundle end

parser_definition() {
	# mode:+ enables POSIX-style cumulative flag mode
	setup REST help:usage abbr:true mode:+ -- \
		"Usage: dotenv [options...] command [args...]"
	msg -- '' 'Load environment from .env files and execute command' ''
	msg -- 'Options:'
	param :append_env_file -e --env-file var:FILE init:'ENV_FILES=()' -- ".env file to load (repeatable)"
	flag  EXEC_MODE -x --exec  -- "Replace process with exec"
	flag  STRICT    -s --strict -- "Fail on warnings"
	msg -- ''
	msg -- '  General:'
	flag  QUIET     -q --quiet -- "Suppress warnings"
	disp  :usage    -h --help
	disp  VERSION   -V --version
}
