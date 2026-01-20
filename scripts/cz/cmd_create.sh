# shellcheck shell=bash

# cz create - compose a commit message interactively

# @bundle source
. ./config.sh

# Gum wrapper - exits 130 on cancel
_gum() { gum "$@" || exit 130; }

# Prompt for free-form scope input (header varies for test compatibility)
_scope_input_optional() { _gum input --header "Scope (optional):" --placeholder "e.g., api, ui, core"; }
_scope_input_custom() { _gum input --header "Enter scope:" --placeholder "e.g., api, ui, core"; }

cmd_create() {
	# Check gum dependency
	if ! command -v gum &>/dev/null; then
		echo "cz: error: gum is required for interactive mode" >&2
		echo "See: https://github.com/charmbracelet/gum" >&2
		exit 1
	fi

	ensure_config

	# Build type choices: "type - description"
	local type_choices=() t
	for t in "${!CFG_TYPES[@]}"; do
		type_choices+=("$t - ${CFG_TYPES[$t]}")
	done

	# Select type
	local type_selection
	type_selection=$(_gum choose --header "Select commit type:" "${type_choices[@]}")
	local type="${type_selection%% - *}"

	# Determine require-scope mode (--require-scope/--no-require-scope override config)
	local require_scope
	if [[ "${REQUIRE_SCOPE-unset}" == "1" ]]; then
		require_scope=true
	elif [[ "${REQUIRE_SCOPE-unset}" == "" ]]; then
		require_scope=false
	else
		require_scope="${CFG_SETTINGS[require_scope]:-false}"
	fi

	# Determine custom-scope mode (--custom-scope/--no-custom-scope)
	# Default (unset) allows custom scope; --no-custom-scope disables it
	local allow_custom_scope=true
	[[ "${CUSTOM_SCOPE-unset}" == "" ]] && allow_custom_scope=false

	# Select or input scope
	local scope=""
	if [[ ${#CFG_SCOPES[@]} -gt 0 ]]; then
		# Build scope choices from configured scopes (skip wildcard)
		local scope_choices=() s
		for s in "${!CFG_SCOPES[@]}"; do
			[[ "$s" == "*" ]] && continue
			scope_choices+=("$s")
		done

		if [[ ${#scope_choices[@]} -gt 0 ]]; then
			local scope_selection
			# Add options based on flags:
			# - (custom): only if allow_custom_scope is true
			# - (none): only if require_scope is not set
			[[ "$allow_custom_scope" == "true" ]] && scope_choices+=("(custom)")
			[[ "$require_scope" != "true" ]] && scope_choices+=("(none)")

			scope_selection=$(_gum choose --header "Select scope:" "${scope_choices[@]}")
			case "$scope_selection" in
				"(custom)") scope=$(_scope_input_custom) ;;
				"(none)") ;;
				*) scope="$scope_selection" ;;
			esac
		else
			# No configured scopes - fall back to free input
			if [[ "$require_scope" == "true" ]]; then
				scope=$(_scope_input_custom)
			else
				scope=$(_scope_input_optional)
			fi
		fi
	else
		# No scopes section - fall back to free input
		if [[ "$require_scope" == "true" ]]; then
			scope=$(_scope_input_custom)
		else
			scope=$(_scope_input_optional)
		fi
	fi

	# Ask about breaking change
	local breaking=""
	gum confirm "Is this a breaking change?" && breaking="!"

	# Get description (required)
	local description=""
	while [[ -z "$description" ]]; do
		description=$(_gum input --header "Description (required):" --placeholder "Short summary of the change")
		[[ -z "$description" ]] && echo "cz: error: description cannot be empty" >&2
	done

	# Get body (optional)
	local body
	body=$(_gum write --header "Body (optional, Ctrl+D to finish):" --placeholder "Detailed explanation of the change...")

	# Get footer
	local footer=""
	if [[ -n "$breaking" ]]; then
		local breaking_explanation=""
		while [[ -z "$breaking_explanation" ]]; do
			breaking_explanation=$(_gum write --header "Breaking change explanation (required):" --placeholder "Describe what breaks and how to migrate...")
			[[ -z "$breaking_explanation" ]] && echo "cz: error: breaking change explanation is required" >&2
		done
		footer="BREAKING CHANGE: $breaking_explanation"
	else
		footer=$(_gum write --header "Footer (optional, Ctrl+D to finish):" --placeholder "Closes #123, Co-authored-by: ...")
	fi

	# Format output
	local header="$type"
	[[ -n "$scope" ]] && header="${header}(${scope})"
	header="${header}${breaking}: ${description}"

	echo "$header"
	[[ -n "$body" ]] && {
		echo
		echo "$body"
	}
	[[ -n "$footer" ]] && {
		echo
		echo "$footer"
	}
	return 0
}
