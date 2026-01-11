# shellcheck shell=bash

# cz hook - manage the commit-msg git hook

cmd_hook() {
	local action="${1:-status}"

	# Find git directory
	local git_dir
	git_dir="$(git rev-parse --git-dir 2>/dev/null)" || {
		echo "cz: error: not a git repository" >&2
		return 1
	}

	local hook_path="$git_dir/hooks/commit-msg"
	local hook_marker="# cz-hook"

	case "$action" in
		install)
			hook_install "$hook_path" "$hook_marker"
			;;
		uninstall)
			hook_uninstall "$hook_path" "$hook_marker"
			;;
		status)
			hook_status "$hook_path" "$hook_marker"
			;;
		*)
			echo "cz: error: unknown hook action '$action'" >&2
			echo "Usage: cz hook [install|uninstall|status]" >&2
			return 2
			;;
	esac
}

hook_install() {
	local hook_path="$1"
	local hook_marker="$2"

	if [[ -f "$hook_path" ]]; then
		if grep -q "$hook_marker" "$hook_path" 2>/dev/null; then
			echo "cz: hook already installed"
			return 0
		else
			echo "cz: error: existing commit-msg hook found" >&2
			echo "Remove it manually or add 'cz lint < \"\$1\"' to it" >&2
			return 1
		fi
	fi

	mkdir -p "$(dirname "$hook_path")"
	cat >"$hook_path" <<EOF
#!/bin/sh
$hook_marker
# Validate commit message with cz lint
cz lint <"\$1" || exit 1
EOF
	chmod +x "$hook_path"
	echo "Installed commit-msg hook"
}

hook_uninstall() {
	local hook_path="$1"
	local hook_marker="$2"

	if [[ ! -f "$hook_path" ]]; then
		echo "cz: no commit-msg hook installed"
		return 0
	fi

	if ! grep -q "$hook_marker" "$hook_path" 2>/dev/null; then
		echo "cz: error: commit-msg hook was not installed by cz" >&2
		return 1
	fi

	rm "$hook_path"
	echo "Uninstalled commit-msg hook"
}

hook_status() {
	local hook_path="$1"
	local hook_marker="$2"

	if [[ ! -f "$hook_path" ]]; then
		echo "Not installed"
		return 1
	fi

	if grep -q "$hook_marker" "$hook_path" 2>/dev/null; then
		echo "Installed: $hook_path"
		return 0
	else
		echo "Other hook present: $hook_path"
		return 1
	fi
}
