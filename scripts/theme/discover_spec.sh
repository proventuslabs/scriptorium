# shellcheck shell=bash disable=SC2034,SC2329

Describe 'discover'
	Include ./discover.sh

	Describe 'theme_discover_provider'
		BeforeEach 'cleanup_providers'
		cleanup_providers() {
			# Remove any existing provider functions
			unset -f theme_provider_test 2>/dev/null || true
			unset -f theme_provider_other 2>/dev/null || true
			unset -f theme_provider_catppuccin 2>/dev/null || true
			unset -f theme_provider_aaa 2>/dev/null || true
			unset -f theme_provider_zzz 2>/dev/null || true
			THEME_PROVIDER=""
		}

		It 'discovers provider by function prefix'
			theme_provider_catppuccin() { :; }
			When call theme_discover_provider
			The status should be success
			The variable THEME_PROVIDER should equal "theme_provider_catppuccin"
		End

		It 'returns first provider when multiple exist'
			theme_provider_aaa() { :; }
			theme_provider_zzz() { :; }
			When call theme_discover_provider
			The status should be success
			The variable THEME_PROVIDER should equal "theme_provider_aaa"
		End

		It 'fails when no provider found'
			When call theme_discover_provider
			The status should equal 1
			The variable THEME_PROVIDER should equal ""
		End
	End

	Describe 'theme_discover_handlers'
		BeforeEach 'cleanup_handlers'
		cleanup_handlers() {
			# Remove any existing handler functions
			unset -f theme_handler_bat 2>/dev/null || true
			unset -f theme_handler_fzf 2>/dev/null || true
			unset -f theme_handler_vivid 2>/dev/null || true
			unset -f theme_handler_aaa 2>/dev/null || true
			unset -f theme_handler_mmm 2>/dev/null || true
			unset -f theme_handler_zzz 2>/dev/null || true
			THEME_HANDLERS=()
		}

		It 'discovers handlers by function prefix'
			theme_handler_bat() { :; }
			theme_handler_fzf() { :; }
			When call theme_discover_handlers
			The status should be success
			# Check array length is 2
			The value "${#THEME_HANDLERS[@]}" should equal 2
		End

		It 'returns handlers in sorted order'
			theme_handler_zzz() { :; }
			theme_handler_aaa() { :; }
			theme_handler_mmm() { :; }
			When call theme_discover_handlers
			The status should be success
			# First handler should be aaa (alphabetically first)
			The value "${THEME_HANDLERS[0]}" should equal "theme_handler_aaa"
		End

		It 'returns empty array when no handlers found'
			When call theme_discover_handlers
			The status should be success
			The value "${#THEME_HANDLERS[@]}" should equal 0
		End
	End

	Describe 'theme_source_handlers_dir'
		# Note: This tests sourcing from handlers.d directory

		It 'handles non-existent directory gracefully'
			When call theme_source_handlers_dir "/nonexistent/path"
			The status should be success
		End

		It 'sources handler files from directory'
			# Setup temp dir inline
			TEST_HANDLERS_DIR=$(mktemp -d)
			cat > "$TEST_HANDLERS_DIR/test.sh" << 'EOF'
theme_handler_from_file() {
	export TEST_HANDLER_CALLED=1
}
EOF
			When call theme_source_handlers_dir "$TEST_HANDLERS_DIR"
			The status should be success
			# Function should now be defined
			The value "$(type -t theme_handler_from_file 2>/dev/null)" should equal "function"
			# Cleanup
			rm -rf "$TEST_HANDLERS_DIR"
			unset -f theme_handler_from_file 2>/dev/null || true
		End

		It 'ignores non-.sh files'
			TEST_HANDLERS_DIR=$(mktemp -d)
			# Create a non-.sh file only
			echo "theme_handler_ignored() { :; }" > "$TEST_HANDLERS_DIR/ignored.txt"
			When call theme_source_handlers_dir "$TEST_HANDLERS_DIR"
			The status should be success
			# ignored.txt should not be sourced
			The value "$(type -t theme_handler_ignored 2>/dev/null)" should not equal "function"
			# Cleanup
			rm -rf "$TEST_HANDLERS_DIR"
		End
	End

	Describe 'theme_list'
		BeforeEach 'setup_list_test'
		setup_list_test() {
			theme_provider_mytest() { :; }
			theme_handler_bat() { :; }
			theme_handler_fzf() { :; }
		}

		It 'lists provider and handlers'
			When call theme_list
			The status should be success
			The output should include "Provider:"
			The output should include "theme_provider_mytest"
			The output should include "Handlers:"
			The output should include "theme_handler_bat"
			The output should include "theme_handler_fzf"
		End

		AfterEach 'cleanup_list_test'
		cleanup_list_test() {
			unset -f theme_provider_mytest 2>/dev/null || true
			unset -f theme_handler_bat 2>/dev/null || true
			unset -f theme_handler_fzf 2>/dev/null || true
		}
	End
End
