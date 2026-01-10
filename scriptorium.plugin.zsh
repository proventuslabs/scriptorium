# Scriptorium plugin for Zsh (source this file)

# Check bash 4+ is available (scripts require it)
if ! command -v bash &>/dev/null; then
	echo "Scriptorium requires Bash 4+ but bash was not found." >&2
	return 1
fi
if ! bash -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
	echo "Scriptorium requires Bash 4+. Found: $(bash --version | head -1)" >&2
	return 1
fi

# Get plugin directory
plugin_dir="${0:A:h}"

# Add all script bins to PATH
for dir in "$plugin_dir"/dist/*/bin(N); do
	[[ -d "$dir" ]] && PATH="$dir:$PATH"
done

# Add all script mans to MANPATH
for dir in "$plugin_dir"/dist/*/man(N); do
	[[ -d "$dir" ]] && MANPATH="$dir:${MANPATH:-}"
done
export MANPATH

# Add all zsh completions to fpath
for dir in "$plugin_dir"/dist/*/completions/zsh(N); do
	[[ -d "$dir" ]] && fpath=("$dir" "${fpath[@]}")
done

# Initialize completion system
autoload -Uz compinit && compinit
