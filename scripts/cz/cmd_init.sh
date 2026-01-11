# shellcheck shell=bash

# cz init - generate a starter .gitcommitizen file

# @bundle source
. ./config_defaults.sh

cmd_init() {
	local target=".gitcommitizen"

	if [[ -f "$target" && -z "${FORCE:-}" ]]; then
		echo "cz: error: '$target' already exists (use -f to overwrite)" >&2
		return 1
	fi

	default_config
	format_config >"$target"

	echo "Created $target"
}
