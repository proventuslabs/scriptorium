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

	# Path to the built script
	BIN="${SHELLSPEC_PROJECT_ROOT}/dist/cz/bin/cz"

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
				When run script "$BIN" lint
				The status should be success
			End

			It 'accepts type(scope): description'
				Data "fix(api): resolve null pointer"
				When run script "$BIN" lint
				The status should be success
			End

			It 'accepts type(scope)!: description with BREAKING CHANGE footer'
				Data
					#|feat(api)!: remove deprecated endpoint
					#|
					#|BREAKING CHANGE: /v1/users endpoint removed
				End
				When run script "$BIN" lint
				The status should be success
			End

			It 'accepts type!: description with BREAKING CHANGE footer'
				Data
					#|feat!: breaking change
					#|
					#|BREAKING CHANGE: this breaks things
				End
				When run script "$BIN" lint
				The status should be success
			End

			Parameters
				feat fix docs style refactor perf test build ci chore revert
			End
			It "accepts default type: $1"
				Data "$1: description"
				When run script "$BIN" lint
				The status should be success
			End

			It 'accepts multiline body'
				Data
					#|feat: add feature
					#|
					#|This is the body explaining why.
					#|It can span multiple lines.
				End
				When run script "$BIN" lint
				The status should be success
			End

			It 'accepts message with footer'
				Data
					#|fix: resolve issue
					#|
					#|Fixes #123
				End
				When run script "$BIN" lint
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Invalid conventional commits
		#───────────────────────────────────────────────────────────
		Describe 'invalid messages'
			It 'rejects empty message'
				Data ""
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "empty commit message"
			End

			It 'rejects whitespace-only message'
				Data "   "
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing colon'
				Data "feat add feature"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing description after colon'
				Data "feat:"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects missing description after colon and space'
				Data "feat: "
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects unknown type'
				Data "unknown: some change"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "unknown type"
			End

			It 'rejects uppercase type'
				Data "FEAT: add feature"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects breaking ! without BREAKING CHANGE footer'
				Data "feat!: breaking change"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "BREAKING CHANGE:"
			End

			It 'rejects empty scope'
				Data "feat(): add feature"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "invalid commit format"
			End

			It 'rejects whitespace-only description'
				Data "feat:    "
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "description cannot be empty"
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
				When run script "$BIN" lint
				The status should be success
			End

			It 'rejects types not in config'
				cat > .gitcommitizen << 'EOF'
[types]
custom = My custom type
EOF
				Data "feat: not in config"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "unknown type"
			End

			It 'uses --config-file option'
				cat > custom.ini << 'EOF'
[types]
special = Special type
EOF
				Data "special: do something"
				When run script "$BIN" --config-file custom.ini lint
				The status should be success
			End

			It 'uses -c short option'
				cat > custom.ini << 'EOF'
[types]
special = Special type
EOF
				Data "special: do something"
				When run script "$BIN" -c custom.ini lint
				The status should be success
			End

			It 'fails if explicit config file not found'
				Data "feat: something"
				When run script "$BIN" --config-file nonexistent.ini lint
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
				When run script "$BIN" lint
				The status should be success
				The stderr should include "using defaults"
			End

			It 'parses values with spaces'
				cat > .gitcommitizen << 'EOF'
