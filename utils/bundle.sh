#!/usr/bin/env bash
# bundle.sh — recursively inline sourced scripts into a single file

set -euo pipefail

# shellcheck disable=SC2034 # VERSION used by getoptions disp
VERSION=0.1.0

parser_definition() {
	# shellcheck disable=SC2016 # Single quotes intentional for literal backticks in help text
	setup REST help:usage abbr:true -- \
		"Usage: bundle.sh [options] <entry-file>" \
		'' \
		'Recursively inline sourced scripts into a single file.' \
		'' \
		'Features:' \
		'  - Use `# @bundle source` before a `source`/`.` to inline that file' \
		'  - Use `# @bundle cmd <command>` to inline command output' \
		'  - Use `# @bundle keep` to mark blocks to preserve when referenced by @bundle cmd -f' \
		'  - Use `# @bundle end` to mark end of block' \
		'  - Tracks included files to avoid duplicates' \
		'  - Preserves shebang from entry file, errors on mismatched shebangs' \
		'  - Source statements without `# @bundle source` are kept verbatim' \
		''
	msg -- 'Options:'
	flag STRIP_COMMENTS -s --strip-comments -- "Strip comments from source files"
	param KEEP_COMMENTS -k --keep-comments var:PATTERN -- "Regex pattern for comments to keep when stripping"
	flag HIDE_MARKERS -n --hide-markers -- "Suppress bundle marker comments"
	disp :usage -h --help
	disp VERSION -V --version
}

eval "$(getoptions parser_definition parse)"
parse "$@"
eval "set -- $REST"

STRIP_COMMENTS="${STRIP_COMMENTS:-0}"
KEEP_COMMENTS="${KEEP_COMMENTS:-}"
HIDE_MARKERS="${HIDE_MARKERS:-0}"

declare -A seen
is_entry=1
entry_shebang=""

# Output a line with the given indentation prefix
emit() {
	local indent="$1" line="$2"
	if [[ -n "$line" ]]; then
		printf '%s%s\n' "$indent" "$line"
	else
		echo
	fi
}

# Extract leading whitespace from a line
get_indent() {
	local line="$1"
	printf '%s' "${line%%[![:space:]]*}"
}

# Extract @bundle keep blocks from a file
extract_keep_blocks() {
	local file="$1"
	local in_keep=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		local stripped="${line#"${line%%[![:space:]]*}"}"

		if [[ "$stripped" == '# @bundle keep' ]]; then
			in_keep=1
			continue
		elif [[ "$stripped" == '# @bundle end' && "$in_keep" -eq 1 ]]; then
			in_keep=0
			continue
		fi

		if [[ "$in_keep" -eq 1 ]]; then
			printf '%s\n' "$line"
		fi
	done <"$file"
}

