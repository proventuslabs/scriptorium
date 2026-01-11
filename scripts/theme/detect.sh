#!/usr/bin/env bash
# theme detection - detects system appearance (dark/light)
# shellcheck disable=SC2034 # THEME_APPEARANCE and THEME_SOURCE are used externally

# Detect macOS appearance via defaults command
# Sets THEME_APPEARANCE on success
_theme_detect_macos() {
	local result
	if ! command -v defaults >/dev/null 2>&1; then
		return 1
	fi

	if result=$(defaults read -g AppleInterfaceStyle 2>/dev/null); then
		# AppleInterfaceStyle is set - check if Dark
		case "${result,,}" in
			dark) THEME_APPEARANCE=dark ;;
			*) THEME_APPEARANCE=light ;;
		esac
	else
		# AppleInterfaceStyle not set means light mode
		THEME_APPEARANCE=light
	fi
	return 0
}

# Detect Linux appearance via desktop environment settings
# Sets THEME_APPEARANCE on success
_theme_detect_linux() {
	local result
	local desktop="${XDG_CURRENT_DESKTOP:-}"

	case "$desktop" in
		GNOME | Unity | ubuntu:GNOME | gnome)
			if command -v gsettings >/dev/null 2>&1; then
				result=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null) || return 1
				case "$result" in
					*prefer-dark* | *dark*) THEME_APPEARANCE=dark ;;
					*) THEME_APPEARANCE=light ;;
				esac
				return 0
			fi
			;;
		KDE | plasma)
			if command -v kreadconfig5 >/dev/null 2>&1; then
				result=$(kreadconfig5 --file kdeglobals --group General --key ColorScheme 2>/dev/null) || return 1
				case "${result,,}" in
					*dark*) THEME_APPEARANCE=dark ;;
					*) THEME_APPEARANCE=light ;;
				esac
				return 0
			elif command -v kreadconfig >/dev/null 2>&1; then
				result=$(kreadconfig --file kdeglobals --group General --key ColorScheme 2>/dev/null) || return 1
				case "${result,,}" in
					*dark*) THEME_APPEARANCE=dark ;;
					*) THEME_APPEARANCE=light ;;
				esac
				return 0
			fi
			;;
		XFCE | xfce)
			if command -v xfconf-query >/dev/null 2>&1; then
				result=$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null) || return 1
				case "${result,,}" in
					*dark*) THEME_APPEARANCE=dark ;;
					*) THEME_APPEARANCE=light ;;
				esac
				return 0
			fi
			;;
	esac

	return 1
}

# Detect Windows appearance via registry (for WSL/Cygwin)
# Sets THEME_APPEARANCE on success
_theme_detect_windows() {
	local result

	# Check if we're in WSL or have reg.exe
	if ! command -v reg.exe >/dev/null 2>&1; then
		return 1
	fi

	result=$(reg.exe query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize" /v AppsUseLightTheme 2>/dev/null) || return 1

	if [[ "$result" == *"0x0"* ]]; then
		THEME_APPEARANCE=dark
	else
		THEME_APPEARANCE=light
	fi
	return 0
}

# Main detection function
# Usage: theme_detect [override]
# Sets: THEME_APPEARANCE (dark|light), THEME_SOURCE (override|detected|environment|default)
theme_detect() {
	local override="${1:-}"

	# Handle override argument
	if [[ -n "$override" ]]; then
		case "${override,,}" in
			dark)
				THEME_APPEARANCE=dark
				THEME_SOURCE=override
				return 0
				;;
			light)
				THEME_APPEARANCE=light
				THEME_SOURCE=override
				return 0
				;;
			*)
				echo "theme: error: invalid appearance '$override' (must be 'dark' or 'light')" >&2
				return 1
				;;
		esac
	fi

	# Try OS-specific detection based on platform
	case "$(uname -s)" in
		Darwin)
			if _theme_detect_macos; then
				THEME_SOURCE=detected
				return 0
			fi
			;;
		Linux)
			# Check if WSL first
			if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
				if _theme_detect_windows; then
					THEME_SOURCE=detected
					return 0
				fi
			fi
			if _theme_detect_linux; then
				THEME_SOURCE=detected
				return 0
			fi
			;;
		CYGWIN* | MINGW* | MSYS*)
			if _theme_detect_windows; then
				THEME_SOURCE=detected
				return 0
			fi
			;;
	esac

	# Fall back to THEME environment variable
	if [[ -n "${THEME:-}" ]]; then
		case "${THEME,,}" in
			dark)
				THEME_APPEARANCE=dark
				THEME_SOURCE=environment
				return 0
				;;
			light)
				THEME_APPEARANCE=light
				THEME_SOURCE=environment
				return 0
				;;
		esac
	fi

	# Default to light
	THEME_APPEARANCE=light
	THEME_SOURCE=default
	return 0
}
