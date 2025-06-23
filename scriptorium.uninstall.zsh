#!/usr/bin/env zsh
# Scriptorium uninstall script - exactly undoes what scriptorium.plugin.zsh does (run this script)

set -euo pipefail

# Use SCRIPTORIUM_ROOT if available, otherwise calculate from script location
if [[ -z "${SCRIPTORIUM_ROOT:-}" ]]; then
	plugin_dir="$(cd "$(dirname "${0:A}")" && pwd)"
	echo "SCRIPTORIUM_ROOT not set, using script location: $plugin_dir"
else
	plugin_dir="$SCRIPTORIUM_ROOT"
	echo "Using SCRIPTORIUM_ROOT: $plugin_dir"
fi

# Use the same install_root logic as the plugin
install_root="${SCRIPTORIUM_INSTALL_ROOT:-$plugin_dir/.local}"

echo "Uninstalling Scriptorium plugin from: $install_root"

# UNDO: Remove symlinks created for libraries
if [[ -d "$plugin_dir/lib" ]]; then
	for lib_dir in "$plugin_dir/lib"/*(/N); do
		if [[ -d "$lib_dir" ]]; then
			lib_name="$(basename "$lib_dir")"

			# UNDO: Remove man page symlinks for all sections (1-8)
			for section in {1..8}; do
				man_link="$install_root/share/man/man$section/$lib_name.$section"
				if [[ -L "$man_link" ]]; then
					rm "$man_link"
					echo "Removed man page symlink: $man_link"
				fi
			done

			# UNDO: Remove zsh completion symlink
			comp_link="$install_root/share/zsh/site-functions/_$lib_name"
			if [[ -L "$comp_link" ]]; then
				rm "$comp_link"
				echo "Removed completion symlink: $comp_link"
			fi
		fi
	done
fi

# UNDO: Remove symlinks created for scripts
if [[ -d "$plugin_dir/scripts" ]]; then
	for script_dir in "$plugin_dir/scripts"/*(/N); do
		if [[ -d "$script_dir" ]]; then
			script_name="$(basename "$script_dir")"

			# UNDO: Remove man page symlinks for all sections (1-8)
			for section in {1..8}; do
				man_link="$install_root/share/man/man$section/$script_name.$section"
				if [[ -L "$man_link" ]]; then
					rm "$man_link"
					echo "Removed man page symlink: $man_link"
				fi
			done

			# UNDO: Remove zsh completion symlink
			comp_link="$install_root/share/zsh/site-functions/_$script_name"
			if [[ -L "$comp_link" ]]; then
				rm "$comp_link"
				echo "Removed completion symlink: $comp_link"
			fi
		fi
	done
fi

# UNDO: Remove directories created by mkdir -p (in reverse order, checking if empty)
# Remove individual man section directories if empty
for section in {1..8}; do
	man_section_dir="$install_root/share/man/man$section"
	if [[ -d "$man_section_dir" && -z "$(ls -A "$man_section_dir" 2>/dev/null)" ]]; then
		rmdir "$man_section_dir"
		echo "Removed empty directory: $man_section_dir"
	fi
done

# Remove man directory if empty
if [[ -d "$install_root/share/man" && -z "$(ls -A "$install_root/share/man" 2>/dev/null)" ]]; then
	rmdir "$install_root/share/man"
	echo "Removed empty directory: $install_root/share/man"
fi

# Remove site-functions directory if empty
if [[ -d "$install_root/share/zsh/site-functions" && -z "$(ls -A "$install_root/share/zsh/site-functions" 2>/dev/null)" ]]; then
	rmdir "$install_root/share/zsh/site-functions"
	echo "Removed empty directory: $install_root/share/zsh/site-functions"
fi

# Remove zsh directory if empty
if [[ -d "$install_root/share/zsh" && -z "$(ls -A "$install_root/share/zsh" 2>/dev/null)" ]]; then
	rmdir "$install_root/share/zsh"
	echo "Removed empty directory: $install_root/share/zsh"
fi

# Remove share directory if empty
if [[ -d "$install_root/share" && -z "$(ls -A "$install_root/share" 2>/dev/null)" ]]; then
	rmdir "$install_root/share"
	echo "Removed empty directory: $install_root/share"
fi

# Remove install_root directory if empty (only if it's the plugin-local .local directory)
if [[ "$install_root" == "$plugin_dir/.local" && -d "$install_root" && -z "$(ls -A "$install_root" 2>/dev/null)" ]]; then
	rmdir "$install_root"
	echo "Removed empty directory: $install_root"
fi

echo
echo "Uninstall complete!"
echo
echo "Note: The following cannot be undone by this script:"
echo "  - SCRIPTORIUM_ROOT environment variable"
echo "  - MANPATH modifications"
echo "  - fpath modifications"
echo "  - Sourced functions from script files"
echo "  - compinit execution"
echo "These will be cleared when you start a new shell session
