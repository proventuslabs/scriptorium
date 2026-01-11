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

	# Show global scopes
	if [[ ${#GLOBAL_SCOPES[@]} -gt 0 ]]; then
		echo "Global scopes: ${GLOBAL_SCOPES[*]}"
		echo
	fi

	# Show types with descriptions and resolved scopes
	echo "Types:"
	local max_type_len=0
	for type in "${TYPES[@]}"; do
		((${#type} > max_type_len)) && max_type_len=${#type}
	done

	for i in "${!TYPES[@]}"; do
		local type="${TYPES[$i]}"
		local desc="${DESCRIPTIONS[$i]}"
		# shellcheck disable=SC2153 # SCOPES is a global array loaded by config.sh, not a misspelling of local scopes.
		local scopes="${SCOPES[$i]}"

		# Format: type (padded)  description  [scopes]
		printf "  %-${max_type_len}s  %s" "$type" "$desc"
		if [[ -n "$scopes" ]]; then
			# Convert space-separated to comma-separated for display
			local scope_display="${scopes// /, }"
			printf "  [%s]" "$scope_display"
		fi
		printf "\n"
	done
}
