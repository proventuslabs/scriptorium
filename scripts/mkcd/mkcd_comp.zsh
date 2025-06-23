#compdef mkcd

_mkcd() {
	local context state line
	typeset -A opt_args=()

	_arguments -C \
		'(-h --help)'{-h,--help}'[Show help message for mkcd]' \
		'*:mkdir-args:->mkdir'

	if [[ $state == mkdir ]]; then
		$_comps[mkdir]
	fi
}
