# shellcheck shell=bash disable=SC2034,SC2329

Describe 'detect'
	Include ./detect.sh

	Describe 'theme_detect'
		# theme_detect sets THEME_APPEARANCE and THEME_SOURCE

		Context 'with override argument'
			It 'uses dark override'
				When call theme_detect "dark"
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
				The variable THEME_SOURCE should equal "override"
			End

			It 'uses light override'
				When call theme_detect "light"
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
				The variable THEME_SOURCE should equal "override"
			End

			It 'normalizes Dark to dark'
				When call theme_detect "Dark"
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
			End

			It 'normalizes LIGHT to light'
				When call theme_detect "LIGHT"
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
			End

			It 'rejects invalid override'
				When call theme_detect "invalid"
				The status should equal 1
				The stderr should include "invalid appearance"
			End
		End

		Context 'with THEME environment variable'
			BeforeEach 'unset_detection_mocks'
			unset_detection_mocks() {
				# Ensure no OS detection works
				_theme_detect_macos() { return 1; }
				_theme_detect_linux() { return 1; }
				_theme_detect_windows() { return 1; }
			}

			It 'uses THEME=dark from environment'
				export THEME=dark
				When call theme_detect
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
				The variable THEME_SOURCE should equal "environment"
			End

			It 'uses THEME=light from environment'
				export THEME=light
				When call theme_detect
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
				The variable THEME_SOURCE should equal "environment"
			End

			AfterEach 'cleanup_theme_env'
			cleanup_theme_env() {
				unset THEME
			}
		End

		Context 'with no detection available'
			BeforeEach 'disable_all_detection'
			disable_all_detection() {
				unset THEME
				_theme_detect_macos() { return 1; }
				_theme_detect_linux() { return 1; }
				_theme_detect_windows() { return 1; }
			}

			It 'defaults to light'
				When call theme_detect
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
				The variable THEME_SOURCE should equal "default"
			End
		End
	End

	Describe '_theme_detect_macos'
		Context 'when defaults command returns Dark'
			BeforeEach 'mock_macos_dark'
			mock_macos_dark() {
				defaults() {
					if [[ "$1" == "read" && "$2" == "-g" && "$3" == "AppleInterfaceStyle" ]]; then
						echo "Dark"
						return 0
					fi
					return 1
				}
			}

			It 'returns dark'
				When call _theme_detect_macos
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
			End
		End

		Context 'when defaults command returns nothing (light mode)'
			BeforeEach 'mock_macos_light'
			mock_macos_light() {
				defaults() {
					# AppleInterfaceStyle not set means light mode
					return 1
				}
			}

			It 'returns light'
				When call _theme_detect_macos
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
			End
		End

		Context 'when defaults command not available'
			BeforeEach 'mock_no_defaults'
			mock_no_defaults() {
				# Simulate command not found
				unset -f defaults 2>/dev/null || true
			}

			It 'fails detection'
				Skip if "defaults available" command -v defaults
				When call _theme_detect_macos
				The status should equal 1
			End
		End
	End

	Describe '_theme_detect_linux'
		Context 'GNOME with dark theme'
			BeforeEach 'mock_gnome_dark'
			mock_gnome_dark() {
				export XDG_CURRENT_DESKTOP="GNOME"
				gsettings() {
					if [[ "$1" == "get" && "$2" == "org.gnome.desktop.interface" && "$3" == "color-scheme" ]]; then
						echo "'prefer-dark'"
						return 0
					fi
					return 1
				}
			}

			It 'detects dark from GNOME color-scheme'
				When call _theme_detect_linux
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
			End

			AfterEach 'cleanup_gnome'
			cleanup_gnome() {
				unset XDG_CURRENT_DESKTOP
				unset -f gsettings 2>/dev/null || true
			}
		End

		Context 'GNOME with light theme'
			BeforeEach 'mock_gnome_light'
			mock_gnome_light() {
				export XDG_CURRENT_DESKTOP="GNOME"
				gsettings() {
					if [[ "$1" == "get" && "$2" == "org.gnome.desktop.interface" && "$3" == "color-scheme" ]]; then
						echo "'default'"
						return 0
					fi
					return 1
				}
			}

			It 'detects light from GNOME color-scheme'
				When call _theme_detect_linux
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
			End

			AfterEach 'cleanup_gnome_light'
			cleanup_gnome_light() {
				unset XDG_CURRENT_DESKTOP
				unset -f gsettings 2>/dev/null || true
			}
		End

		Context 'KDE with dark theme'
			BeforeEach 'mock_kde_dark'
			mock_kde_dark() {
				export XDG_CURRENT_DESKTOP="KDE"
				kreadconfig5() {
					if [[ "$2" == "kdeglobals" && "$4" == "General" && "$6" == "ColorScheme" ]]; then
						echo "BreezeDark"
						return 0
					fi
					return 1
				}
			}

			It 'detects dark from KDE ColorScheme'
				When call _theme_detect_linux
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
			End

			AfterEach 'cleanup_kde'
			cleanup_kde() {
				unset XDG_CURRENT_DESKTOP
				unset -f kreadconfig5 2>/dev/null || true
			}
		End
	End

	Describe '_theme_detect_windows'
		Context 'WSL with dark theme'
			BeforeEach 'mock_wsl_dark'
			mock_wsl_dark() {
				export WSL_DISTRO_NAME="Ubuntu"
				reg.exe() {
					echo "    AppsUseLightTheme    REG_DWORD    0x0"
					return 0
				}
			}

			It 'detects dark from Windows registry'
				When call _theme_detect_windows
				The status should be success
				The variable THEME_APPEARANCE should equal "dark"
			End

			AfterEach 'cleanup_wsl'
			cleanup_wsl() {
				unset WSL_DISTRO_NAME
				unset -f reg.exe 2>/dev/null || true
			}
		End

		Context 'WSL with light theme'
			BeforeEach 'mock_wsl_light'
			mock_wsl_light() {
				export WSL_DISTRO_NAME="Ubuntu"
				reg.exe() {
					echo "    AppsUseLightTheme    REG_DWORD    0x1"
					return 0
				}
			}

			It 'detects light from Windows registry'
				When call _theme_detect_windows
				The status should be success
				The variable THEME_APPEARANCE should equal "light"
			End

			AfterEach 'cleanup_wsl_light'
			cleanup_wsl_light() {
				unset WSL_DISTRO_NAME
				unset -f reg.exe 2>/dev/null || true
			}
		End
	End
End
