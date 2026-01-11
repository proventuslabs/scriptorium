# shellcheck shell=bash disable=SC2034,SC2329

Describe 'run'
	# We test the theme_run function which is the core orchestration
	Include ./run.sh

	Describe 'theme_run'
		BeforeEach 'setup_main_test'
		setup_main_test() {
			# Clean environment
			unset THEME THEME_APPEARANCE THEME_SOURCE THEME_VARIANT THEME_ACCENT
			unset -f theme_provider_test 2>/dev/null || true
			unset -f theme_handler_test 2>/dev/null || true
			THEME_PROVIDER=""
			THEME_HANDLERS=()

			# Create a test provider
			theme_provider_test() {
				local appearance="$1"
				local source="$2"
				export THEME="$appearance"
				export THEME_SOURCE="$source"
				case "$appearance" in
					dark) export THEME_VARIANT=mocha ;;
					*) export THEME_VARIANT=latte ;;
				esac
				export THEME_ACCENT=blue
			}

			# Create a test handler that records it was called
			HANDLER_CALLED=0
			theme_handler_test() {
				HANDLER_CALLED=1
				HANDLER_THEME="$THEME"
				HANDLER_VARIANT="$THEME_VARIANT"
			}
		}

		AfterEach 'cleanup_main_test'
		cleanup_main_test() {
			unset THEME THEME_APPEARANCE THEME_SOURCE THEME_VARIANT THEME_ACCENT
			unset -f theme_provider_test 2>/dev/null || true
			unset -f theme_handler_test 2>/dev/null || true
			unset HANDLER_CALLED HANDLER_THEME HANDLER_VARIANT
		}

		It 'runs provider and handlers with detected appearance'
			When call theme_run
			The status should be success
			The variable THEME should be present
			The variable HANDLER_CALLED should equal 1
		End

		It 'passes dark override to provider'
			When call theme_run "dark"
			The status should be success
			The variable THEME should equal "dark"
			The variable THEME_VARIANT should equal "mocha"
			The variable HANDLER_CALLED should equal 1
		End

		It 'passes light override to provider'
			When call theme_run "light"
			The status should be success
			The variable THEME should equal "light"
			The variable THEME_VARIANT should equal "latte"
		End

		It 'fails when no provider found'
			unset -f theme_provider_test
			When call theme_run
			The status should equal 1
			The stderr should include "no provider"
		End

		It 'accepts auto as argument (same as no argument)'
			When call theme_run "auto"
			The status should be success
			The variable THEME should be present
			The variable HANDLER_CALLED should equal 1
		End

		It 'fails with invalid appearance value'
			When call theme_run "invalid"
			The status should equal 1
			The stderr should include "invalid appearance"
		End
	End

	Describe 'theme_run with --detect'
		BeforeEach 'setup_detect_only'
		setup_detect_only() {
			unset THEME THEME_APPEARANCE THEME_SOURCE
			HANDLER_CALLED=0
			theme_handler_test() {
				HANDLER_CALLED=1
			}
		}

		AfterEach 'cleanup_detect_only'
		cleanup_detect_only() {
			unset THEME THEME_APPEARANCE THEME_SOURCE
			unset -f theme_handler_test 2>/dev/null || true
			unset HANDLER_CALLED
		}

		It 'only detects without running provider or handlers'
			When call theme_run --detect
			The status should be success
			The output should match pattern "*"
			# Handler should NOT be called
			The variable HANDLER_CALLED should equal 0
		End
	End

	Describe 'theme_warn'
		setup_warn() { unset THEME_QUIET; }
		cleanup_warn() { unset THEME_QUIET; }
		BeforeEach 'setup_warn'
		AfterEach 'cleanup_warn'

		It 'outputs warning by default'
			When call theme_warn "test warning"
			The status should be success
			The stderr should equal "theme: warning: test warning"
		End

		It 'suppresses warning with THEME_QUIET'
			THEME_QUIET=1
			When call theme_warn "test warning"
			The status should be success
			The stderr should equal ""
		End
	End

	Describe 'theme_run with --list'
		BeforeEach 'setup_list_only'
		setup_list_only() {
			theme_provider_mytest() { :; }
			theme_handler_bat() { :; }
		}

		AfterEach 'cleanup_list_only'
		cleanup_list_only() {
			unset -f theme_provider_mytest 2>/dev/null || true
			unset -f theme_handler_bat 2>/dev/null || true
		}

		It 'lists provider and handlers without running them'
			When call theme_run --list
			The status should be success
			The output should include "Provider:"
			The output should include "theme_provider_mytest"
			The output should include "Handlers:"
			The output should include "theme_handler_bat"
		End
	End
End
