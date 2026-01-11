# shellcheck shell=bash

Describe 'cmd_hook'
	Include ./cmd_hook.sh

	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
		git init --quiet
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	Describe 'status'
		It 'shows not installed when no hook exists'
			When call cmd_hook status
			The status should be failure
			The output should equal "Not installed"
		End

		It 'shows installed when cz hook exists'
			mkdir -p .git/hooks
			# shellcheck disable=SC2016 # Single-quoted $1 is intentional - writing literal hook content.
			printf '#!/bin/sh\n# cz-hook\ncz lint <"$1"\n' > .git/hooks/commit-msg
			When call cmd_hook status
			The status should be success
			The output should include "Installed"
		End

		It 'shows other hook when non-cz hook exists'
			mkdir -p .git/hooks
			printf '#!/bin/sh\necho "other hook"\n' > .git/hooks/commit-msg
			When call cmd_hook status
			The status should be failure
			The output should include "Other hook"
		End
	End

	Describe 'install'
		It 'creates commit-msg hook'
			When call cmd_hook install
			The status should be success
			The output should equal "Installed commit-msg hook"
			The file ".git/hooks/commit-msg" should be exist
			The file ".git/hooks/commit-msg" should be executable
		End

		It 'hook contains cz lint command'
			When call cmd_hook install
			The status should be success
			The output should equal "Installed commit-msg hook"
			The contents of file ".git/hooks/commit-msg" should include "cz lint"
		End

		It 'reports already installed if cz hook exists'
			cmd_hook install >/dev/null
			When call cmd_hook install
			The status should be success
			The output should include "already installed"
		End

		It 'errors if other hook exists'
			mkdir -p .git/hooks
			printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
			When call cmd_hook install
			The status should be failure
			The stderr should include "existing commit-msg hook"
		End
	End

	Describe 'uninstall'
		It 'removes cz hook'
			cmd_hook install >/dev/null
			When call cmd_hook uninstall
			The status should be success
			The output should equal "Uninstalled commit-msg hook"
			The file ".git/hooks/commit-msg" should not be exist
		End

		It 'reports no hook when none exists'
			When call cmd_hook uninstall
			The status should be success
			The output should include "no commit-msg hook"
		End

		It 'errors if hook not installed by cz'
			mkdir -p .git/hooks
			printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
			When call cmd_hook uninstall
			The status should be failure
			The stderr should include "not installed by cz"
		End
	End

	Describe 'outside git repo'
		It 'errors when not in git repo'
			rm -rf .git
			When call cmd_hook status
			The status should equal 1
			The stderr should include "not a git repository"
		End
	End
End
