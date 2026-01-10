# bash completion for theme

_theme() {
	local cur prev
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	local opts="--detect --list -h --help --version"
	local appearances="dark light"

	# Complete options
	if [[ "$cur" == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
		return 0
	fi

	# Complete appearance values
	mapfile -t COMPREPLY < <(compgen -W "$appearances" -- "$cur")
	return 0
}

complete -F _theme theme
