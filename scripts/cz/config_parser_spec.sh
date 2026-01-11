# shellcheck shell=bash
# shellcheck disable=SC2329 # Functions invoked indirectly via ShellSpec BeforeCall

Describe 'parse_config'
	Include ./config_parser.sh

	It 'parses empty input'
		When call parse_config
		The status should be success
	End

	It 'ignores comments and blank lines'
		Data
			#|# comment
			#|
			#|  # indented comment
		End
		When call parse_config
		The status should be success
	End

	It 'parses settings section'
		Data
			#|[settings]
			#|strict = true
			#|multi-scope = false
		End
		When call parse_config
		The status should be success
		The variable CFG_SETTINGS_strict should equal "true"
		The variable CFG_SETTINGS_multi_scope should equal "false"
	End

	It 'parses scopes section'
		Data
			#|[scopes]
			#|cz = scripts/cz/**
			#|ci = .github/**
		End
		When call parse_config
		The status should be success
		The variable CFG_SCOPES_cz should equal "scripts/cz/**"
		The variable CFG_SCOPES_ci should equal ".github/**"
	End

	It 'parses types section'
		Data
			#|[types]
			#|feat = A new feature
			#|fix = A bug fix
		End
		When call parse_config
		The status should be success
		The variable CFG_TYPES_feat should equal "A new feature"
		The variable CFG_TYPES_fix should equal "A bug fix"
	End

	It 'parses full config'
		Data
			#|[settings]
			#|strict = true
			#|
			#|[scopes]
			#|api = src/api/**
			#|
			#|[types]
			#|feat = A new feature
		End
		When call parse_config
		The status should be success
		The variable CFG_SETTINGS_strict should equal "true"
		The variable CFG_SCOPES_api should equal "src/api/**"
		The variable CFG_TYPES_feat should equal "A new feature"
	End

	It 'handles values with spaces'
		Data
			#|[types]
			#|feat = A new feature for users
		End
		When call parse_config
		The status should be success
		The variable CFG_TYPES_feat should equal "A new feature for users"
	End

	It 'handles multi-value scopes'
		Data
			#|[scopes]
			#|nix = flake.nix, flake.lock, */default.nix
		End
		When call parse_config
		The status should be success
		The variable CFG_SCOPES_nix should equal "flake.nix, flake.lock, */default.nix"
	End

	It 'handles paths with spaces in scopes'
		Data
			#|[scopes]
			#|docs = docs/my folder/**, src/some path/**
		End
		When call parse_config
		The status should be success
		The variable CFG_SCOPES_docs should equal "docs/my folder/**, src/some path/**"
	End

	It 'parses multi-scope-separator setting'
		Data
			#|[settings]
			#|multi-scope-separator = /
		End
		When call parse_config
		The status should be success
		The variable CFG_SETTINGS_multi_scope_separator should equal "/"
	End

	It 'populates CFG_SCOPE_NAMES array'
		Data
			#|[scopes]
			#|api = src/api/**
			#|ui = src/ui/**
		End
		When call parse_config
		The status should be success
		The variable CFG_SCOPE_NAMES[0] should equal "api"
		The variable CFG_SCOPE_NAMES[1] should equal "ui"
	End

	It 'populates CFG_TYPE_NAMES array'
		Data
			#|[types]
			#|feat = A new feature
			#|fix = A bug fix
		End
		When call parse_config
		The status should be success
		The variable CFG_TYPE_NAMES[0] should equal "feat"
		The variable CFG_TYPE_NAMES[1] should equal "fix"
	End
End

Describe 'get_setting'
	Include ./config_parser.sh

	setup_settings() {
		parse_config <<-'EOF'
		[settings]
		strict = true
		EOF
	}

	setup_empty() {
		parse_config <<-'EOF'
		[settings]
		EOF
	}

	setup_hyphen() {
		parse_config <<-'EOF'
		[settings]
		multi-scope = true
		EOF
	}

	It 'returns setting value'
		BeforeCall setup_settings
		When call get_setting strict
		The output should equal "true"
	End

	It 'returns default when setting not found'
		BeforeCall setup_empty
		When call get_setting missing default_value
		The output should equal "default_value"
	End

	It 'handles hyphenated setting names'
		BeforeCall setup_hyphen
		When call get_setting multi-scope
		The output should equal "true"
	End
End

Describe 'scope_exists'
	Include ./config_parser.sh

	setup_scope() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**
		EOF
	}

	setup_empty() {
		parse_config <<-'EOF'
		[scopes]
		EOF
	}

	setup_wildcard() {
		parse_config <<-'EOF'
		[scopes]
		* = **
		EOF
	}

	It 'returns true when scope exists'
		BeforeCall setup_scope
		When call scope_exists api
		The status should be success
	End

	It 'returns false when scope does not exist'
		BeforeCall setup_empty
		When call scope_exists missing
		The status should be failure
	End

	It 'returns true for wildcard scope'
		BeforeCall setup_wildcard
		When call scope_exists '*'
		The status should be success
	End
End

Describe 'get_scope_patterns'
	Include ./config_parser.sh

	setup_scope() {
		parse_config <<-'EOF'
		[scopes]
		api = src/api/**, lib/api/**
		EOF
	}

	setup_empty() {
		parse_config <<-'EOF'
		[scopes]
		EOF
	}

	It 'returns patterns for scope'
		BeforeCall setup_scope
		When call get_scope_patterns api
		The output should equal "src/api/**, lib/api/**"
	End

	It 'returns empty for missing scope'
		BeforeCall setup_empty
		When call get_scope_patterns missing
		The output should equal ""
	End
End

Describe 'type_exists'
	Include ./config_parser.sh

	setup_type() {
		parse_config <<-'EOF'
		[types]
		feat = A new feature
		EOF
	}

	setup_empty() {
		parse_config <<-'EOF'
		[types]
		EOF
	}

	It 'returns true when type exists'
		BeforeCall setup_type
		When call type_exists feat
		The status should be success
	End

	It 'returns false when type does not exist'
		BeforeCall setup_empty
		When call type_exists missing
		The status should be failure
	End
End