[types]
feat = A new feature for users
EOF
				Data "feat: add feature"
				When run script "$BIN" lint
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
				When run script "$BIN" lint
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Scope validation (message only, no files)
		#───────────────────────────────────────────────────────────
		Describe 'scope in message'
			It 'accepts any scope when no scopes defined'
				Data "feat(anything): works"
				When run script "$BIN" lint
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
				When run script "$BIN" lint
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
				When run script "$BIN" lint
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
				When run script "$BIN" lint --paths "src/api/handler.go"
				The status should be success
			End

			It 'passes with multiple files matching scope'
				Data "feat(api): add endpoint"
				When run script "$BIN" lint --paths "src/api/handler.go src/api/routes.go"
				The status should be success
			End

			It 'fails when file does not match scope'
				Data "feat(api): add endpoint"
				When run script "$BIN" -e lint --paths "src/ui/button.tsx"
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'fails when some files do not match scope'
				Data "feat(api): add endpoint"
				When run script "$BIN" -e lint --paths "src/api/handler.go src/ui/button.tsx"
				The status should be failure
				The stderr should include "src/ui/button.tsx"
			End

			It 'matches ** for recursive directories'
				Data "feat(api): add endpoint"
				When run script "$BIN" lint --paths "src/api/deep/nested/file.go"
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
				When run script "$BIN" -e lint --paths "scripts/nested/main.sh"
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'matches multi-pattern scope (first pattern)'
				Data "feat(nix): update flake"
				When run script "$BIN" lint --paths "flake.nix"
				The status should be success
			End

			It 'matches multi-pattern scope (second pattern)'
				Data "feat(nix): update flake"
				When run script "$BIN" lint --paths "flake.lock"
				The status should be success
			End

			It 'matches multi-pattern scope (glob pattern)'
				Data "feat(nix): update package"
				When run script "$BIN" lint --paths "scripts/default.nix"
				The status should be success
			End

			# Note: paths with spaces cannot be tested via CLI because --files
			# uses space-separated values. The underlying path_validator
			# supports them, but the CLI interface doesn't.

			It 'skips path validation when no files provided'
				Data "feat(api): add endpoint"
				When run script "$BIN" lint
				The status should be success
			End

			It 'skips path validation when no scopes configured'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature
EOF
				Data "feat(anything): add feature"
				When run script "$BIN" lint --paths "any/file.txt"
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
				When run script "$BIN" lint --paths "src/api/handler.go src/ui/button.tsx"
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
				When run script "$BIN" -e lint --paths "src/api/x.go"
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
				When run script "$BIN" -e lint --paths "src/api/x.go"
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
				When run script "$BIN" -e lint --paths "src/api/x.go"
				The status should be failure
				The stderr should include "unknown scope"
			End

			It '--multi-scope flag enables multi-scope without config'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api,ui): cross-cutting change"
				When run script "$BIN" --multi-scope lint --paths "src/api/handler.go src/ui/button.tsx"
				The status should be success
			End

			It '--no-multi-scope flag disables multi-scope even with config'
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
				When run script "$BIN" --no-multi-scope -e lint --paths "src/api/x.go"
				The status should be failure
				The stderr should include "multi-scope not enabled"
			End

			It '-m shorthand enables multi-scope'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
				Data "feat(api,ui): cross-cutting change"
				When run script "$BIN" -m lint --paths "src/api/handler.go src/ui/button.tsx"
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Scope validation flags
		#───────────────────────────────────────────────────────────
		Describe 'defined-scope flag'
			It 'rejects unknown scope when -d is set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(unknown): add feature"
				When run script "$BIN" -d lint
				The status should be failure
				The stderr should include "unknown scope"
			End

			It 'accepts defined scope when -d is set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api): add feature"
				When run script "$BIN" -d lint
				The status should be success
			End

			It 'allows any scope when -d is not set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(unknown): add feature"
				When run script "$BIN" lint
				The status should be success
			End

			It 'rejects any scope when no scopes defined and -d is set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature
EOF
				Data "feat(anything): add feature"
				When run script "$BIN" -d lint
				The status should be failure
				The stderr should include "no scopes defined"
			End

			It '--no-defined-scope overrides config'
				cat > .gitcommitizen << 'EOF'
[settings]
defined-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(unknown): add feature"
				When run script "$BIN" --no-defined-scope lint
				The status should be success
			End

			It 'config defined-scope = true validates scope'
				cat > .gitcommitizen << 'EOF'
[settings]
defined-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(unknown): add feature"
				When run script "$BIN" lint
				The status should be failure
				The stderr should include "unknown scope"
			End
		End

		Describe 'require-scope flag'
			It 'requires scope when -r is set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat: add feature"
				When run script "$BIN" -r lint
				The status should be failure
				The stderr should include "scope required"
			End

			It 'accepts scope when -r is set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api): add feature"
				When run script "$BIN" -r lint
				The status should be success
			End

			It 'allows no scope when -r is not set'
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature
EOF
				Data "feat: add feature"
				When run script "$BIN" lint
				The status should be success
			End

			It '--no-require-scope overrides config'
				cat > .gitcommitizen << 'EOF'
