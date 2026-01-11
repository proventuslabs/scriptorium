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

	Describe 'stdout mode (default)'
		It 'prints config to stdout'
			When call cmd_init
			The status should be success
			The output should include "feat"
			The output should include "fix"
		End

		It 'does not create file'
			When call cmd_init
			The status should be success
			The output should include "feat"
			The file ".gitcommitizen" should not be exist
		End
	End

	Describe 'file mode (-o)'
		It 'writes to specified file silently'
			OUTPUT_FILE="custom-config"
			When call cmd_init
			The status should be success
			The output should equal ""
			The file "custom-config" should be exist
			The contents of file "custom-config" should include "feat"
		End

		It 'errors if file exists without -f'
			OUTPUT_FILE=".gitcommitizen"
			touch .gitcommitizen
			When call cmd_init
			The status should be failure
			The stderr should include "already exists"
		End

		It 'overwrites with FORCE set'
			OUTPUT_FILE=".gitcommitizen"
			echo "old content" > .gitcommitizen
			FORCE=1
			When call cmd_init
			The status should be success
			The output should equal ""
			The contents of file ".gitcommitizen" should include "feat"
		End
	End

	Describe 'config content'
		It 'includes feat type in INI format'
			When call cmd_init
			The output should include "feat = A new feature"
		End

		It 'includes fix type in INI format'
			When call cmd_init
			The output should include "fix = A bug fix"
		End

		It 'includes [types] section'
			When call cmd_init
			The output should include "[types]"
		End

		It 'includes [settings] section'
			When call cmd_init
			The output should include "[settings]"
		End

		It 'includes [scopes] section'
			When call cmd_init
			The output should include "[scopes]"
		End

		It 'includes header comment'
			When call cmd_init
			The output should include "# Conventional Commits"
		End
	End
End
