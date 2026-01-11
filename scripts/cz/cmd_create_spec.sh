# shellcheck shell=bash disable=SC2034

Describe 'cmd_create'
	Include ./cmd_create.sh

	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
		# Create mock bin directory
		mkdir -p "$TEST_DIR/bin"
		# Save original PATH
		ORIG_PATH="$PATH"
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
		PATH="$ORIG_PATH"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	Describe 'gum dependency'
		It 'fails if gum is not found'
			# Remove gum from PATH by using empty PATH with just essential dirs
			PATH="/usr/bin:/bin"
			# Ensure no gum exists
			if command -v gum &>/dev/null; then
				Skip "gum is installed system-wide"
			fi
			When run cmd_create
			The status should equal 1
			The stderr should include "gum is required"
		End
	End

	Describe 'with mocked gum'
		# Create a mock gum that returns predefined values
		# No configured scopes = free-form input
		setup_mock_gum() {
			cat > "$TEST_DIR/bin/gum" << 'MOCK'
#!/bin/bash
case "$1" in
	choose)
		# Return first type
		echo "feat - A new feature"
		;;
	input)
		# Return test input based on header
		if [[ "$*" == *"Scope"* ]] || [[ "$*" == *"scope"* ]]; then
			echo "api"
		elif [[ "$*" == *"Description"* ]]; then
			echo "add new feature"
		fi
		;;
	confirm)
		# Return false (no breaking change)
		exit 1
		;;
	write)
		# Return empty for body/footer
		echo ""
		;;
esac
MOCK
			chmod +x "$TEST_DIR/bin/gum"
			PATH="$TEST_DIR/bin:$PATH"
		}

		BeforeEach 'setup_mock_gum'

		It 'outputs formatted commit message'
			When call cmd_create
			The status should be success
			The output should equal "feat(api): add new feature"
		End

		It 'loads default config when no config file'
			When call cmd_create
			The status should be success
			The output should include "feat"
		End
	End

	Describe 'with breaking change'
		setup_breaking_gum() {
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
		# Return true (is breaking change)
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
			When call cmd_create
			The status should be success
			The line 1 of output should equal "feat!: change api"
		End

		It 'includes BREAKING CHANGE footer'
			When call cmd_create
			The status should be success
			The output should include "BREAKING CHANGE: removed deprecated endpoints"
		End
	End

	Describe 'with body'
		setup_body_gum() {
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
			When call cmd_create
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

		Describe 'default mode with custom option'
			setup_custom_gum() {
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
				When call cmd_create
				The status should be success
				The output should equal "feat(custom-scope): add button"
			End
		End

		Describe 'default mode selecting from list'
			setup_list_gum() {
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
				When call cmd_create
				The status should be success
				The output should equal "feat(ui): add button"
			End
		End

		Describe 'strict mode'
			setup_strict_gum() {
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

			BeforeEach 'setup_strict_gum'

			It 'only allows configured scopes with STRICT_SCOPES'
				STRICT_SCOPES=1
				When call cmd_create
				The status should be success
				The output should equal "feat(api): add button"
			End
		End
	End
End