[settings]
require-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat: add feature"
				When run script "$BIN" --no-require-scope lint
				The status should be success
			End
		End

		Describe 'enforce-patterns flag'
			setup_enforce_config() {
				cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
			}

			BeforeEach 'setup_enforce_config'

			It 'requires scope to match files when -e is set'
				Data "feat(api): add endpoint"
				When run script "$BIN" -e lint --paths "src/ui/button.tsx"
				The status should be failure
				The stderr should include "does not match scope"
			End

			It 'passes when scope matches files with -e'
				Data "feat(api): add endpoint"
				When run script "$BIN" -e lint --paths "src/api/handler.go"
				The status should be success
			End

			It 'requires scope for scoped files when -e is set'
				Data "feat: add feature"
				When run script "$BIN" -e lint --paths "src/api/handler.go"
				The status should be failure
				The stderr should include "scope required"
			End

			It 'allows no scope for unscoped files when -e is set'
				Data "feat: add feature"
				When run script "$BIN" -e lint --paths "other/file.txt"
				The status should be success
			End

			It '-e implies -d (validates scope exists)'
				Data "feat(unknown): add feature"
				When run script "$BIN" -e lint --paths "other/file.txt"
				The status should be failure
				The stderr should include "unknown scope"
			End

			It '--no-enforce-patterns allows scope mismatch'
				cat > .gitcommitizen << 'EOF'
[settings]
enforce-patterns = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api): add endpoint"
				When run script "$BIN" --no-enforce-patterns lint --paths "src/ui/button.tsx"
				The status should be success
			End

			It 'config enforce-patterns = true validates patterns'
				cat > .gitcommitizen << 'EOF'
[settings]
enforce-patterns = true

[types]
feat = Feature

