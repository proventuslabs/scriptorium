# shellcheck shell=bash

Describe '<name>'
	# Include script functions if needed
	# Include ./<name>.sh

	setup() {
		TEST_DIR=$(mktemp -d)
	}
	cleanup() {
		rm -rf "$TEST_DIR"
	}
	BeforeEach 'setup'
	AfterEach 'cleanup'

	Describe 'basic functionality'
		It 'shows help with -h'
			When run script ./main.sh -h
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows version with --version'
			When run script ./main.sh --version
			The status should be success
			The output should match pattern '*.*.*'
		End
	End

	# TODO: Add more tests
End
