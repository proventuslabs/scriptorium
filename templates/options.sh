#!/usr/bin/env bash
# getoptions parser definition for <name>

# @bundle keep
VERSION=0.1.0 # x-release-please-version
# @bundle end

parser_definition() {
	setup REST help:usage abbr:true -- "Usage: <name> [options]" ''
	msg -- 'Options:'
	disp VERSION --version
	disp :usage -h --help
}
