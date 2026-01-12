# shellcheck shell=bash
# shellcheck disable=SC2329 # Functions invoked indirectly via ShellSpec BeforeCall

Describe 'parse_config'
	Include ./config_defaults.sh
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
		The variable 'CFG_SETTINGS[strict]' should equal "true"
		The variable 'CFG_SETTINGS[multi_scope]' should equal "false"
	End

	It 'parses scopes section'
		Data
			#|[scopes]
			#|cz = scripts/cz/**
			#|ci = .github/**
		End
		When call parse_config
		The status should be success
		The variable 'CFG_SCOPES[cz]' should equal "scripts/cz/**"
		The variable 'CFG_SCOPES[ci]' should equal ".github/**"
	End

	It 'parses types section'
		Data
			#|[types]
			#|feat = A new feature
			#|fix = A bug fix
		End
		When call parse_config
		The status should be success
		The variable 'CFG_TYPES[feat]' should equal "A new feature"
		The variable 'CFG_TYPES[fix]' should equal "A bug fix"
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
		The variable 'CFG_SETTINGS[strict]' should equal "true"
		The variable 'CFG_SCOPES[api]' should equal "src/api/**"
		The variable 'CFG_TYPES[feat]' should equal "A new feature"
	End

	It 'handles values with spaces'
		Data
			#|[types]
			#|feat = A new feature for users
		End
		When call parse_config
		The status should be success
		The variable 'CFG_TYPES[feat]' should equal "A new feature for users"
	End

	It 'handles multi-value scopes'
		Data
			#|[scopes]
			#|nix = flake.nix, flake.lock, */default.nix
		End
		When call parse_config
		The status should be success
		The variable 'CFG_SCOPES[nix]' should equal "flake.nix, flake.lock, */default.nix"
	End

	It 'handles paths with spaces in scopes'
		Data
			#|[scopes]
			#|docs = docs/my folder/**, src/some path/**
		End
		When call parse_config
		The status should be success
		The variable 'CFG_SCOPES[docs]' should equal "docs/my folder/**, src/some path/**"
	End

	It 'parses multi-scope-separator setting'
		Data
			#|[settings]
			#|multi-scope-separator = /
		End
		When call parse_config
		The status should be success
		The variable 'CFG_SETTINGS[multi_scope_separator]' should equal "/"
	End

	It 'populates CFG_SCOPES keys'
		Data
			#|[scopes]
			#|api = src/api/**
			#|ui = src/ui/**
		End
		When call parse_config
		The status should be success
		The variable 'CFG_SCOPES[api]' should be present
		The variable 'CFG_SCOPES[ui]' should be present
	End

	It 'populates CFG_TYPES keys'
		Data
			#|[types]
			#|feat = A new feature
			#|fix = A bug fix
		End
		When call parse_config
		The status should be success
		The variable 'CFG_TYPES[feat]' should be present
		The variable 'CFG_TYPES[fix]' should be present
	End
End
