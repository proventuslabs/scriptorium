# shellcheck shell=bash disable=SC2034

Describe 'cmd_init'
	Include ./cmd_init.sh

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

	It 'creates .gitcommitizen file'
		When call cmd_init
		The status should be success
		The output should equal "Created .gitcommitizen"
		The file ".gitcommitizen" should be exist
	End

	It 'errors if file exists without -f'
		touch .gitcommitizen
		When call cmd_init
		The status should be failure
		The stderr should include "already exists"
	End

	It 'overwrites with FORCE set'
		echo "old content" > .gitcommitizen
		FORCE=1
		When call cmd_init
		The status should be success
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should not equal "old content"
	End

	It 'creates file with feat type in INI format'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "feat = A new feature"
	End

	It 'creates file with fix type in INI format'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "fix = A bug fix"
	End

	It 'creates file with [types] section'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "[types]"
	End

	It 'creates file with [settings] section'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "[settings]"
	End

	It 'creates file with [scopes] section'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "[scopes]"
	End

	It 'includes usage comments'
		When call cmd_init
		The output should equal "Created .gitcommitizen"
		The contents of file ".gitcommitizen" should include "# Conventional Commits"
	End
End
