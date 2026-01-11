# shellcheck shell=bash

# cz create - compose a commit message interactively

# @bundle source
. ./config.sh

cmd_create() {
	# Check gum dependency
	if ! command -v gum &>/dev/null; then
		echo "cz: error: gum is required for interactive mode" >&2
		echo "See: https://github.com/charmbracelet/gum" >&2
		exit 1
	fi

	# Load config if not already loaded
	if [[ -z "${TYPES+x}" || ${#TYPES[@]} -eq 0 ]]; then
		if [[ -z "${CONFIG_FILE:-}" ]]; then
			find_config || true
		fi
		load_config
	fi

	# Build type choices: "type - description"
	local type_choices=()
	for i in "${!TYPES[@]}"; do
		type_choices+=("${TYPES[$i]} - ${DESCRIPTIONS[$i]}")
	done

	# Select type
	local type_selection
	if ! type_selection=$(gum choose --header "Select commit type:" "${type_choices[@]}"); then
		exit 130
	fi
	local type="${type_selection%% - *}"

	# Find type index for scope lookup
	local type_index=-1
	for i in "${!TYPES[@]}"; do
		if [[ "${TYPES[$i]}" == "$type" ]]; then
			type_index=$i
			break
		fi
	done

	# Select or input scope
	local scope=""
	local allowed_scopes="${SCOPES[$type_index]:-}"

	if [[ -n "$allowed_scopes" ]]; then
		# Build scope choices
		local scope_choices=()
		for s in $allowed_scopes; do
			scope_choices+=("$s")
		done

		if [[ -n "${STRICT_SCOPES:-}" ]]; then
			# Strict mode: only configured scopes
			scope_choices+=("(none)")
			local scope_selection
			if ! scope_selection=$(gum choose --header "Select scope:" "${scope_choices[@]}"); then
				exit 130
			fi
			if [[ "$scope_selection" != "(none)" ]]; then
				scope="$scope_selection"
			fi
		else
			# Default: configured scopes + custom option
			scope_choices+=("(custom)" "(none)")
			local scope_selection
			if ! scope_selection=$(gum choose --header "Select scope:" "${scope_choices[@]}"); then
				exit 130
			fi
			if [[ "$scope_selection" == "(custom)" ]]; then
				if ! scope=$(gum input --header "Enter scope:" --placeholder "e.g., api, ui, core"); then
					exit 130
				fi
			elif [[ "$scope_selection" != "(none)" ]]; then
				scope="$scope_selection"
			fi
		fi
	else
		# No configured scopes: free-form input
		if ! scope=$(gum input --header "Scope (optional):" --placeholder "e.g., api, ui, core"); then
			exit 130
		fi
	fi

	# Ask about breaking change
	local breaking=""
	if gum confirm "Is this a breaking change?"; then
		breaking="!"
	fi

	# Get description (required)
	local description=""
	while [[ -z "$description" ]]; do
		if ! description=$(gum input --header "Description (required):" --placeholder "Short summary of the change"); then
			exit 130
		fi
		if [[ -z "$description" ]]; then
			echo "cz: error: description cannot be empty" >&2
		fi
	done

	# Get body (optional)
	local body=""
	if ! body=$(gum write --header "Body (optional, Ctrl+D to finish):" --placeholder "Detailed explanation of the change..."); then
		exit 130
	fi

	# Get footer
	local footer=""
	if [[ -n "$breaking" ]]; then
		# Breaking change requires explanation
		local breaking_explanation=""
		while [[ -z "$breaking_explanation" ]]; do
			if ! breaking_explanation=$(gum write --header "Breaking change explanation (required):" --placeholder "Describe what breaks and how to migrate..."); then
				exit 130
			fi
			if [[ -z "$breaking_explanation" ]]; then
				echo "cz: error: breaking change explanation is required" >&2
			fi
		done
		footer="BREAKING CHANGE: $breaking_explanation"
	else
		# Optional footer
		if ! footer=$(gum write --header "Footer (optional, Ctrl+D to finish):" --placeholder "Closes #123, Co-authored-by: ..."); then
			exit 130
		fi
	fi

	# Format output
	local header="$type"
	if [[ -n "$scope" ]]; then
		header="${header}(${scope})"
	fi
	header="${header}${breaking}: ${description}"

	echo "$header"
	if [[ -n "$body" ]]; then
		echo
		echo "$body"
	fi
	if [[ -n "$footer" ]]; then
		echo
		echo "$footer"
	fi
}
