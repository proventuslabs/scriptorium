# bash completion for jwt

_jwt() {
	local cur prev
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	local opts="-H --header -P --payload -S --signature -A --all -v --verify -h --help --version"

	# Complete file path after -v/--verify (could be key file)
	if [[ "$prev" == "-v" || "$prev" == "--verify" ]]; then
		mapfile -t COMPREPLY < <(compgen -f -- "$cur")
		return 0
	fi

	# Complete options
	if [[ "$cur" == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
		return 0
	fi

	# Default: complete files (for token files) or nothing
	return 0
}

complete -F _jwt jwt
