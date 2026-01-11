# shellcheck shell=bash
# shellcheck disable=SC2329 # Functions invoked indirectly via ShellSpec BeforeCall

Describe 'file_matches_pattern'
	Include ./path_validator.sh

	It 'matches exact file path'
		When call file_matches_pattern "src/main.sh" "src/main.sh"
		The status should be success
	End

	It 'does not match different file'
		When call file_matches_pattern "src/main.sh" "src/other.sh"
		The status should be failure
	End

	It 'matches single star for single segment'
		When call file_matches_pattern "src/main.sh" "src/*.sh"
		The status should be success
	End

	It 'single star does not cross directories'
		When call file_matches_pattern "src/lib/main.sh" "src/*.sh"
		The status should be failure
	End

	It 'matches double star for recursive directories'
		When call file_matches_pattern "src/lib/deep/main.sh" "src/**"
		The status should be success
	End

	It 'matches double star with file extension'
		When call file_matches_pattern "src/lib/deep/main.sh" "src/**/*.sh"
		The status should be success
	End

	It 'matches double star at start'
		When call file_matches_pattern "deep/nested/path/file.txt" "**/*.txt"
		The status should be success
	End

	It 'matches root level with double star'
		When call file_matches_pattern "file.txt" "**/*.txt"
		The status should be success
	End

	It 'matches wildcard-only pattern'
		When call file_matches_pattern "anything/at/all.sh" "*"
		The status should be success
	End

	It 'matches double star only pattern'
		When call file_matches_pattern "any/path/here.txt" "**"
		The status should be success
	End

	It 'does not match wrong extension'
		When call file_matches_pattern "src/main.js" "src/**/*.sh"
		The status should be failure
	End

	It 'matches nested paths correctly'
		When call file_matches_pattern "scripts/cz/lib/util.sh" "scripts/cz/**"
		The status should be success
	End

	It 'matches direct child with double star'
		When call file_matches_pattern "scripts/cz/main.sh" "scripts/cz/**"
		The status should be success
	End

	It 'literal dot only matches literal dot'
		When call file_matches_pattern "fileXtxt" "file.txt"
		The status should be failure
	End

	It 'matches path with spaces'
		When call file_matches_pattern "docs/my folder/file.txt" "docs/my folder/**"
		The status should be success
	End

	It 'matches path with spaces using double star'
		When call file_matches_pattern "src/some path/nested/file.sh" "src/**"
		The status should be success
	End
End

