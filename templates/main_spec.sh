# shellcheck shell=bash

# BDD tests for <name> - test all behaviors through CLI invocation
#
# Tests the bundled script as users experience it.
# Run `make build NAME=<name>` before running tests.

Describe '<name>'
	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	# Path to the built script
	BIN="${SHELLSPEC_PROJECT_ROOT}/dist/<name>/bin/<name>"

	Describe 'help and version'
		It 'shows help with -h'
			When run script "$BIN" -h
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows version with --version'
			When run script "$BIN" --version
			The status should be success
			The output should match pattern '*.*.*'
		End
	End

	# TODO: Add more behavior tests
End
