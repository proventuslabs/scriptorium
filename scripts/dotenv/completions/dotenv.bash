# bash completion for dotenv

_dotenv() {
	local cur prev opts
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	opts="-e --env-file -x --exec -s --strict -q --quiet -h --help -V --version"

	# Complete .env files after -e/--env-file
	if [[ "$prev" == "-e" || "$prev" == "--env-file" ]]; then
		mapfile -t COMPREPLY < <(compgen -f -- "$cur")
		return 0
	fi

	# If current word starts with -, complete options
	if [[ "$cur" == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
		return 0
	fi

	# Otherwise complete commands
	mapfile -t COMPREPLY < <(compgen -c -- "$cur")
	return 0
}

complete -F _dotenv dotenv
