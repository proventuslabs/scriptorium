# mkcd - Create directory and cd into it

mkcd() {
    # Local variables for parsed arguments
    local -A parsed_args
    local -a positional_args

    # mkcd only cares about its own --builtin option
    # No need to declare mkdir's options - we'll pass them through as-is
    local -A options_with_args=()

    # Parse arguments using the helper
    getargs mkcd parsed_args positional_args 1 options_with_args "$@"
    local parse_result=$?

    # handle parse args failures
    if [[ $parse_result -gt 0 ]]; then
        [[ $parse_result -eq ${GETARGS_ERRORS[HELP_REQUESTED]} ]] && return 0 || return 1
    fi

    local dir_name="$positional_args[-1]"  # Last argument is directory name

    # Build mkdir arguments by reconstructing the original command line,
    # excluding mkcd-specific options and the directory name
    local -a mkdir_args

    # Add back all the original arguments and the last positional arg
    local -a original_args=("$@")

    for ((i=1; i<=${#original_args}; i++)); do
        local arg="${original_args[i]}"

        case "$arg" in
            --help|-h)
                # Skip help (already handled)
                ;;
            *)
                # This is the last argument (directory name), don't add to mkdir_args
                if [[ $i -eq ${#original_args} ]]; then
                    break
                fi
                # Add everything else to mkdir
                mkdir_args+=("$arg")
                ;;
        esac
    done

    mkdir "${mkdir_args[@]}" "$dir_name" && cd "$dir_name"
}