bundle_file() {
	local file="$1"
	local base_indent="${2:-}"
	local dir
	dir="$(cd "$(dirname "$file")" && pwd)"
	local bundle_next=0
	local bundle_next_indent=""
	local skip_until_end=0
	local is_first_line=1

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Handle shebangs (only valid on first line): preserve from entry file, validate in sourced files
		if [[ "$is_first_line" -eq 1 && "$line" == '#!'* ]]; then
			is_first_line=0
			if [[ "$is_entry" -eq 1 ]]; then
				entry_shebang="$line"
				echo "$line"
				is_entry=0
			elif [[ "$line" != "$entry_shebang" ]]; then
				echo "Error: shebang mismatch in ${file#"$PWD/"}" >&2
				echo "  entry:  $entry_shebang" >&2
				echo "  source: $line" >&2
				exit 1
			fi
			continue
		fi
		is_first_line=0
		is_entry=0

		# Get this line's indentation for potential use
		local line_indent
		line_indent="$(get_indent "$line")"

		# Strip leading whitespace for directive matching
		local stripped="${line#"${line%%[![:space:]]*}"}"

		# Skip lines until @bundle end
		if [[ "$skip_until_end" -eq 1 ]]; then
			if [[ "$stripped" == '# @bundle end' ]]; then
				skip_until_end=0
			fi
			continue
		fi

		# Strip full-line comments if requested (but not @bundle directives or --keep-comments pattern)
		if [[ "$STRIP_COMMENTS" -eq 1 && "$stripped" == '#'* && "$stripped" != '# @bundle'* ]]; then
			if [[ -z "$KEEP_COMMENTS" ]] || ! [[ "$stripped" =~ $KEEP_COMMENTS ]]; then
				continue
			fi
		fi

		case "$stripped" in
			'# @bundle source')
				bundle_next=1
				bundle_next_indent="$line_indent"
				;;
			'# @bundle end')
				# Stray end marker, ignore
				;;
			'# @bundle cmd '*)
				local cmd="${stripped#\# @bundle cmd }"
				local cmd_indent="$base_indent$line_indent"

				# Extract @bundle keep blocks from any -f <file> referenced in the command
				if [[ "$cmd" =~ -f[[:space:]]+([^[:space:]]+) ]]; then
					local ref_file="${BASH_REMATCH[1]}"
					local ref_path
					if [[ "$ref_file" == /* ]]; then
						ref_path="$ref_file"
					else
						ref_path="$dir/${ref_file#./}"
					fi
					if [[ -f "$ref_path" ]]; then
						local keep_content
						keep_content="$(extract_keep_blocks "$ref_path")"
						if [[ -n "$keep_content" ]]; then
							[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$cmd_indent" "# --- keep from: ${ref_path#"$PWD/"} ---" || true
							while IFS= read -r keep_line; do
								emit "$cmd_indent" "$keep_line"
							done <<<"$keep_content"
						fi
					fi
				fi

				# Run the command and indent each line of output
				# Convert << to <<- so heredocs work when indented (<<- strips leading tabs)
				[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$cmd_indent" "# --- begin: $cmd ---" || true
				while IFS= read -r cmd_line; do
					emit "$cmd_indent" "$cmd_line"
				done < <(cd "$dir" && eval "$cmd" | sed 's/<<\([^-]\)/<<-\1/g')
				[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$cmd_indent" "# --- end: $cmd ---" || true
				skip_until_end=1
				;;
			*)
				# Check for source/. statements
				if [[ "$line" =~ ^[[:space:]]*(\.|source)[[:space:]]+(.+) ]]; then
					local dep="${BASH_REMATCH[2]}"
					# Strip quotes and trailing comments
					dep="${dep%%#*}" # remove comments
					dep="${dep%% }"  # trim trailing space
					dep="${dep%\"}"
					dep="${dep#\"}"
					dep="${dep%\'}"
					dep="${dep#\'}"

					# Only bundle if explicitly marked
					if [[ "$bundle_next" -eq 0 ]]; then
						emit "$base_indent" "$line"
						continue
					fi
					bundle_next=0

					# Resolve path relative to current file's directory
					local dep_path
					if [[ "$dep" == /* ]]; then
						dep_path="$dep"
					else
						dep_path="$(cd "$dir" && realpath -m "$dep" 2>/dev/null || echo "$dir/$dep")"
					fi

					# Use the @bundle directive's indentation
					local src_indent="$base_indent$bundle_next_indent"
					if [[ -f "$dep_path" ]]; then
						if [[ -z "${seen[$dep_path]:-}" ]]; then
							seen["$dep_path"]=1
							[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$src_indent" "# --- begin: ${dep_path#"$PWD/"} ---" || true
							bundle_file "$dep_path" "$src_indent"
							[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$src_indent" "# --- end: ${dep_path#"$PWD/"} ---" || true
						else
							[[ "$HIDE_MARKERS" -eq 0 ]] && emit "$src_indent" "# --- skipped (already included): ${dep_path#"$PWD/"} ---" || true
						fi
					else
						echo "Error: file not found: $dep_path" >&2
						exit 1
					fi
				else
					# Error if @bundle was expecting a source statement
					if [[ "$bundle_next" -eq 1 ]]; then
						echo "Error: '# @bundle source' must be followed by a source statement" >&2
						echo "  file: ${file#"$PWD/"}" >&2
						echo "  got:  $line" >&2
						exit 1
					fi
					emit "$base_indent" "$line"
				fi
				;;
		esac
	done <"$file"
}

if [[ $# -lt 1 ]]; then
	echo "Usage: bundle.sh <entry-file>" >&2
	exit 1
fi

if [[ ! -f "$1" ]]; then
	echo "Error: file not found: $1" >&2
	exit 1
fi

bundle_file "$1"