Describe 'file_matches_scope'
	Include ./path_validator.sh

	setup_single_pattern() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		EOF
	}

	setup_multi_pattern() {
		parse_config <<-'EOF'
		[scopes]
		nix = flake.nix, flake.lock, */default.nix
		EOF
	}

	setup_catchall() {
		parse_config <<-'EOF'
		[scopes]
		any = **
		EOF
	}

	setup_space_pattern() {
		parse_config <<-'EOF'
		[scopes]
		docs = docs/my folder/**, src/some path/**
		EOF
	}

	It 'matches file against single pattern scope'
		BeforeCall setup_single_pattern
		When call file_matches_scope "src/api/handler.go" "api"
		The status should be success
	End

	It 'does not match file against wrong scope'
		BeforeCall setup_single_pattern
		When call file_matches_scope "src/ui/component.tsx" "api"
		The status should be failure
	End

	It 'matches file against multi-pattern scope'
		BeforeCall setup_multi_pattern
		When call file_matches_scope "flake.nix" "nix"
		The status should be success
	End

	It 'matches second pattern in multi-pattern scope'
		BeforeCall setup_multi_pattern
		When call file_matches_scope "flake.lock" "nix"
		The status should be success
	End

	It 'matches third pattern in multi-pattern scope'
		BeforeCall setup_multi_pattern
		When call file_matches_scope "scripts/default.nix" "nix"
		The status should be success
	End

	It 'matches catchall scope with double star pattern'
		BeforeCall setup_catchall
		When call file_matches_scope "any/file/anywhere.txt" "any"
		The status should be success
	End

	It 'matches file with spaces against scope with space patterns'
		BeforeCall setup_space_pattern
		When call file_matches_scope "docs/my folder/readme.txt" "docs"
		The status should be success
	End

	It 'matches second pattern with spaces'
		BeforeCall setup_space_pattern
		When call file_matches_scope "src/some path/nested/file.sh" "docs"
		The status should be success
	End
End

Describe 'find_matching_scope'
	Include ./path_validator.sh

	setup_scopes() {
		# Note: using 'any' instead of '*' since '*' is not a valid bash variable name
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		ui = src/ui/**
		EOF
	}

	setup_no_wildcard() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		ui = src/ui/**
		EOF
	}

	It 'finds matching scope for file'
		BeforeCall setup_scopes
		When call find_matching_scope "src/api/handler.go"
		The output should equal "api"
		The status should be success
	End

	It 'finds different matching scope'
		BeforeCall setup_scopes
		When call find_matching_scope "src/ui/button.tsx"
		The output should equal "ui"
		The status should be success
	End

	It 'returns empty for unmatched file'
		BeforeCall setup_scopes
		When call find_matching_scope "other/file.txt"
		The output should equal ""
		The status should be failure
	End

	It 'returns empty for no match'
		BeforeCall setup_no_wildcard
		When call find_matching_scope "other/file.txt"
		The output should equal ""
		The status should be failure
	End
End

Describe 'validate_files_against_scope'
	Include ./path_validator.sh

	setup_scope() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		EOF
	}

	It 'succeeds when all files match scope'
		BeforeCall setup_scope
		When call validate_files_against_scope "api" "src/api/handler.go" "src/api/routes.go"
		The status should be success
	End

	It 'fails when some files do not match scope'
		BeforeCall setup_scope
		When call validate_files_against_scope "api" "src/api/handler.go" "src/ui/button.tsx"
		The status should be failure
		The variable VALIDATION_ERRORS[0] should include "src/ui/button.tsx"
	End

	It 'fails when no files match scope'
		BeforeCall setup_scope
		When call validate_files_against_scope "api" "src/ui/a.tsx" "src/ui/b.tsx"
		The status should be failure
	End
End

Describe 'validate_files_against_scopes'
	Include ./path_validator.sh

	setup_scopes() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		ui = src/ui/**
		EOF
	}

	setup_with_separator() {
		parse_config <<-'EOF'
		[settings]
		multi-scope-separator = /
		[scopes]
		api = src/api/**
		ui = src/ui/**
		EOF
	}

	It 'succeeds when files match any of the scopes'
		BeforeCall setup_scopes
		When call validate_files_against_scopes "api,ui" "src/api/handler.go" "src/ui/button.tsx"
		The status should be success
	End

	It 'fails when file matches none of the scopes'
		BeforeCall setup_scopes
		When call validate_files_against_scopes "api,ui" "src/api/handler.go" "other/file.txt"
		The status should be failure
		The variable VALIDATION_ERRORS[0] should include "other/file.txt"
	End

	It 'uses custom separator from settings'
		BeforeCall setup_with_separator
		When call validate_files_against_scopes "api/ui" "src/api/handler.go" "src/ui/button.tsx"
		The status should be success
	End
End

Describe 'validate_strict_no_scope'
	Include ./path_validator.sh

	setup_scopes() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		ui = src/ui/**
		EOF
	}

	It 'succeeds when no files match any scope'
		BeforeCall setup_scopes
		When call validate_strict_no_scope "other/file.txt" "docs/readme.md"
		The status should be success
	End

	It 'fails when files match a scope'
		BeforeCall setup_scopes
		When call validate_strict_no_scope "src/api/handler.go" "other/file.txt"
		The status should be failure
		The variable STRICT_MATCHES[0] should include "api"
	End

	It 'reports all matches in STRICT_MATCHES'
		BeforeCall setup_scopes
		When call validate_strict_no_scope "src/api/handler.go" "src/ui/button.tsx"
		The status should be failure
	End
End
