# shellcheck shell=bash
# shellcheck disable=SC2016 # Single-quoted $1 is intentional in hook content
# BDD tests for cz - all behaviors tested through CLI invocation
#
# This spec tests the script as users experience it: through the CLI.
# All internal implementation details (config_parser, path_validator, etc.)
# are tested implicitly through observable behavior.
#
Describe 'cz'
	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
		git init --quiet
		ORIG_PATH="$PATH"
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
		PATH="$ORIG_PATH"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	cz() {
		"${SHELLSPEC_PROJECT_ROOT}/dist/cz/bin/cz" "$@"
	}

	#═══════════════════════════════════════════════════════════════
	# LINT COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'lint'
		#───────────────────────────────────────────────────────────
		# Valid conventional commits
		#───────────────────────────────────────────────────────────
		Describe 'valid messages'
			It 'accepts type: description'
				Data "feat: add new feature"
				When call cz lint
				The status should be success
			End

			It 'accepts type(scope): description'
				Data "fix(api): resolve null pointer"
				When call cz lint
				The status should be success
			End

			It 'accepts type(scope)!: description with BREAKING CHANGE footer'
				Data
					#|feat(api)!: remove deprecated endpoint
					#|
					#|BREAKING CHANGE: /v1/users endpoint removed
				End
				When call cz lint
				The status should be success
			End

			It 'accepts type!: description with BREAKING CHANGE footer'
				Data
					#|feat!: breaking change
					#|
					#|BREAKING CHANGE: this breaks things
				End
				When call cz lint
				The status should be success
			End

			Parameters
				feat fix docs style refactor perf test build ci chore revert
			End
			It "accepts default type: $1"
				Data "$1: description"
				When call cz lint
				The status should be success
			End

			It 'accepts multiline body'
				Data
					#|feat: add feature
					#|
					#|This is the body explaining why.
					#|It can span multiple lines.
				End
				When call cz lint
				The status should be success
			End

			It 'accepts message with footer'
				Data
					#|fix: resolve issue
					#|
					#|Fixes #123
				End
				When call cz lint
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Invalid conventional commits
		#───────────────────────────────────────────────────────────
		Describe 'invalid messages'
			It 'rejects empty message'
				Data ""
				When call cz lint
				The status should be failure
				The stderr should include "empty commit message"
			End

			It 'rejects whitespace-only message'
				Data "   "
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing colon'
				Data "feat add feature"
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing description after colon'
				Data "feat:"
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing description after colon and space'
				Data "feat: "
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects unknown type'
				Data "unknown: some change"
				When call cz lint
				The status should be failure
				The stderr should include "unknown type"
			End

			It 'rejects uppercase type'
				Data "FEAT: add feature"
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects breaking ! without BREAKING CHANGE footer'
				Data "feat!: breaking change"
				When call cz lint
				The status should be failure
				The stderr should include "BREAKING CHANGE:"
			End

			It 'rejects empty scope'
				Data "feat(): add feature"
				When call cz lint
				The status should be failure
				The stderr should include "invalid commit format"
			End
		End

		#───────────────────────────────────────────────────────────
		# Config file handling
		#───────────────────────────────────────────────────────────
		Describe 'config file'
			It 'uses .gitcommitizen in current directory'
				cat > .gitcommitizen << 'EOF'
[types]
custom = My custom type
EOF
				Data "custom: do something"
				When call cz lint
				The status should be success
			End

			It 'rejects types not in config'
				cat > .gitcommitizen << 'EOF'
[types]
custom = My custom type
EOF
				Data "feat: not in config"
				When call cz lint
				The status should be failure
				The stderr should include "unknown type"
			End

			It 'uses --config-file option'
				cat > custom.ini << 'EOF'
[types]
special = Special type
EOF
				Data "special: do something"
				When call cz --config-file custom.ini lint
				The status should be success
			End

			It 'uses -c short option'
				cat > custom.ini << 'EOF'
