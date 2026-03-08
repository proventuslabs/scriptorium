# shellcheck shell=bash

# cz init - generate a starter .gitcommitizen file

# @bundle source
. ./helpers.sh
# @bundle source
. ./config_defaults.sh

cmd_init() {
	default_config

	# If no output file specified, print to stdout
	if [[ -z "${OUTPUT_FILE:-}" ]]; then
		format_config
		return 0
	fi

	# Write to file
	if [[ -f "$OUTPUT_FILE" && -z "${FORCE:-}" ]]; then
		_err "'$OUTPUT_FILE' already exists (use -f to overwrite)"
		return 1
	fi

	format_config >"$OUTPUT_FILE"
}
