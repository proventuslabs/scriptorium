# bash completion for <name>

_<name>() {
	local cur prev opts
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	opts="-h --help --version"

	# If current word starts with -, complete options
	if [[ "$cur" == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
		return 0
	fi

	# TODO: Add argument completions
	return 0
}

complete -F _<name> <name>
