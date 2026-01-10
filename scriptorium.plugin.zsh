# Scriptorium plugin for Zsh (source this file)

# Get plugin directory
plugin_dir="${0:A:h}"

# Add bin to PATH
PATH="$plugin_dir/bin:$PATH"

# Add man to MANPATH
MANPATH="$plugin_dir/man:${MANPATH:-}"
export MANPATH

# Add zsh completions to fpath
fpath=("$plugin_dir/completions/zsh" "${fpath[@]}")

# Initialize completion system
autoload -Uz compinit && compinit
