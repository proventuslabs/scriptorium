# shellcheck shell=bash
# Scriptorium plugin for Bash v4+ (source this file)

# Get the plugin directory
plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add bin to PATH
PATH="$plugin_dir/bin:$PATH"

# Add man to MANPATH
MANPATH="$plugin_dir/man:${MANPATH:-}"
export MANPATH

# Source bash completions
for comp in "$plugin_dir"/completions/bash/*.bash; do
	[[ -f "$comp" ]] && source "$comp"
done