[types]
special = Special type
EOF
				Data "special: do something"
				When call cz -c custom.ini lint
				The status should be success
			End

			It 'fails if explicit config file not found'
				Data "feat: something"
				When call cz --config-file nonexistent.ini lint
				The status should be failure
				The stderr should include "config file not found"
				The stderr should include "nonexistent.ini"
			End

			It 'handles config with only scopes (uses default types)'
				cat > .gitcommitizen << 'EOF'
[scopes]
api = src/api/**
EOF
				Data "feat: add feature"
				When call cz lint
				The status should be success
				The stderr should include "using defaults"
			End

			It 'parses values with spaces'
				cat > .gitcommitizen << 'EOF'
[types]
feat = A new feature for users
EOF
				Data "feat: add feature"
				When call cz lint
				The status should be success
			End

			It 'ignores comments and blank lines in config'
				cat > .gitcommitizen << 'EOF'
# This is a comment
[types]

# Another comment
feat = A new feature
EOF
				Data "feat: add feature"
				When call cz lint
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Scope validation (message only, no files)
		#───────────────────────────────────────────────────────────
		Describe 'scope in message'
			It 'accepts any scope when no scopes defined'
				Data "feat(anything): works"
				When call cz lint
				The status should be success
			End

			It 'accepts defined scope'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api): add endpoint"
				When call cz lint
				The status should be success
			End

			It 'accepts scope not in config when not strict'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(other): add something"
				When call cz lint
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# File validation against scope patterns
		#───────────────────────────────────────────────────────────
		Describe 'file validation'
			setup_scope_config() {
				cat > .gitcommitizen << 'EOF'
[types]
feat = New feature
fix = Bug fix

[scopes]
api = src/api/**
ui = src/ui/**
nix = flake.nix, flake.lock, */default.nix
docs = docs/my folder/**
EOF
			}

			BeforeEach 'setup_scope_config'

			It 'passes when all files match scope pattern'
				Data "feat(api): add endpoint"
				When call cz lint --files "src/api/handler.go"
				The status should be success
			End

			It 'passes with multiple files matching scope'
				Data "feat(api): add endpoint"
				When call cz lint --files "src/api/handler.go src/api/routes.go"
				The status should be success
			End

			It 'fails when file does not match scope'
				Data "feat(api): add endpoint"
				When call cz lint --files "src/ui/button.tsx"
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'fails when some files do not match scope'
				Data "feat(api): add endpoint"
				When call cz lint --files "src/api/handler.go src/ui/button.tsx"
				The status should be failure
				The stderr should include "src/ui/button.tsx"
			End

			It 'matches ** for recursive directories'
				Data "feat(api): add endpoint"
				When call cz lint --files "src/api/deep/nested/file.go"
				The status should be success
			End

			It 'single * does not cross directories'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
scripts = scripts/*.sh
EOF
				Data "feat(scripts): update script"
				When call cz lint --files "scripts/nested/main.sh"
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'matches multi-pattern scope (first pattern)'
				Data "feat(nix): update flake"
				When call cz lint --files "flake.nix"
				The status should be success
			End

			It 'matches multi-pattern scope (second pattern)'
				Data "feat(nix): update flake"
				When call cz lint --files "flake.lock"
				The status should be success
			End

			It 'matches multi-pattern scope (glob pattern)'
				Data "feat(nix): update package"
				When call cz lint --files "scripts/default.nix"
				The status should be success
			End

			# Note: paths with spaces cannot be tested via CLI because --files
			# uses space-separated values. The underlying path_validator
			# supports them, but the CLI interface doesn't.

			It 'skips path validation when no files provided'
				Data "feat(api): add endpoint"
				When call cz lint
				The status should be success
			End

			It 'skips path validation when no scopes configured'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature
EOF
				Data "feat(anything): add feature"
				When call cz lint --files "any/file.txt"
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Multi-scope
		#───────────────────────────────────────────────────────────
		Describe 'multi-scope'
			It 'accepts multi-scope when enabled'
				cat > .gitcommitizen << 'EOF'
[settings]
multi-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api,ui): cross-cutting change"
				When call cz lint --files "src/api/handler.go src/ui/button.tsx"
				The status should be success
			End

			It 'rejects multi-scope when disabled (with files)'
				cat > .gitcommitizen << 'EOF'
[settings]
multi-scope = false

[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api,ui): cross-cutting change"
				When call cz lint --files "src/api/x.go"
				The status should be failure
				The stderr should include "multi-scope not enabled"
			End

			It 'rejects multi-scope by default when validating files'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api,ui): cross-cutting change"
				When call cz lint --files "src/api/x.go"
				The status should be failure
				The stderr should include "multi-scope not enabled"
			End

			It 'rejects multi-scope with unknown scope'
				cat > .gitcommitizen << 'EOF'
[settings]
multi-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api,unknown): change"
				When call cz lint --files "src/api/x.go"
				The status should be failure
				The stderr should include "unknown scope"
			End

			It 'uses custom multi-scope separator'
				cat > .gitcommitizen << 'EOF'
[settings]
multi-scope = true
multi-scope-separator = /

[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api/ui): cross-cutting change"
				When call cz lint --files "src/api/handler.go src/ui/button.tsx"
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Strict mode
		#───────────────────────────────────────────────────────────
		Describe 'strict mode'
			setup_strict_config() {
				cat > .gitcommitizen << 'EOF'
[settings]
strict = true

[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
			}

			BeforeEach 'setup_strict_config'

			It 'requires scope when files match scoped paths'
				Data "feat: add feature"
				When call cz lint --files "src/api/handler.go"
				The status should be failure
				The stderr should include "strict mode requires scope"
				The stderr should include "Hint"
			End

			It 'allows no scope when files match no scoped paths'
				Data "feat: add feature"
				When call cz lint --files "other/file.txt"
				The status should be success
			End

			It 'allows no scope when no files provided'
				Data "feat: add feature"
				When call cz lint
				The status should be success
			End

			It 'rejects unknown scope'
				Data "feat(unknown): add feature"
				When call cz lint
				The status should be failure
				The stderr should include "unknown scope"
			End

			It 'accepts defined scope'
				Data "feat(api): add feature"
				When call cz lint
				The status should be success
			End

			It 'rejects any scope when no scopes defined'
				cat > .gitcommitizen << 'EOF'
[settings]
strict = true

[types]
feat = Feature
EOF
				Data "feat(anything): add feature"
				When call cz lint
				The status should be failure
				The stderr should include "no scopes defined"
			End

			It '--no-strict overrides config strict=true'
				Data "feat: add feature"
				When call cz lint --no-strict -f "src/api/handler.go"
				The status should be success
			End

			It '--strict overrides config strict=false'
				cat > .gitcommitizen << 'EOF'
[settings]
strict = false

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat: add feature"
				When call cz lint --strict --files "src/api/handler.go"
				The status should be failure
				The stderr should include "strict mode requires scope"
			End
		End

		#───────────────────────────────────────────────────────────
		# Wildcard scope
		#───────────────────────────────────────────────────────────
		Describe 'wildcard scope'
			It '* scope matches any files'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
* = **
EOF
				Data "feat(*): generic change"
				When call cz lint --files "any/random/file.txt"
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Quiet mode
		#───────────────────────────────────────────────────────────
		Describe 'quiet mode'
			It '-q suppresses error output'
				Data "unknown: bad type"
				When call cz -q lint
				The status should be failure
				The stderr should equal ""
			End

			It '--quiet suppresses error output'
				Data "unknown: bad type"
				When call cz --quiet lint
				The status should be failure
				The stderr should equal ""
			End
		End
	End

	#═══════════════════════════════════════════════════════════════
	# INIT COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'init'
		It 'prints config to stdout by default'
			When call cz init
			The status should be success
			The output should include "[types]"
			The output should include "[settings]"
			The output should include "[scopes]"
			The output should include "feat = A new feature"
			The output should include "fix = A bug fix"
		End

		It 'does not create file by default'
			When call cz init
			The status should be success
			The output should include "[types]"
			The file ".gitcommitizen" should not be exist
		End

		It 'includes header comment'
			When call cz init
			The output should include "# Conventional Commits"
		End

		Describe 'file output'
			It '-o writes to specified file'
				When call cz init -o custom-config
				The status should be success
				The output should equal ""
				The file "custom-config" should be exist
				The contents of file "custom-config" should include "feat"
			End

			It '--output writes to specified file'
				When call cz init --output custom-config
				The status should be success
				The file "custom-config" should be exist
			End

			It 'errors if file exists without -f'
				touch .gitcommitizen
				When call cz init -o .gitcommitizen
				The status should be failure
				The stderr should include "already exists"
			End

			It '-f overwrites existing file'
				echo "old content" > .gitcommitizen
				When call cz init -o .gitcommitizen -f
				The status should be success
				The output should equal ""
				The contents of file ".gitcommitizen" should include "feat"
				The contents of file ".gitcommitizen" should not include "old content"
			End

			It '--force overwrites existing file'
				echo "old content" > .gitcommitizen
				When call cz init -o .gitcommitizen --force
				The status should be success
				The contents of file ".gitcommitizen" should include "feat"
			End
		End
	End

	#═══════════════════════════════════════════════════════════════
	# HOOK COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'hook'
		Describe 'status'
			It 'shows not installed when no hook exists'
				When call cz hook status
				The status should be failure
				The output should equal "Not installed"
			End

			It 'shows installed when cz hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\n# cz-hook\ncz lint <"$1"\n' > .git/hooks/commit-msg
				When call cz hook status
				The status should be success
				The output should include "Installed"
			End

			It 'shows other hook when non-cz hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other hook"\n' > .git/hooks/commit-msg
				When call cz hook status
				The status should be failure
				The output should include "Other hook"
			End
		End

		Describe 'install'
			It 'creates commit-msg hook'
				When call cz hook install
				The status should be success
				The output should equal "Installed commit-msg hook"
				The file ".git/hooks/commit-msg" should be exist
			End

			It 'creates executable hook'
				When call cz hook install
				The file ".git/hooks/commit-msg" should be executable
				The output should include "Installed"
			End

			It 'hook contains cz lint command'
				When call cz hook install
				The contents of file ".git/hooks/commit-msg" should include "cz lint"
				The output should include "Installed"
			End

			It 'hook contains cz-hook marker'
				When call cz hook install
				The contents of file ".git/hooks/commit-msg" should include "cz-hook"
				The output should include "Installed"
			End

			It 'reports already installed if cz hook exists'
				cz hook install >/dev/null
				When call cz hook install
				The status should be success
				The output should include "already installed"
			End

			It 'errors if other hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
				When call cz hook install
				The status should be failure
				The stderr should include "existing commit-msg hook"
			End
		End

		Describe 'uninstall'
			It 'removes cz hook'
				cz hook install >/dev/null
				When call cz hook uninstall
				The status should be success
				The output should equal "Uninstalled commit-msg hook"
				The file ".git/hooks/commit-msg" should not be exist
			End

			It 'reports no hook when none exists'
				When call cz hook uninstall
				The status should be success
				The output should include "no commit-msg hook"
			End

			It 'errors if hook not installed by cz'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
				When call cz hook uninstall
				The status should be failure
				The stderr should include "not installed by cz"
			End
		End

		Describe 'outside git repo'
			It 'errors when not in git repo'
				rm -rf .git
				When call cz hook status
				The status should be failure
				The stderr should include "not a git repository"
			End

			It 'install errors outside git repo'
				rm -rf .git
				When call cz hook install
				The status should be failure
				The stderr should include "not a git repository"
			End

			It 'uninstall errors outside git repo'
				rm -rf .git
				When call cz hook uninstall
				The status should be failure
				The stderr should include "not a git repository"
			End
		End

		It 'errors with unknown subcommand'
			When call cz hook unknown
			The status should be failure
			The stderr should include "unknown"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSE COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'parse'
		It 'shows defaults indicator when no config'
			When call cz parse
			The output should include "Config: (defaults)"
		End

		It 'shows default types'
			When call cz parse
			The output should include "feat"
			The output should include "fix"
			The output should include "docs"
			The output should include "A new feature"
			The output should include "A bug fix"
		End

		It 'shows config path when present'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Custom feature
EOF
			When call cz parse
			The output should include "Config:"
			The output should include ".gitcommitizen"
		End

		It 'shows custom types from config'
			cat > .gitcommitizen << 'EOF'
[types]
custom = My custom type
EOF
			When call cz parse
			The output should include "custom"
			The output should include "My custom type"
		End

		It 'shows settings'
			cat > .gitcommitizen << 'EOF'
[settings]
strict = true
multi-scope = true
EOF
			When call cz parse
			The output should include "Settings:"
			The output should include "strict = true"
			The stderr should include "using defaults"
		End

		It 'shows scopes with patterns'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
			When call cz parse
			The output should include "Scopes:"
			The output should include "api = src/api/**"
			The output should include "ui = src/ui/**"
		End

		It 'uses explicit config file'
			cat > custom.conf << 'EOF'
[types]
custom = Custom type
EOF
			When call cz --config-file custom.conf parse
			The output should include "Config: custom.conf"
			The output should include "custom"
			The output should include "Custom type"
		End

		It 'fails if explicit config file does not exist'
			When call cz --config-file /nonexistent/config parse
			The status should be failure
			The stderr should include "config file not found"
			The stderr should include "/nonexistent/config"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# CREATE COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'create'
		Describe 'gum dependency'
			It 'fails if gum is not found'
				PATH="/usr/bin:/bin"
				# Skip if gum is installed in those paths
				command -v gum &>/dev/null && Skip "gum is installed system-wide"
				When run cz create
				The status should be failure
				The stderr should include "gum is required"
			End
		End

		Describe 'with mocked gum'
			setup_mock_gum() {
				mkdir -p "$TEST_DIR/bin"
				cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		echo "feat - A new feature"
		;;
	input)
		if [[ "$*" == *"Scope"* ]] || [[ "$*" == *"scope"* ]]; then
			echo "api"
		elif [[ "$*" == *"Description"* ]]; then
			echo "add new feature"
		fi
		;;
	confirm)
		exit 1
		;;
	write)
		echo ""
		;;
esac
MOCK
				chmod +x "$TEST_DIR/bin/gum"
				PATH="$TEST_DIR/bin:$PATH"
			}

			BeforeEach 'setup_mock_gum'

			It 'outputs formatted commit message'
				When call cz create
				The status should be success
				The output should equal "feat(api): add new feature"
			End

			It 'loads default config when no config file'
				When call cz create
				The status should be success
				The output should include "feat"
			End
		End

		Describe 'breaking change'
			setup_breaking_gum() {
				mkdir -p "$TEST_DIR/bin"
				cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		echo "feat - A new feature"
		;;
	input)
		if [[ "$*" == *"Scope"* ]]; then
			echo ""
		elif [[ "$*" == *"Description"* ]]; then
			echo "change api"
		fi
		;;
	confirm)
		exit 0
		;;
	write)
		if [[ "$*" == *"Breaking"* ]]; then
			echo "removed deprecated endpoints"
		else
			echo ""
		fi
		;;
esac
MOCK
				chmod +x "$TEST_DIR/bin/gum"
				PATH="$TEST_DIR/bin:$PATH"
			}

			BeforeEach 'setup_breaking_gum'

			It 'adds ! for breaking change'
				When call cz create
				The status should be success
				The line 1 of output should equal "feat!: change api"
			End

			It 'includes BREAKING CHANGE footer'
				When call cz create
				The output should include "BREAKING CHANGE: removed deprecated endpoints"
			End
		End

		Describe 'with body'
			setup_body_gum() {
				mkdir -p "$TEST_DIR/bin"
				cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		echo "fix - A bug fix"
		;;
	input)
		if [[ "$*" == *"Scope"* ]]; then
			echo "core"
		elif [[ "$*" == *"Description"* ]]; then
			echo "fix null pointer"
		fi
		;;
	confirm)
		exit 1
		;;
	write)
		if [[ "$*" == *"Body"* ]]; then
			echo "This fixes issue #123"
		else
			echo ""
		fi
		;;
esac
MOCK
				chmod +x "$TEST_DIR/bin/gum"
				PATH="$TEST_DIR/bin:$PATH"
			}

			BeforeEach 'setup_body_gum'

			It 'includes body with blank line separator'
				When call cz create
				The status should be success
				The line 1 of output should equal "fix(core): fix null pointer"
				The line 2 of output should equal ""
				The line 3 of output should equal "This fixes issue #123"
			End
		End

		Describe 'with configured scopes'
			setup_scopes_config() {
				cat > .gitcommitizen << 'EOF'
[scopes]
api = src/api/**
core = src/core/**
ui = src/ui/**

[types]
feat = A new feature
EOF
			}

			BeforeEach 'setup_scopes_config'

			Describe 'selecting from list'
				setup_list_gum() {
					mkdir -p "$TEST_DIR/bin"
					cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		if [[ "$*" == *"type"* ]]; then
			echo "feat - A new feature"
		elif [[ "$*" == *"scope"* ]]; then
			echo "ui"
		fi
		;;
	input)
		if [[ "$*" == *"Description"* ]]; then
			echo "add button"
		fi
		;;
	confirm)
		exit 1
		;;
	write)
		echo ""
		;;
esac
MOCK
					chmod +x "$TEST_DIR/bin/gum"
					PATH="$TEST_DIR/bin:$PATH"
				}

				BeforeEach 'setup_list_gum'

				It 'uses selected scope from list'
					When call cz create
					The status should be success
					The output should equal "feat(ui): add button"
				End
			End

			Describe 'custom scope input'
				setup_custom_gum() {
					mkdir -p "$TEST_DIR/bin"
					cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		if [[ "$*" == *"type"* ]]; then
			echo "feat - A new feature"
		elif [[ "$*" == *"scope"* ]]; then
			echo "(custom)"
		fi
		;;
	input)
		if [[ "$*" == *"scope"* ]]; then
			echo "custom-scope"
		elif [[ "$*" == *"Description"* ]]; then
			echo "add button"
		fi
		;;
	confirm)
		exit 1
		;;
	write)
		echo ""
		;;
esac
MOCK
					chmod +x "$TEST_DIR/bin/gum"
					PATH="$TEST_DIR/bin:$PATH"
				}

				BeforeEach 'setup_custom_gum'

				It 'allows custom scope input'
					When call cz create
					The status should be success
					The output should equal "feat(custom-scope): add button"
				End
			End

			Describe 'STRICT_SCOPES mode'
				setup_strict_gum() {
					mkdir -p "$TEST_DIR/bin"
					cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		if [[ "$*" == *"type"* ]]; then
			echo "feat - A new feature"
		elif [[ "$*" == *"scope"* ]]; then
			echo "api"
		fi
		;;
	input)
		if [[ "$*" == *"Description"* ]]; then
			echo "add endpoint"
		fi
		;;
	confirm)
		exit 1
		;;
	write)
		echo ""
		;;
esac
MOCK
					chmod +x "$TEST_DIR/bin/gum"
					PATH="$TEST_DIR/bin:$PATH"
				}

				BeforeEach 'setup_strict_gum'

				It 'only allows configured scopes with STRICT_SCOPES'
					export STRICT_SCOPES=1
					When call cz create
					The status should be success
					The output should equal "feat(api): add endpoint"
				End
			End
		End
	End

	#═══════════════════════════════════════════════════════════════
	# DEFAULT BEHAVIOR
	#═══════════════════════════════════════════════════════════════
	Describe 'default command'
		It 'runs lint when stdin is not a TTY'
			Data "feat: test feature"
			When call cz
			The status should be success
		End

		It 'rejects invalid input in default lint mode'
			Data "invalid message"
			When call cz
			The status should be failure
			The stderr should include "invalid commit format"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# GLOBAL OPTIONS AND ERROR HANDLING
	#═══════════════════════════════════════════════════════════════
	Describe 'global options'
		It '--help shows usage'
			When call cz --help
			The status should be success
			The output should include "Usage:"
		End

		It '-h shows usage'
			When call cz -h
			The status should be success
			The output should include "Usage:"
		End

		It 'unknown command fails with error'
			When call cz unknown
			The status should be failure
			The stderr should include "Not a command"
		End
	End
End
