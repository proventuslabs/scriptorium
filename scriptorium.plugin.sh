# shellcheck shell=bash
# Scriptorium plugin for Bash v4+ (source this file)

# Check bash version
if ((BASH_VERSINFO[0] < 4)); then
	echo "Scriptorium requires Bash 4+. Current version: $BASH_VERSION" >&2
	return 1
fi

# Get the plugin directory
plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add all script bins to PATH
for dir in "$plugin_dir"/dist/*/bin; do
	[[ -d "$dir" ]] && PATH="$dir:$PATH"
done

# Add all script mans to MANPATH
for dir in "$plugin_dir"/dist/*/man; do
	[[ -d "$dir" ]] && MANPATH="$dir:${MANPATH:-}"
done
export MANPATH

# Source bash completions
for comp in "$plugin_dir"/dist/*/completions/bash/*.bash; do
	[[ -f "$comp" ]] && source "$comp"
done
