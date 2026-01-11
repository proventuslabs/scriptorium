# shellcheck shell=bash

# Find and load .gitcommitizen configuration

# @bundle source
. ./config_defaults.sh
# @bundle source
. ./config_parser.sh
# @bundle source
. ./ini_parser.sh
# @bundle source
. ./path_validator.sh
# Sets: TYPES, DESCRIPTIONS, SCOPES, GLOBAL_SCOPES, CONFIG_FILE, CONFIG_FORMAT

# Find config file by walking up directory tree
# Usage: find_config [start_dir]
# Returns: 0 if found (path in CONFIG_FILE), 1 if not found
find_config() {
	local dir="${1:-$PWD}"

	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.gitcommitizen" ]]; then
			CONFIG_FILE="$dir/.gitcommitizen"
			return 0
		fi
		dir="$(dirname "$dir")"
	done

	CONFIG_FILE=""
	return 1
}

# Detect config file format
# Usage: detect_config_format <file>
# Returns: "ini", "legacy", or "unknown"
detect_config_format() {
	local file="$1"
	local line

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and blank lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# Check for INI section header
		if [[ "$line" =~ ^\[[a-z]+\]$ ]]; then
			echo "ini"
			return 0
		fi

		# Check for pipe delimiter (legacy format)
		if [[ "$line" == *"|"* ]]; then
			echo "legacy"
			return 0
		fi

		# First non-comment, non-blank line doesn't match either format
		echo "unknown"
		return 0
	done <"$file"

	# Empty file or only comments
	echo "unknown"
	return 0
}

# Load configuration from file or use defaults
# Usage: load_config
# Requires: CONFIG_FILE to be set (empty = use defaults)
# Exits with error if CONFIG_FILE is set but file doesn't exist
# Sets CONFIG_FORMAT to "ini", "legacy", or "default"
load_config() {
	if [[ -n "$CONFIG_FILE" ]]; then
		if [[ ! -f "$CONFIG_FILE" ]]; then
			echo "cz: error: config file not found: $CONFIG_FILE" >&2
			exit 1
		fi

		CONFIG_FORMAT="$(detect_config_format "$CONFIG_FILE")"

		case "$CONFIG_FORMAT" in
			ini)
				parse_ini <"$CONFIG_FILE"
				# Build TYPES/DESCRIPTIONS arrays from INI for compatibility
				TYPES=()
				DESCRIPTIONS=()
				SCOPES=()
				GLOBAL_SCOPES=()
				for type in "${INI_TYPE_NAMES[@]}"; do
					TYPES+=("$type")
					local desc_var="INI_TYPES_$type"
					DESCRIPTIONS+=("${!desc_var:-}")
					SCOPES+=("")
				done
				;;
			legacy)
				parse_config <"$CONFIG_FILE"
				;;
			*)
				echo "cz: error: unknown config format in: $CONFIG_FILE" >&2
				exit 1
				;;
		esac
	else
		CONFIG_FORMAT="default"
		default_config
	fi
}
