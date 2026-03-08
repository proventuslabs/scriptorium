# shellcheck shell=sh disable=SC2034,SC1083

# @bundle keep
VERSION=0.1.0 # x-release-please-version
# @bundle end

parser_definition() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz [options...] [command] [arguments...]"
	msg -- '' 'Conventional commit message builder' ''
	msg -- 'Options:'
	param   CONFIG_FILE      -c --config-file var:FILE -- "Config file path"
	flag    REQUIRE_SCOPE    -r --{no-}require-scope    init:@unset -- "Require scope to be present"
	flag    DEFINED_SCOPE    -d --{no-}defined-scope    init:@unset -- "Scope must exist in [scopes]"
	flag    ENFORCE_PATTERNS -e --{no-}enforce-patterns init:@unset validate:'DEFINED_SCOPE=1' -- "Scope must match file patterns (implies -d)"
	flag    MULTI_SCOPE      -m --{no-}multi-scope      init:@unset -- "Allow multiple scopes like feat(api,db):"
	flag    BREAKING_FOOTER      --{no-}breaking-footer  init:@unset -- "Require BREAKING CHANGE footer when ! is used"
	flag    QUIET            -q --quiet       -- "Suppress warnings and non-essential output"
	disp    :usage           -h --help
	disp    VERSION          -V --version

	msg -- '' 'Commands:'
	cmd create -- "Compose a commit message interactively"
	cmd lint   -- "Validate a commit message from stdin"
	cmd parse  -- "Display resolved configuration"
	cmd init   -- "Generate a starter .gitcommitizen file"
	cmd hook   -- "Manage the commit-msg git hook"
}

parser_definition_create() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz create [options...]"
	msg -- '' 'Compose a commit message interactively' ''
	msg -- 'Options:'
	disp    :usage           -h --help
}

parser_definition_lint() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz lint [options...]"
	msg -- '' 'Validate a commit message from stdin' ''
	msg -- 'Options:'
	param   PATHS   -p --paths  -- "Validate scope against file paths (space-separated)"
	disp    :usage  -h --help
}

parser_definition_init() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz init [options...]"
	msg -- '' 'Generate a starter .gitcommitizen file' ''
	msg -- 'Options:'
	param   OUTPUT_FILE -o --output -- "Write to file instead of stdout"
	flag    FORCE       -f --force  -- "Overwrite existing file"
	disp    :usage      -h --help
}

parser_definition_hook() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz hook [install|uninstall|status]"
	msg -- '' 'Manage the commit-msg git hook' ''
	msg -- 'Options:'
	disp    :usage  -h --help
}
