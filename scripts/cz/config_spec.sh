# shellcheck shell=bash

Describe 'detect_config_format'
	Include ./config.sh

	setup() {
		TEST_DIR=$(mktemp -d)
	}

	cleanup() {
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	It 'detects INI format by [section]'
		cat > "$TEST_DIR/config" <<-'EOF'
		[settings]
		strict = true
		EOF
		When call detect_config_format "$TEST_DIR/config"
		The output should equal "ini"
	End

	It 'detects legacy format by pipe |'
		cat > "$TEST_DIR/config" <<-'EOF'
		feat|A new feature|api
		EOF
		When call detect_config_format "$TEST_DIR/config"
		The output should equal "legacy"
	End

	It 'returns unknown for unrecognized format'
		cat > "$TEST_DIR/config" <<-'EOF'
		some random content
		EOF
		When call detect_config_format "$TEST_DIR/config"
		The output should equal "unknown"
	End
End

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

	It 'sets CONFIG_FORMAT correctly for INI files'
		cat > "$TEST_DIR/config" <<-'EOF'
		[types]
		feat = A new feature
		EOF
		CONFIG_FILE="$TEST_DIR/config"
		When call load_config
		The status should be success
		The variable CONFIG_FORMAT should equal "ini"
	End

	It 'sets CONFIG_FORMAT correctly for legacy files'
		cat > "$TEST_DIR/config" <<-'EOF'
		feat|A new feature|api
		EOF
		CONFIG_FILE="$TEST_DIR/config"
		When call load_config
		The status should be success
		The variable CONFIG_FORMAT should equal "legacy"
	End
End
