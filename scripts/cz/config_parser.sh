# shellcheck shell=bash

# Parse .gitcommitizen configuration from stdin
# Usage: parse_config < config_file
# Sets arrays: TYPES, DESCRIPTIONS, SCOPES, GLOBAL_SCOPES
parse_config() {
	TYPES=()
	DESCRIPTIONS=()
	GLOBAL_SCOPES=()
	SCOPES=()

	[[ -t 0 ]] && return 0

	# Track type indices (last definition wins)
	declare -A type_indices
	local -a type_scope_mods=()

	local line type desc scopes

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and blank lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# Split by pipe
		IFS='|' read -r type desc scopes <<<"$line"

		# Trim whitespace
		type="${type#"${type%%[![:space:]]*}"}"
		type="${type%"${type##*[![:space:]]}"}"
		desc="${desc#"${desc%%[![:space:]]*}"}"
		desc="${desc%"${desc##*[![:space:]]}"}"
		scopes="${scopes#"${scopes%%[![:space:]]*}"}"
		scopes="${scopes%"${scopes##*[![:space:]]}"}"

		# Handle global scopes (type is *)
		if [[ "$type" == '*' ]]; then
			GLOBAL_SCOPES=()
			IFS=',' read -ra scope_list <<<"$scopes"
			for scope in "${scope_list[@]}"; do
				scope="${scope#"${scope%%[![:space:]]*}"}"
				scope="${scope%"${scope##*[![:space:]]}"}"
				scope="${scope#+}"
				[[ -n "$scope" ]] && GLOBAL_SCOPES+=("$scope")
			done
		elif [[ -n "$type" ]]; then
			# Last definition wins
			if [[ -v type_indices[$type] ]]; then
				idx="${type_indices[$type]}"
				DESCRIPTIONS[idx]="$desc"
				type_scope_mods[idx]="$scopes"
			else
				type_indices[$type]=${#TYPES[@]}
				TYPES+=("$type")
				DESCRIPTIONS+=("$desc")
				type_scope_mods+=("$scopes")
			fi
		fi
	done

	# Build SCOPES array by applying modifiers to global scopes
	for i in "${!TYPES[@]}"; do
		local -a type_scopes=()
		local -a adds=() removes=()

		# Start with global scopes
		type_scopes+=("${GLOBAL_SCOPES[@]}")

		# Parse scope modifiers
		if [[ -n "${type_scope_mods[$i]}" ]]; then
			IFS=',' read -ra mods <<<"${type_scope_mods[$i]}"
			for mod in "${mods[@]}"; do
				mod="${mod#"${mod%%[![:space:]]*}"}"
				mod="${mod%"${mod##*[![:space:]]}"}"
				[[ -z "$mod" ]] && continue

				if [[ "$mod" == -* ]]; then
					# Remove scope
					removes+=("${mod#-}")
				else
					# Add scope (strip optional +)
					adds+=("${mod#+}")
				fi
			done
		fi

		# Add new scopes
		type_scopes+=("${adds[@]}")

		# Remove blacklisted scopes
		if [[ ${#removes[@]} -gt 0 ]]; then
			local -a filtered_scopes=()
			for scope in "${type_scopes[@]}"; do
				local removed=false
				for rm_scope in "${removes[@]}"; do
					[[ "$scope" == "$rm_scope" ]] && removed=true && break
				done
				$removed || filtered_scopes+=("$scope")
			done
			type_scopes=("${filtered_scopes[@]}")
		fi

		SCOPES+=("${type_scopes[*]}")
	done
}
