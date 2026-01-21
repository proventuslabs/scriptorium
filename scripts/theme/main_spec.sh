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
		mkdir -p "$XDG_CONFIG_HOME/theme/detectors.d"
		# Create no-op handler and detector to prevent warnings in unrelated tests
		echo 'theme_handler_noop() { :; }' > "$XDG_CONFIG_HOME/theme/handlers.d/noop.sh"
		echo 'theme_detector_noop() { THEME_APPEARANCE=light; return 0; }' > "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
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

		It 'falls back to THEME env var when set to dark'
			export THEME=dark
			When run script "$BIN" --detect
			The status should be success
			# On macOS system detection happens first, but if THEME is set it may be used
			The output should be present
		End

		It 'falls back to light when THEME env var is invalid'
			export THEME=invalid_value
			# Clear any system-level detection by running in isolated env
			When run script "$BIN" --detect
			The status should be success
			# Falls through to default light when THEME has invalid value
			The output should be present
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

		It 'shows none found when no handlers configured'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			# Remove noop handler from setup to test "none found" display
			rm -f "$XDG_CONFIG_HOME/theme/handlers.d/noop.sh"
			When run script "$BIN" --list
			The status should be success
			The output should include "theme_provider_test"
			The output should match pattern "*Handlers:*none found*"
		End

		It 'sources config.sh when present'
			cat > "$XDG_CONFIG_HOME/theme/config.sh" << 'EOF'
# Config loaded marker
THEME_CONFIG_LOADED=1
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_config_test() {
	echo "CONFIG_LOADED=${THEME_CONFIG_LOADED:-0}"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should equal "CONFIG_LOADED=1"
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

		It 'passes source to provider'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	local appearance="$1"
	local source="$2"
	echo "SOURCE=$source"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			# Source should be one of: override, detected, environment, default
			The output should match pattern "SOURCE=*"
		End

		It 'warns when no handlers found'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "PROVIDER_RAN"
}
EOF
			# Remove noop handler from setup to test warning
			rm -f "$XDG_CONFIG_HOME/theme/handlers.d/noop.sh"
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should equal "PROVIDER_RAN"
			The stderr should include "no handlers found"
		End

		It 'warns when handler file source fails'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "PROVIDER_RAN"
}
EOF
			# Create a handler file with syntax error
			echo "this is not valid bash {{{{" > "$XDG_CONFIG_HOME/theme/handlers.d/bad.sh"
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should equal "PROVIDER_RAN"
			The stderr should include "failed to source"
		End

		It 'warns when no detectors configured'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "PROVIDER_RAN"
}
EOF
			# Remove noop detector from setup to test warning
			rm -f "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should equal "PROVIDER_RAN"
			The stderr should include "no detectors configured"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PLUGGABLE DETECTION
	#═══════════════════════════════════════════════════════════════
	Describe 'pluggable detection'
		# These tests verify detection uses user-provided detector functions
		# from detectors.d/ directory, not hardcoded system detection.

		It 'uses detector function for detection'
			mkdir -p "$XDG_CONFIG_HOME/theme/detectors.d"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/always_dark.sh" << 'EOF'
theme_detector_always_dark() {
	THEME_APPEARANCE=dark
	return 0
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "DETECTED=$1"
}
EOF
			When run script "$BIN"
			The status should be success
			The output should equal "DETECTED=dark"
		End

		It 'tries detectors in alphabetical order until one succeeds'
			mkdir -p "$XDG_CONFIG_HOME/theme/detectors.d"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/aaa_fail.sh" << 'EOF'
theme_detector_aaa_fail() {
	return 1
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/bbb_dark.sh" << 'EOF'
theme_detector_bbb_dark() {
	THEME_APPEARANCE=dark
	return 0
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/ccc_light.sh" << 'EOF'
theme_detector_ccc_light() {
	THEME_APPEARANCE=light
	return 0
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "DETECTED=$1"
}
EOF
			When run script "$BIN"
			The status should be success
			The output should equal "DETECTED=dark"
		End

		It 'falls back to THEME env var when no detector succeeds'
			# Remove noop detector so only failing detector exists
			rm -f "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/always_fail.sh" << 'EOF'
theme_detector_always_fail() {
	return 1
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "SOURCE=$2"
}
EOF
			export THEME=dark
			When run script "$BIN"
			The status should be success
			The output should equal "SOURCE=environment"
		End

		It 'falls back to light when no detector and no THEME env'
			# Remove noop detector so only failing detector exists
			rm -f "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/always_fail.sh" << 'EOF'
theme_detector_always_fail() {
	return 1
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "RESULT=$1 SOURCE=$2"
}
EOF
			When run script "$BIN"
			The status should be success
			The output should equal "RESULT=light SOURCE=default"
		End

		It 'sets source to detected when detector succeeds'
			mkdir -p "$XDG_CONFIG_HOME/theme/detectors.d"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/test.sh" << 'EOF'
theme_detector_test() {
	THEME_APPEARANCE=dark
	return 0
}
EOF
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	echo "SOURCE=$2"
}
EOF
			When run script "$BIN"
			The status should be success
			The output should equal "SOURCE=detected"
		End

		It 'shows detectors in --list output'
			mkdir -p "$XDG_CONFIG_HOME/theme/detectors.d"
			cat > "$XDG_CONFIG_HOME/theme/detectors.d/macos.sh" << 'EOF'
theme_detector_macos() {
	return 1
}
EOF
			When run script "$BIN" --list
			The status should be success
			The output should include "Detectors:"
			The output should include "theme_detector_macos"
		End

		It 'shows none found when no detectors configured'
			# Remove noop detector from setup
			rm -f "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
			When run script "$BIN" --list
			The status should be success
			The output should match pattern "*Detectors:*none found*"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# QUIET MODE
	#═══════════════════════════════════════════════════════════════
	Describe 'quiet mode'
		It '-q suppresses handler failure warning'
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

		It '--quiet suppresses handler failure warning'
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

		It '-q suppresses no handlers warning'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			# Remove noop handler from setup to test warning suppression
			rm -f "$XDG_CONFIG_HOME/theme/handlers.d/noop.sh"
			export THEME=dark
			When run script "$BIN" -q
			The status should be success
			The stderr should equal ""
		End

		It '-q suppresses source failure warning'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			echo "invalid bash {{{{" > "$XDG_CONFIG_HOME/theme/handlers.d/bad.sh"
			export THEME=dark
			When run script "$BIN" -q
			The status should be success
			The stderr should equal ""
		End

		It '-q suppresses no detectors warning'
			cat > "$XDG_CONFIG_HOME/theme/provider.sh" << 'EOF'
theme_provider_test() {
	:
}
EOF
			# Remove noop detector from setup to test warning suppression
			rm -f "$XDG_CONFIG_HOME/theme/detectors.d/noop.sh"
			export THEME=dark
			When run script "$BIN" -q
			The status should be success
			The stderr should equal ""
		End
	End
End
