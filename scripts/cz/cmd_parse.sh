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
	if [[ ${#CFG_SETTINGS[@]} -gt 0 ]]; then
		echo "Settings:"
		[[ -v CFG_SETTINGS[require_scope] ]] && echo "  require-scope = ${CFG_SETTINGS[require_scope]}"
		[[ -v CFG_SETTINGS[multi_scope] ]] && echo "  multi-scope = ${CFG_SETTINGS[multi_scope]}"
		[[ -v CFG_SETTINGS[multi_scope_separator] ]] && echo "  multi-scope-separator = ${CFG_SETTINGS[multi_scope_separator]}"
		echo
	fi

	# Show scopes with patterns
	if [[ ${#CFG_SCOPES[@]} -gt 0 ]]; then
		echo "Scopes:"
		local scope
		for scope in "${!CFG_SCOPES[@]}"; do
			echo "  $scope = ${CFG_SCOPES[$scope]}"
		done
		echo
	fi

	# Show types with descriptions
	echo "Types:"
	local max_type_len=0 type
	for type in "${!CFG_TYPES[@]}"; do
		((${#type} > max_type_len)) && max_type_len=${#type}
	done

	for type in "${!CFG_TYPES[@]}"; do
		printf "  %-${max_type_len}s  %s\n" "$type" "${CFG_TYPES[$type]}"
	done
}