[scopes]
api = src/api/**
EOF
				Data "feat(api): add endpoint"
				When run script "$BIN" lint --paths "src/ui/button.tsx"
				The status should be failure
				The stderr should include "does not match scope"
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
				When run script "$BIN" lint --paths "any/random/file.txt"
				The status should be success
			End
		End

		#───────────────────────────────────────────────────────────
		# Quiet mode
		#───────────────────────────────────────────────────────────
		Describe 'quiet mode'
			It '-q suppresses error output'
				Data "unknown: bad type"
				When run script "$BIN" -q lint
				The status should be failure
				The stderr should equal ""
			End

			It '--quiet suppresses error output'
				Data "unknown: bad type"
				When run script "$BIN" --quiet lint
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
			When run script "$BIN" init
			The status should be success
			The output should include "[types]"
			The output should include "[settings]"
			The output should include "[scopes]"
			The output should include "feat = A new feature"
			The output should include "fix = A bug fix"
		End

		It 'does not create file by default'
			When run script "$BIN" init
			The status should be success
			The output should include "[types]"
			The file ".gitcommitizen" should not be exist
		End

		It 'includes header comment'
			When run script "$BIN" init
			The output should include "# Conventional Commits"
		End

		Describe 'file output'
			It '-o writes to specified file'
				When run script "$BIN" init -o custom-config
				The status should be success
				The output should equal ""
				The file "custom-config" should be exist
				The contents of file "custom-config" should include "feat"
			End

			It '--output writes to specified file'
				When run script "$BIN" init --output custom-config
				The status should be success
				The file "custom-config" should be exist
			End

			It 'errors if file exists without -f'
				touch .gitcommitizen
				When run script "$BIN" init -o .gitcommitizen
				The status should be failure
				The stderr should include "already exists"
			End

			It '-f overwrites existing file'
				echo "old content" > .gitcommitizen
				When run script "$BIN" init -o .gitcommitizen -f
				The status should be success
				The output should equal ""
				The contents of file ".gitcommitizen" should include "feat"
				The contents of file ".gitcommitizen" should not include "old content"
			End

			It '--force overwrites existing file'
				echo "old content" > .gitcommitizen
				When run script "$BIN" init -o .gitcommitizen --force
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
				When run script "$BIN" hook status
				The status should be failure
				The output should equal "Not installed"
			End

			It 'shows installed when cz hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\n# cz-hook\ncz lint <"$1"\n' > .git/hooks/commit-msg
				When run script "$BIN" hook status
				The status should be success
				The output should include "Installed"
			End

			It 'shows other hook when non-cz hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other hook"\n' > .git/hooks/commit-msg
				When run script "$BIN" hook status
				The status should be failure
				The output should include "Other hook"
			End
		End

		Describe 'install'
			It 'creates commit-msg hook'
				When run script "$BIN" hook install
				The status should be success
				The output should equal "Installed commit-msg hook"
				The file ".git/hooks/commit-msg" should be exist
			End

			It 'creates executable hook'
				When run script "$BIN" hook install
				The file ".git/hooks/commit-msg" should be executable
				The output should include "Installed"
			End

			It 'hook contains cz lint command with paths flag'
				When run script "$BIN" hook install
				The contents of file ".git/hooks/commit-msg" should include 'cz lint --paths "$files"'
				The output should include "Installed"
			End

			It 'hook contains cz-hook marker'
				When run script "$BIN" hook install
				The contents of file ".git/hooks/commit-msg" should include "cz-hook"
				The output should include "Installed"
			End

			It 'reports already installed if cz hook exists'
				"$BIN" hook install >/dev/null
				When run script "$BIN" hook install
				The status should be success
				The output should include "already installed"
			End

			It 'errors if other hook exists'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
				When run script "$BIN" hook install
				The status should be failure
				The stderr should include "existing commit-msg hook"
			End
		End

		Describe 'uninstall'
			It 'removes cz hook'
				"$BIN" hook install >/dev/null
				When run script "$BIN" hook uninstall
				The status should be success
				The output should equal "Uninstalled commit-msg hook"
				The file ".git/hooks/commit-msg" should not be exist
			End

			It 'reports no hook when none exists'
				When run script "$BIN" hook uninstall
				The status should be success
				The output should include "no commit-msg hook"
			End

			It 'errors if hook not installed by cz'
				mkdir -p .git/hooks
				printf '#!/bin/sh\necho "other"\n' > .git/hooks/commit-msg
				When run script "$BIN" hook uninstall
				The status should be failure
				The stderr should include "not installed by cz"
			End
		End

		Describe 'outside git repo'
			It 'errors when not in git repo'
				rm -rf .git
				When run script "$BIN" hook status
				The status should be failure
				The stderr should include "not a git repository"
			End

			It 'install errors outside git repo'
				rm -rf .git
				When run script "$BIN" hook install
				The status should be failure
				The stderr should include "not a git repository"
			End

			It 'uninstall errors outside git repo'
				rm -rf .git
				When run script "$BIN" hook uninstall
				The status should be failure
				The stderr should include "not a git repository"
			End
		End

		It 'errors with unknown subcommand'
			When run script "$BIN" hook unknown
			The status should be failure
			The stderr should include "unknown"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSE COMMAND
	#═══════════════════════════════════════════════════════════════
	Describe 'parse'
		It 'shows defaults indicator when no config'
			When run script "$BIN" parse
			The output should include "Config: (defaults)"
		End

		It 'shows default types'
			When run script "$BIN" parse
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
			When run script "$BIN" parse
			The output should include "Config:"
			The output should include ".gitcommitizen"
		End

		It 'shows custom types from config'
			cat > .gitcommitizen << 'EOF'
[types]
custom = My custom type
EOF
			When run script "$BIN" parse
			The output should include "custom"
			The output should include "My custom type"
		End

		It 'shows settings'
			cat > .gitcommitizen << 'EOF'
[settings]
require-scope = true
multi-scope = true
EOF
			When run script "$BIN" parse
			The output should include "Settings:"
			The output should include "require-scope = true"
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
			When run script "$BIN" parse
			The output should include "Scopes:"
			The output should include "api = src/api/**"
			The output should include "ui = src/ui/**"
		End

		It 'uses explicit config file'
			cat > custom.conf << 'EOF'
[types]
custom = Custom type
EOF
			When run script "$BIN" --config-file custom.conf parse
			The output should include "Config: custom.conf"
			The output should include "custom"
			The output should include "Custom type"
		End

		It 'fails if explicit config file does not exist'
			When run script "$BIN" --config-file /nonexistent/config parse
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
				When run script "$BIN" create
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
				When run script "$BIN" create
				The status should be success
				The output should equal "feat(api): add new feature"
			End

			It 'loads default config when no config file'
				When run script "$BIN" create
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
				When run script "$BIN" create
				The status should be success
				The line 1 of output should equal "feat!: change api"
			End

			It 'includes BREAKING CHANGE footer'
				When run script "$BIN" create
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
				When run script "$BIN" create
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
					When run script "$BIN" create
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
					When run script "$BIN" create
					The status should be success
					The output should equal "feat(custom-scope): add button"
				End
			End

			Describe 'scope flag combinations'
				# Mock that selects "api" scope and returns "add endpoint" description
				setup_scope_select_gum() {
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
		elif [[ "$*" == *"scope"* ]]; then
			echo "custom-scope"
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

				BeforeEach 'setup_scope_select_gum'

				It '--require-scope removes (none) option but keeps (custom)'
					When run script "$BIN" --require-scope create
					The status should be success
					The output should equal "feat(api): add endpoint"
				End

				It '--defined-scope removes (custom) option but keeps (none)'
					# Mock that selects "(none)" when it's available
					mkdir -p "$TEST_DIR/bin"
					cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		if [[ "$*" == *"type"* ]]; then
			echo "feat - A new feature"
		elif [[ "$*" == *"scope"* ]]; then
			echo "(none)"
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

					When run script "$BIN" --defined-scope create
					The status should be success
					The output should equal "feat: add endpoint"
				End

				It 'both flags together only allows configured scopes'
					When run script "$BIN" --require-scope --defined-scope create
					The status should be success
					The output should equal "feat(api): add endpoint"
				End

				It 'config require-scope=true removes (none) option'
					cat > .gitcommitizen << 'EOF'
[settings]
require-scope = true

[types]
feat = A new feature

[scopes]
api = src/api/**
EOF
					When run script "$BIN" create
					The status should be success
					The output should equal "feat(api): add endpoint"
				End
			End

			Describe 'no scope selected'
				setup_none_gum() {
					mkdir -p "$TEST_DIR/bin"
					cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		if [[ "$*" == *"type"* ]]; then
			echo "feat - A new feature"
		elif [[ "$*" == *"scope"* ]]; then
			echo "(none)"
		fi
		;;
	input)
		if [[ "$*" == *"Description"* ]]; then
			echo "general change"
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

				BeforeEach 'setup_none_gum'

				It 'allows no scope when (none) selected'
					When run script "$BIN" create
					The status should be success
					The output should equal "feat: general change"
				End
			End
		End

		Describe 'gum cancel'
			setup_cancel_gum() {
				mkdir -p "$TEST_DIR/bin"
				cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
# Simulate user pressing Ctrl+C or Escape
exit 1
MOCK
				chmod +x "$TEST_DIR/bin/gum"
				PATH="$TEST_DIR/bin:$PATH"
			}

			BeforeEach 'setup_cancel_gum'

			It 'exits with code 130 when gum is cancelled'
				When run script "$BIN" create
				The status should equal 130
			End
		End
	End

	#═══════════════════════════════════════════════════════════════
	# DEFAULT BEHAVIOR
	#═══════════════════════════════════════════════════════════════
	Describe 'default command'
		It 'runs lint when stdin is not a TTY'
			Data "feat: test feature"
			When run script "$BIN"
			The status should be success
		End

		It 'rejects invalid input in default lint mode'
			Data "invalid message"
			When run script "$BIN"
			The status should be failure
			The stderr should include "invalid commit format"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# GLOBAL OPTIONS AND ERROR HANDLING
	#═══════════════════════════════════════════════════════════════
	Describe 'global options'
		It '--help shows usage'
			When run script "$BIN" --help
			The status should be success
			The output should include "Usage:"
		End

		It '-h shows usage'
			When run script "$BIN" -h
			The status should be success
			The output should include "Usage:"
		End

		It '--version shows version'
			When run script "$BIN" --version
			The status should be success
			The output should match pattern '*.*.*'
		End

		It '-V shows version'
			When run script "$BIN" -V
			The status should be success
			The output should match pattern '*.*.*'
		End

		It 'unknown command fails with error'
			When run script "$BIN" unknown
			The status should be failure
			The stderr should include "Not a command"
		End

		It '-c requires argument'
			When run script "$BIN" -c
			The status should be failure
			The stderr should include "Requires an argument"
		End

		It '--config-file requires argument'
			When run script "$BIN" --config-file
			The status should be failure
			The stderr should include "Requires an argument"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# EDGE CASES
	#═══════════════════════════════════════════════════════════════
	Describe 'edge cases'
		It 'shows defined scopes hint when scope unknown'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
			Data "feat(unknown): add feature"
			When run script "$BIN" --defined-scope lint
			The status should be failure
			The stderr should include "unknown scope"
			The stderr should include "api"
			The stderr should include "ui"
		End

		It 'handles files with special regex characters'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
special = src/[test]/**
EOF
			Data "feat(special): add feature"
			When run script "$BIN" lint --paths "src/[test]/file.ts"
			The status should be success
		End

		It 'accepts description with leading space preserved'
			Data "feat:   description with spaces"
			When run script "$BIN" lint
			The status should be success
		End

		It 'rejects whitespace-only description'
			Data "feat:    "
			When run script "$BIN" lint
			The status should be failure
			The stderr should include "empty"
		End

		It 'handles config keys with hyphens correctly'
			cat > .gitcommitizen << 'EOF'
[settings]
multi-scope = true

[types]
feat = Feature

[scopes]
api = src/api/**
ui = src/ui/**
EOF
			Data "feat(api,ui): cross-cutting"
			When run script "$BIN" lint --paths "src/api/x.go src/ui/y.tsx"
			The status should be success
		End

		It 'skips wildcard scope in strict scope checking'
			cat > .gitcommitizen << 'EOF'
[settings]
strict = true

[types]
feat = Feature

[scopes]
api = src/api/**
* = **
EOF
			Data "feat(*): wildcard change"
			When run script "$BIN" lint
			The status should be success
		End

		It 'handles pattern with dots'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
config = *.config.js
EOF
			Data "feat(config): update config"
			When run script "$BIN" lint --paths "webpack.config.js"
			The status should be success
		End

		It 'handles pattern with plus sign'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
cpp = src/c++/**
EOF
			Data "feat(cpp): add c++ code"
			When run script "$BIN" lint --paths "src/c++/main.cpp"
			The status should be success
		End

		It 'handles pattern with caret'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
special = src/^test/**
EOF
			Data "feat(special): add test"
			When run script "$BIN" lint --paths "src/^test/file.ts"
			The status should be success
		End

		It 'handles pattern with dollar sign'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
money = src/$utils/**
EOF
			Data "feat(money): add utils"
			When run script "$BIN" lint --paths "src/\$utils/format.ts"
			The status should be success
		End

		It 'handles pattern with pipe'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
pipe = src/a|b/**
EOF
			Data "feat(pipe): add feature"
			When run script "$BIN" lint --paths "src/a|b/file.ts"
			The status should be success
		End

		It 'handles pattern with parentheses'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
group = src/(test)/**
EOF
			Data "feat(group): add feature"
			When run script "$BIN" lint --paths "src/(test)/file.ts"
			The status should be success
		End

		It 'handles pattern with curly braces'
			cat > .gitcommitizen << 'EOF'
[types]
feat = Feature

[scopes]
tmpl = src/{templates}/**
EOF
			Data "feat(tmpl): add template"
			When run script "$BIN" lint --paths "src/{templates}/base.html"
			The status should be success
		End
	End
End
