# bash completion for cz

_cz() {
	local cur prev words cword
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	local commands="create lint parse init hook"
	local global_opts="-c --config-file -r --require-scope --no-require-scope -d --defined-scope --no-defined-scope -e --enforce-patterns --no-enforce-patterns -m --multi-scope --no-multi-scope -b --breaking-footer --no-breaking-footer -q --quiet -h --help -V --version"

	# Complete config file path after -c/--config-file
	if [[ "$prev" == "-c" || "$prev" == "--config-file" ]]; then
		mapfile -t COMPREPLY < <(compgen -f -- "$cur")
		return 0
	fi

	# Find the subcommand
	local cmd=""
	for ((i=1; i < COMP_CWORD; i++)); do
		case "${COMP_WORDS[i]}" in
			create|lint|parse|init|hook)
				cmd="${COMP_WORDS[i]}"
				break
				;;
		esac
	done

	# Complete based on context
	if [[ -z "$cmd" ]]; then
		if [[ "$cur" == -* ]]; then
			mapfile -t COMPREPLY < <(compgen -W "$global_opts" -- "$cur")
		else
			mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
		fi
	else
		case "$cmd" in
			create)
				mapfile -t COMPREPLY < <(compgen -W "-h --help" -- "$cur")
				;;
			lint)
				mapfile -t COMPREPLY < <(compgen -W "-p --paths -h --help" -- "$cur")
				;;
			init)
				mapfile -t COMPREPLY < <(compgen -W "-o --output -f --force -h --help" -- "$cur")
				;;
			hook)
				mapfile -t COMPREPLY < <(compgen -W "install uninstall status -h --help" -- "$cur")
				;;
			parse)
				mapfile -t COMPREPLY < <(compgen -W "-h --help" -- "$cur")
				;;
		esac
	fi

	return 0
}

complete -F _cz cz
