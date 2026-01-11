# shellcheck shell=bash disable=SC2034

Describe 'cmd_lint'
	Include ./cmd_lint.sh

	# Use default config for most tests
	BeforeEach 'default_config'

	Describe 'valid messages'
		It 'accepts simple type: description'
			Data "feat: add new feature"
			When call cmd_lint
			The status should be success
		End

		It 'accepts type(scope): description'
			Data "fix(api): resolve bug"
			When call cmd_lint
			The status should be success
		End

		It 'accepts breaking change with ! and footer'
			Data
				#|feat!: breaking change
				#|
				#|BREAKING CHANGE: this breaks things
			End
			When call cmd_lint
			The status should be success
		End

		It 'accepts breaking change with scope, ! and footer'
			Data
				#|feat(api)!: breaking change
				#|
				#|BREAKING CHANGE: this breaks things
			End
			When call cmd_lint
			The status should be success
		End

		It 'rejects breaking change with ! but no footer'
			Data "feat!: breaking change"
			When call cmd_lint
			The status should equal 1
			The stderr should include "BREAKING CHANGE:"
		End

		Parameters
			feat fix docs style refactor perf test build ci chore revert
		End
		It "accepts default type: $1"
			Data "$1: description"
			When call cmd_lint
			The status should be success
		End

		It 'accepts multiline messages'
			Data
				#|feat: add feature
				#|
				#|This is the body.
			End
			When call cmd_lint
			The status should be success
		End
	End

	Describe 'invalid messages'
		It 'rejects empty message'
			Data ""
			When call cmd_lint
			The status should be failure
			The stderr should include "empty commit message"
		End

		It 'rejects missing colon'
			Data "feat add feature"
			When call cmd_lint
			The status should be failure
			The stderr should include "invalid commit format"
		End

		It 'rejects missing description after colon'
			Data "feat:"
			When call cmd_lint
			The status should be failure
			The stderr should include "invalid commit format"
		End

		It 'rejects unknown type'
			Data "unknown: some change"
			When call cmd_lint
			The status should be failure
			The stderr should include "unknown type"
		End

		It 'rejects uppercase type'
			Data "FEAT: add feature"
			When call cmd_lint
			The status should be failure
			The stderr should include "invalid commit format"
		End
	End

	Describe 'scope validation'
		It 'accepts valid scope for type'
			TYPES=("feat" "fix")
			DESCRIPTIONS=("Feature" "Fix")
			GLOBAL_SCOPES=()
			SCOPES=("api ui" "core")
			Data "feat(api): add endpoint"
			When call cmd_lint
			The status should be success
		End

		It 'rejects invalid scope for type'
			TYPES=("feat" "fix")
			DESCRIPTIONS=("Feature" "Fix")
			GLOBAL_SCOPES=()
			SCOPES=("api ui" "core")
			Data "feat(core): wrong scope"
			When call cmd_lint
			The status should be failure
			The stderr should include "invalid scope"
		End

		It 'accepts scope for different type'
			TYPES=("feat" "fix")
			DESCRIPTIONS=("Feature" "Fix")
			GLOBAL_SCOPES=()
			SCOPES=("api ui" "core")
			Data "fix(core): fix bug"
			When call cmd_lint
			The status should be success
		End

		It 'allows any scope when no scopes defined'
			TYPES=("feat")
			DESCRIPTIONS=("Feature")
			GLOBAL_SCOPES=()
			SCOPES=("")
			Data "feat(anything): works"
			When call cmd_lint
			The status should be success
		End
	End

	Describe 'quiet mode'
		It 'suppresses output with QUIET'
			QUIET=1
			Data "unknown: bad type"
			When call cmd_lint
			The status should be failure
			The stderr should equal ""
		End
	End
End
