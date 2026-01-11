# shellcheck shell=bash

# cz parse - display resolved configuration

# @bundle source
. ./config.sh

cmd_parse() {
	# Find config if not specified via -c
	if [[ -z "$CONFIG_FILE" ]]; then
		find_config || true
	fi

	load_config

	# Show config source
	if [[ -n "$CONFIG_FILE" ]]; then
		echo "Config: $CONFIG_FILE"
	else
		echo "Config: (defaults)"
	fi
	echo

	# Show settings
	if [[ -n "${CFG_SETTINGS_strict:-}" || -n "${CFG_SETTINGS_multi_scope:-}" ]]; then
		echo "Settings:"
		[[ -n "${CFG_SETTINGS_strict:-}" ]] && echo "  strict = ${CFG_SETTINGS_strict}"
		[[ -n "${CFG_SETTINGS_multi_scope:-}" ]] && echo "  multi-scope = ${CFG_SETTINGS_multi_scope}"
		[[ -n "${CFG_SETTINGS_multi_scope_separator:-}" ]] && echo "  multi-scope-separator = ${CFG_SETTINGS_multi_scope_separator}"
		echo
	fi

	# Show scopes with patterns
	if [[ ${#CFG_SCOPE_NAMES[@]} -gt 0 ]]; then
		echo "Scopes:"
		for scope in "${CFG_SCOPE_NAMES[@]}"; do
			echo "  $scope = $(get_scope_patterns "$scope")"
		done
		echo
	fi

	# Show types with descriptions
	echo "Types:"
	local max_type_len=0
	for type in "${TYPES[@]}"; do
		((${#type} > max_type_len)) && max_type_len=${#type}
	done

	for i in "${!TYPES[@]}"; do
		local type="${TYPES[$i]}"
		local desc="${DESCRIPTIONS[$i]}"
		printf "  %-${max_type_len}s  %s\n" "$type" "$desc"
	done
}
