# bash completion for theme

_theme() {
	local cur prev
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	local opts="-d --detect -l --list -q --quiet -h --help -V --version"
	local appearances="dark light auto"

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
