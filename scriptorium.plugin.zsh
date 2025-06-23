# Scriptorium plugin for Zsh (source this file)

# Get the plugin directory
local plugin_dir="${0:A:h}"

# Export plugin directory for scripts to use
export SCRIPTORIUM_ROOT="$plugin_dir"

# Configure installation location
# Change this to "$HOME/.local" to install in user's home directory
# or keep as "$plugin_dir/.local" to install in plugin directory
local install_root="${SCRIPTORIUM_INSTALL_ROOT:-$plugin_dir/.local}"

# Create directories
mkdir -p "$install_root/share/man/man"{1..8}
mkdir -p "$install_root/share/zsh/site-functions"

# Process each library: setup man pages, completions, and source
for lib_dir in "$plugin_dir/lib"/*(/N); do
	local lib_name="${lib_dir:t}"

	# Source the library to make functions available
	if [[ -f "$lib_dir/$lib_name.zsh" ]]; then
		source "$lib_dir/$lib_name.zsh"
	else
		continue;
	fi

	# Link man pages for all sections (1-8)
	for section in {1..8}; do
		if [[ -f "$lib_dir/$lib_name.$section" ]]; then
			ln -sf "$lib_dir/$lib_name.$section" \
				"$install_root/share/man/man$section/$lib_name.$section"
		fi
	done

	# Link zsh completion
	if [[ -f "$lib_dir/${lib_name}_comp.zsh" ]]; then
		ln -sf "$lib_dir/${lib_name}_comp.zsh" \
			"$install_root/share/zsh/site-functions/_$lib_name"
	fi
done

# Process each script: setup man pages, completions, and source
for script_dir in "$plugin_dir/scripts"/*(/N); do
	local script_name="${script_dir:t}"

	# Source the script to make functions available
	if [[ -f "$script_dir/$script_name.zsh" ]]; then
		source "$script_dir/$script_name.zsh"
	else
		continue;
	fi

	# Link man pages for all sections (1-8)
	for section in {1..8}; do
		if [[ -f "$script_dir/$script_name.$section" ]]; then
			ln -sf "$script_dir/$script_name.$section" \
				"$install_root/share/man/man$section/$script_name.$section"
		fi
	done

	# Link zsh completion
	if [[ -f "$script_dir/${script_name}_comp.zsh" ]]; then
		ln -sf "$script_dir/${script_name}_comp.zsh" \
			"$install_root/share/zsh/site-functions/_$script_name"
	fi
done

# Add man pages to MANPATH if not already included
if [[ -d "$install_root/share/man" && ":${MANPATH:-$(manpath 2>/dev/null || echo '')}:" != *":$install_root/share/man:"* ]]; then
	export MANPATH="$install_root/share/man:${MANPATH:-$(manpath 2>/dev/null || echo '')}"
fi

# Add zsh site-functions to fpath if not already present
if [[ -d "$install_root/share/zsh/site-functions" && ! "${fpath[@]}" =~ "$install_root/share/zsh/site-functions" ]]; then
	fpath=("$install_root/share/zsh/site-functions" "${fpath[@]}")
	autoload -Uz compinit && compinit
fi
