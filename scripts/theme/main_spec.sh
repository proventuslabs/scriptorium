# shellcheck shell=bash

# BDD tests for theme - test all behaviors through CLI invocation
#
# Tests the bundled script as users experience it.
# Run `make build NAME=theme` before running tests.

Describe 'theme'
	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
		# Clear theme-related env vars
		unset THEME THEME_APPEARANCE THEME_SOURCE
		# Set XDG_CONFIG_HOME to isolate from user config
		export XDG_CONFIG_HOME="$TEST_DIR/config"
		mkdir -p "$XDG_CONFIG_HOME/theme/handlers.d"
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
		unset THEME THEME_APPEARANCE THEME_SOURCE XDG_CONFIG_HOME
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	# Path to the built script
	BIN="${SHELLSPEC_PROJECT_ROOT}/dist/theme/bin/theme"

	#═══════════════════════════════════════════════════════════════
	# HELP AND VERSION
	#═══════════════════════════════════════════════════════════════
	Describe 'help and version'
		It 'shows help with -h'
			When run script "$BIN" -h
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows help with --help'
			When run script "$BIN" --help
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows version with --version'
			When run script "$BIN" --version
			The status should be success
			The output should match pattern '*.*.*'
		End

		It 'shows version with -V'
			When run script "$BIN" -V
			The status should be success
			The output should match pattern '*.*.*'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# DETECTION
	#═══════════════════════════════════════════════════════════════
	Describe 'detection'
		It 'outputs appearance with -d'
			When run script "$BIN" -d
			The status should be success
			# Result is either dark or light depending on system
			The output should be present
		End

		It 'outputs appearance with --detect'
			When run script "$BIN" --detect
			The status should be success
			The output should be present
		End

		It 'accepts dark override with --detect'
			When run script "$BIN" --detect dark
			The status should be success
			The output should equal "dark"
		End

		It 'accepts light override with --detect'
			When run script "$BIN" --detect light
			The status should be success
			The output should equal "light"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# LIST
	#═══════════════════════════════════════════════════════════════
	Describe 'list'
		It 'shows provider and handlers sections with -l'
			When run script "$BIN" -l
			The status should be success
			The output should include "Provider:"
			The output should include "Handlers:"
		End

		It 'shows provider and handlers sections with --list'
			When run script "$BIN" --list
			The status should be success
			The output should include "Provider:"
			The output should include "Handlers:"
		End

		It 'shows none found when no provider configured'
			When run script "$BIN" --list
			The status should be success
			The output should include "(none found)"
		End

		It 'discovers provider from config directory'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			When run script "$BIN" --list
			The status should be success
			The output should include "theme_provider_test"
		End

		It 'discovers handlers from handlers.d directory'
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/bat.sh" << 'EOF'
theme_handler_bat() {
	:
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/fzf.sh" << 'EOF'
theme_handler_fzf() {
	:
}
EOF
			When run script "$BIN" --list
			The status should be success
			The output should include "theme_handler_bat"
			The output should include "theme_handler_fzf"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# OVERRIDE APPEARANCE
	#═══════════════════════════════════════════════════════════════
	Describe 'override appearance'
		setup_provider() {
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	local appearance="$1"
	echo "APPEARANCE=$appearance"
}
EOF
		}

		BeforeEach 'setup_provider'

		It 'accepts dark override'
			When run script "$BIN" dark
			The status should be success
			The output should equal "APPEARANCE=dark"
		End

		It 'accepts light override'
			When run script "$BIN" light
			The status should be success
			The output should equal "APPEARANCE=light"
		End

		It 'normalizes Dark to dark'
			When run script "$BIN" Dark
			The status should be success
			The output should equal "APPEARANCE=dark"
		End

		It 'normalizes LIGHT to light'
			When run script "$BIN" LIGHT
			The status should be success
			The output should equal "APPEARANCE=light"
		End

		It 'rejects invalid appearance'
			When run script "$BIN" invalid
			The status should be failure
			The stderr should include "invalid appearance"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# ORCHESTRATION
	#═══════════════════════════════════════════════════════════════
	Describe 'orchestration'
		It 'fails when no provider found'
			When run script "$BIN"
			The status should be failure
			The stderr should include "no provider"
		End

		It 'runs provider with detected appearance'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	local appearance="$1"
	local source="$2"
	echo "PROVIDER: $appearance from $source"
}
EOF
			When run script "$BIN"
			The status should be success
			# On macOS/Linux with detection available, source is "detected"
			# In CI without detection, source might be "environment" or "default"
			The output should include "PROVIDER:"
		End

		It 'runs handlers after provider'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "PROVIDER"
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/test.sh" << 'EOF'
theme_handler_test() {
	echo "HANDLER"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should include "PROVIDER"
			The output should include "HANDLER"
		End

		It 'runs multiple handlers in sorted order'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/zzz.sh" << 'EOF'
theme_handler_zzz() {
	echo "ZZZ"
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/aaa.sh" << 'EOF'
theme_handler_aaa() {
	echo "AAA"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The line 1 of output should equal "AAA"
			The line 2 of output should equal "ZZZ"
		End

		It 'continues if handler fails'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "PROVIDER"
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/fail.sh" << 'EOF'
theme_handler_aaa_fail() {
	return 1
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/pass.sh" << 'EOF'
theme_handler_zzz_pass() {
	echo "PASS"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should include "PROVIDER"
			The output should include "PASS"
			The stderr should include "failed"
		End

		It 'accepts auto as argument (same as no argument)'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	local appearance="$1"
	echo "APPEARANCE=$appearance"
}
EOF
			export THEME=light
			When run script "$BIN" auto
			The status should be success
			The output should equal "APPEARANCE=light"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# QUIET MODE
	#═══════════════════════════════════════════════════════════════
	Describe 'quiet mode'
		It '-q suppresses warnings'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/fail.sh" << 'EOF'
theme_handler_fail() {
	return 1
}
EOF
			export THEME=dark
			When run script "$BIN" -q
			The status should be success
			The stderr should equal ""
		End

		It '--quiet suppresses warnings'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/handlers.d/fail.sh" << 'EOF'
theme_handler_fail() {
	return 1
}
EOF
			export THEME=dark
			When run script "$BIN" --quiet
			The status should be success
			The stderr should equal ""
		End
	End
End
