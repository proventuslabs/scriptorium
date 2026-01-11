# shellcheck shell=bash disable=SC2034
# shellcheck disable=SC2329 # Functions invoked indirectly via ShellSpec BeforeCall

Describe 'cmd_lint'
	Include ./config_parser.sh
	Include ./path_validator.sh
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

	Describe 'path validation'
		# Helper to set up INI config with scopes
		setup_ini_config() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[types]
			feat = New feature
			fix = Bug fix
			[scopes]
			api = src/api/**
			ui = src/ui/**
			EOF
			# Set TYPES array for message validation
			TYPES=("feat" "fix")
			DESCRIPTIONS=("New feature" "Bug fix")
			SCOPES=("" "")
			GLOBAL_SCOPES=()
		}

		setup_ini_with_wildcard() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[types]
			feat = New feature
			[scopes]
			api = src/api/**
			EOF
			# Manually add wildcard scope since bash can't store CFG_SCOPES_*
			CFG_SCOPE_NAMES+=("*")
			TYPES=("feat")
			DESCRIPTIONS=("New feature")
			SCOPES=("")
			GLOBAL_SCOPES=()
		}

		setup_ini_multi_scope() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[settings]
			multi-scope = true
			[types]
			feat = New feature
			[scopes]
			api = src/api/**
			ui = src/ui/**
			EOF
			TYPES=("feat")
			DESCRIPTIONS=("New feature")
			SCOPES=("")
			GLOBAL_SCOPES=()
		}

		setup_ini_multi_scope_disabled() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[settings]
			multi-scope = false
			[types]
			feat = New feature
			[scopes]
			api = src/api/**
			ui = src/ui/**
			EOF
			TYPES=("feat")
			DESCRIPTIONS=("New feature")
			SCOPES=("")
			GLOBAL_SCOPES=()
		}

		setup_ini_strict() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[settings]
			strict = true
			[types]
			feat = New feature
			[scopes]
			api = src/api/**
			ui = src/ui/**
			EOF
			TYPES=("feat")
			DESCRIPTIONS=("New feature")
			SCOPES=("")
			GLOBAL_SCOPES=()
		}

		setup_ini_strict_false() {
			CONFIG_FORMAT="ini"
			parse_config <<-'EOF'
			[settings]
			strict = false
			[types]
			feat = New feature
			[scopes]
			api = src/api/**
			EOF
			TYPES=("feat")
			DESCRIPTIONS=("New feature")
			SCOPES=("")
			GLOBAL_SCOPES=()
		}

		Describe 'files match scope'
			It 'passes when files match the scope'
				BeforeCall setup_ini_config
				FILES="src/api/handler.go
src/api/routes.go"
				Data "feat(api): add endpoint"
				When call cmd_lint
				The status should be success
			End

			It 'fails when files do not match scope'
				BeforeCall setup_ini_config
				FILES="src/ui/button.tsx"
				Data "feat(api): add endpoint"
				When call cmd_lint
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'fails when some files do not match scope'
				BeforeCall setup_ini_config
				FILES="src/api/handler.go
src/ui/button.tsx"
				Data "feat(api): add endpoint"
				When call cmd_lint
				The status should be failure
				The stderr should include "src/ui/button.tsx"
			End
		End

		Describe 'multi-scope validation'
			It 'passes when multi-scope enabled and files match any scope'
				BeforeCall setup_ini_multi_scope
				FILES="src/api/handler.go
src/ui/button.tsx"
				Data "feat(api,ui): cross-cutting change"
				When call cmd_lint
				The status should be success
			End

			It 'fails when multi-scope used but disabled'
				BeforeCall setup_ini_multi_scope_disabled
				FILES="src/api/handler.go"
				Data "feat(api,ui): cross-cutting change"
				When call cmd_lint
				The status should be failure
				The stderr should include "multi-scope not enabled"
			End

			It 'fails when multi-scope used with unknown scope'
				BeforeCall setup_ini_multi_scope
				FILES="src/api/handler.go"
				Data "feat(api,unknown): cross-cutting change"
				When call cmd_lint
				The status should be failure
				The stderr should include "unknown scope"
			End
		End

		Describe 'strict mode'
			It 'fails when no scope but files match scoped paths'
				BeforeCall setup_ini_strict
				FILES="src/api/handler.go"
				Data "feat: add feature"
				When call cmd_lint
				The status should be failure
				The stderr should include "strict mode requires scope"
				The stderr should include "Hint"
			End

			It 'passes when no scope and files match no scoped paths'
				BeforeCall setup_ini_strict
				FILES="other/file.txt"
				Data "feat: add feature"
				When call cmd_lint
				The status should be success
			End

			It '--no-strict overrides config strict=true'
				BeforeCall setup_ini_strict
				NO_STRICT=1
				FILES="src/api/handler.go"
				Data "feat: add feature"
				When call cmd_lint
				The status should be success
			End

			It '--strict overrides config strict=false'
				BeforeCall setup_ini_strict_false
				STRICT=1
				FILES="src/api/handler.go"
				Data "feat: add feature"
				When call cmd_lint
				The status should be failure
				The stderr should include "strict mode requires scope"
			End

			It 'rejects any scope in strict mode when no scopes defined'
				# No scopes defined, just types
				CFG_SCOPE_NAMES=()
				STRICT=1
				Data "feat(anything): add feature"
				When call cmd_lint
				The status should be failure
				The stderr should include "no scopes defined"
			End

			It 'rejects unknown scope in strict mode (no files)'
				BeforeCall setup_ini_strict
				STRICT=1
				Data "feat(unknown): add feature"
				When call cmd_lint
				The status should be failure
				The stderr should include "unknown scope"
			End

			It 'accepts defined scope in strict mode (no files)'
				BeforeCall setup_ini_strict
				STRICT=1
				Data "feat(api): add feature"
				When call cmd_lint
				The status should be success
			End
		End

		Describe 'wildcard scope'
			It 'wildcard scope (*) matches any files'
				BeforeCall setup_ini_with_wildcard
				FILES="any/random/file.txt"
				Data "feat(*): generic change"
				When call cmd_lint
				The status should be success
			End
		End

		Describe 'no path validation without files'
			It 'skips path validation when no files provided'
				BeforeCall setup_ini_config
				Data "feat(api): add endpoint"
				When call cmd_lint
				The status should be success
			End
		End

		Describe 'no scopes defined skips path validation'
			It 'does not validate paths when no scopes configured'
				CFG_SCOPE_NAMES=()
				TYPES=("feat")
				DESCRIPTIONS=("Feature")
				SCOPES=("")
				GLOBAL_SCOPES=()
				FILES="any/file.txt"
				Data "feat(anything): works"
				When call cmd_lint
				The status should be success
			End
		End
	End
End
