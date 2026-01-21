#!/usr/bin/env bash
# Validate that shell completions match options.sh definitions
# Exit 0 if all completions are in sync, 1 if mismatches found

set -euo pipefail

# shellcheck disable=SC2034 # VERSION used by getoptions disp
VERSION=0.1.0

parser_definition() {
	setup REST help:usage abbr:true -- \
		"Usage: check-completions.sh [options] [script_dir...]" \
		'' \
		'Validate that shell completions match options.sh definitions.' \
		'If no directories specified, checks all scripts/* directories.' \
		''
	msg -- 'Options:'
	disp :usage -h --help
	disp VERSION -V --version
}

eval "$(getoptions parser_definition parse)"
parse "$@"
eval "set -- $REST"

# Extract flags from options.sh parser definitions
# Handles: flag, param, disp, option with -x --long --{no-}pattern
extract_options_flags() {
	local file="$1"
	local parser="${2:-parser_definition}"

	# Look for flag/param/disp/option lines within the parser function
	# Extract -x and --long-flag patterns
	awk -v parser="$parser" '
		# Track when we are inside the target parser function
		$0 ~ "^" parser "\\(\\)" { in_parser = 1; next }
		$0 ~ "^parser_definition" && in_parser { in_parser = 0 }
		$0 ~ "^}" && in_parser { in_parser = 0 }

		in_parser && /^\t(flag|param|disp|option)/ {
			# Extract all -X and --word patterns from the line
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^-[a-zA-Z]$/) {
					print $i
				} else if ($i ~ /^--\{no-\}/) {
					# --{no-}foo expands to --foo and --no-foo
					gsub(/--\{no-\}/, "", $i)
					print "--" $i
					print "--no-" $i
				} else if ($i ~ /^--[a-z]/) {
					# Remove trailing patterns like var:FILE
					gsub(/:.*$/, "", $i)
					# Stop at -- which separates flags from description
					if ($i == "--") break
					print $i
				}
			}
		}
	' "$file" | sort -u
}

# Extract flags from bash completion file
extract_completion_flags() {
	local file="$1"

	# Look for quoted strings containing flag lists (opts="..." or compgen -W "...")
	# Extract flags from within those quoted strings only
	grep -oE '"[^"]*"' "$file" 2>/dev/null |
		tr -d '"' |
		tr ' ' '\n' |
		grep -oE -- '^-[a-zA-Z]$|^--[a-z][-a-z]*$' |
		sort -u
}

# Compare two flag lists
# Usage: compare_flags <options_flags> <completion_flags>
compare_flags() {
	local options_flags="$1"
	local completion_flags="$2"

	local missing_in_completion missing_in_options
	missing_in_completion=$(comm -23 <(echo "$options_flags") <(echo "$completion_flags"))
	missing_in_options=$(comm -13 <(echo "$options_flags") <(echo "$completion_flags"))

	local has_error=0

	if [[ -n "$missing_in_completion" ]]; then
		echo "  Missing in completions:"
		while IFS= read -r line; do
			echo "    $line"
		done <<<"$missing_in_completion"
		has_error=1
	fi

	if [[ -n "$missing_in_options" ]]; then
		echo "  Extra in completions (not in options.sh):"
		while IFS= read -r line; do
			echo "    $line"
		done <<<"$missing_in_options"
		has_error=1
	fi

	return $has_error
}

# Check a single script directory
check_script() {
	local script_dir="$1"
	script_dir="${script_dir%/}" # Remove trailing slash

	local script_name options_file bash_completion
	script_name=$(basename "$script_dir")
	options_file="$script_dir/options.sh"
	bash_completion="$script_dir/completions/${script_name}.bash"

	# Skip if no options.sh
	[[ -f "$options_file" ]] || return 0

	echo "Checking $script_name..."

	# Check bash completion
	if [[ -f "$bash_completion" ]]; then
		local options_flags completion_flags parsers

		# Get all parser definitions in the file
		parsers=$(grep -oE '^parser_definition[_a-z]*' "$options_file" | sort -u)

		# Collect flags from all parsers
		options_flags=""
		while IFS= read -r parser; do
			options_flags+="$(extract_options_flags "$options_file" "$parser")"$'\n'
		done <<<"$parsers"
		options_flags=$(echo "$options_flags" | grep -v '^$' | sort -u)

		completion_flags=$(extract_completion_flags "$bash_completion")

		if ! compare_flags "$options_flags" "$completion_flags"; then
			return 1
		fi
	else
		echo "  No bash completion file found"
	fi

	return 0
}

main() {
	local exit_code=0
	local script_dirs=("$@")

	# Default to scripts/* if no arguments
	if [[ ${#script_dirs[@]} -eq 0 ]]; then
		for d in scripts/*/; do
			[[ -d "$d" ]] && script_dirs+=("$d")
		done
	fi

	for script_dir in "${script_dirs[@]}"; do
		if ! check_script "$script_dir"; then
			exit_code=1
		fi
	done

	if [[ $exit_code -eq 0 ]]; then
		echo "All completions in sync!"
	else
		echo ""
		echo "Completion files are out of sync with options.sh"
	fi

	return $exit_code
}

main "$@"
