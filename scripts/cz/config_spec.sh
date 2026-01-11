# shellcheck shell=bash
# shellcheck disable=SC2034,SC2329

Describe 'load_config'
	Include ./config.sh

	setup() {
		TEST_DIR=$(mktemp -d)
	}

	cleanup() {
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	It 'loads types from INI config'
		cat > "$TEST_DIR/config" <<-'EOF'
		[types]
		feat = A new feature
		fix = A bug fix
		EOF
		CONFIG_FILE="$TEST_DIR/config"
		When call load_config
		The status should be success
		The variable TYPES[0] should equal "feat"
		The variable TYPES[1] should equal "fix"
		The variable DESCRIPTIONS[0] should equal "A new feature"
	End

	It 'loads defaults when no config file'
		CONFIG_FILE=""
		When call load_config
		The status should be success
		The variable TYPES[0] should equal "feat"
	End

	It 'errors when config file not found'
		CONFIG_FILE="$TEST_DIR/nonexistent"
		When run load_config
		The status should be failure
		The stderr should include "not found"
	End
End
