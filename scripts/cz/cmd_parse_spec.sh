# shellcheck shell=bash disable=SC2034

Describe 'cmd_parse'
	Include ./cmd_parse.sh

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

	Describe 'with no config file'
		It 'shows defaults indicator'
			When call cmd_parse
			The output should include "Config: (defaults)"
		End

		It 'shows default types'
			When call cmd_parse
			The output should include "feat"
			The output should include "fix"
			The output should include "docs"
		End

		It 'shows type descriptions'
			When call cmd_parse
			The output should include "A new feature"
			The output should include "A bug fix"
		End
	End

	Describe 'with config file'
		setup_config() {
			cat > .gitcommitizen << 'EOF'
[settings]
strict = true

[scopes]
api = src/api/**
ui = src/ui/**

[types]
feat = Custom feature
fix = Custom fix
EOF
		}

		BeforeEach 'setup_config'

		It 'shows config path'
			When call cmd_parse
			The output should include "Config:"
			The output should include ".gitcommitizen"
		End

		It 'shows settings'
			When call cmd_parse
			The output should include "Settings:"
			The output should include "strict = true"
		End

		It 'shows scopes with patterns'
			When call cmd_parse
			The output should include "Scopes:"
			The output should include "api = src/api/**"
			The output should include "ui = src/ui/**"
		End

		It 'shows custom types'
			When call cmd_parse
			The output should include "feat"
			The output should include "Custom feature"
		End
	End

	Describe 'with explicit config file'
		It 'uses CONFIG_FILE if set'
			cat > custom.conf << 'EOF'
[types]
custom = Custom type
EOF
			CONFIG_FILE="custom.conf"
			When call cmd_parse
			The output should include "Config: custom.conf"
			The output should include "custom"
			The output should include "Custom type"
		End

		It 'fails if CONFIG_FILE does not exist'
			CONFIG_FILE="/nonexistent/config"
			When run cmd_parse
			The status should equal 1
			The stderr should include "config file not found"
			The stderr should include "/nonexistent/config"
		End
	End
End
