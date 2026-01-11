# shellcheck shell=sh disable=SC2034

# @bundle keep
VERSION=0.1.0 # x-release-please-version
# @bundle end

parser_definition() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz [options...] [command] [arguments...]"
	msg -- '' 'Conventional commit message builder' ''
	msg -- 'Options:'
	param   CONFIG_FILE  -c --config-file -- "Config file path"
	disp    :usage       -h --help
	disp    VERSION         --version

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
	flag    STRICT_SCOPES  -s --strict-scopes -- "Only allow configured scopes"
	disp    :usage         -h --help
}

parser_definition_lint() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz lint [options...]"
	msg -- '' 'Validate a commit message from stdin' ''
	msg -- 'Options:'
	flag    QUIET       -q --quiet      -- "Suppress output, exit status only"
	flag    STAGED      -s --staged     -- "Validate scope against staged files"
	param   FILES       -f --files      -- "Validate scope against specified files"
	flag    STRICT         --strict     -- "Require scope for scoped files"
	flag    NO_STRICT      --no-strict  -- "Allow missing scope (override config)"
	disp    :usage      -h --help
}

parser_definition_init() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz init [options...]"
	msg -- '' 'Generate a starter .gitcommitizen file' ''
	msg -- 'Options:'
	flag    FORCE   -f --force -- "Overwrite existing file"
	disp    :usage  -h --help
}

parser_definition_hook() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz hook [install|uninstall|status]"
	msg -- '' 'Manage the commit-msg git hook' ''
	msg -- 'Options:'
	disp    :usage  -h --help
}
