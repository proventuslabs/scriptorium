#compdef mkcd

_mkcd() {
    local context state line
    typeset -A opt_args=()

    _arguments -C \
        '(-h --help)'{-h,--help}'[Show help message for mkcd]' \
        '--builtin[Use builtin mkdir and cd commands, bypassing any aliases]' \
        '*:mkdir-args:->mkdir'

    if [[ $state == mkdir ]]; then
        $_comps[mkdir]
    fi
}
