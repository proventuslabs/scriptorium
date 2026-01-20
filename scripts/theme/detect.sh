#!/usr/bin/env bash
# theme detection - discovers and runs user-provided detector functions
# shellcheck disable=SC2034 # THEME_APPEARANCE and THEME_SOURCE are used externally

# Main detection function
# Usage: theme_detect [override]
# Sets: THEME_APPEARANCE (dark|light), THEME_SOURCE (override|detected|environment|default)
theme_detect() {
	local override="${1:-}"

	# Handle explicit override
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

	# Try each detector in alphabetical order
	theme_discover_detectors
	local detector
	for detector in "${THEME_DETECTORS[@]}"; do
		if "$detector"; then
			THEME_SOURCE=detected
			return 0
		fi
	done

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
