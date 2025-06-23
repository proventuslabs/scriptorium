# ports - Show what's running on which ports

# Exit codes
if [[ -z ${_ST_PORTS_SUCCESS+x} ]]; then
    readonly _ST_PORTS_SUCCESS=0
    readonly _ST_PORTS_ERROR_ARGS=1
    readonly _ST_PORTS_ERROR_NOT_FOUND=2
    readonly _ST_PORTS_ERROR_KILL=3
    readonly _ST_PORTS_ERROR_MISSING_TOOLS=4
fi

# Helper function to check if required tools are available
_ST_PORTS_check_requirements() {
    local missing_tools=()

    if ! command -v lsof >/dev/null 2>&1; then
        missing_tools+=("lsof")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Error: Missing required tools: ${missing_tools[*]}" >&2
        echo "Please install: ${missing_tools[*]}" >&2
        return $_ST_PORTS_ERROR_MISSING_TOOLS
    fi

    return $_ST_PORTS_SUCCESS
}

# Helper function to get port information
_ST_PORTS_get_port_info() {
    local port="$1"
    local protocol="${2:-tcp}"

    # Use lsof to find processes listening on the port
    lsof -i "$protocol:$port" -P -n 2>/dev/null | grep LISTEN
}

# Helper function to get all listening ports
_ST_PORTS_get_all_ports() {
    local protocol="${1:-}"

    if [[ -n "$protocol" ]]; then
        lsof -i "$protocol" -P -n 2>/dev/null | grep LISTEN
    else
        lsof -i -P -n 2>/dev/null | grep LISTEN
    fi
}

# Helper function to format port output
_ST_PORTS_format_output() {
    local verbose="$1"
    local show_headers="$2"

    if [[ "$show_headers" == true ]]; then
        if [[ "$verbose" == true ]]; then
            printf "%-8s %-6s %-20s %-15s %-10s %s\n" "PID" "PROTO" "PROCESS" "ADDRESS" "PORT" "COMMAND"
            printf "%-8s %-6s %-20s %-15s %-10s %s\n" "---" "-----" "-------" "-------" "----" "-------"
        else
            printf "%-6s %-20s %-10s\n" "PID" "PROCESS" "PORT"
            printf "%-6s %-20s %-10s\n" "---" "-------" "----"
        fi
    fi

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local process_name=$(echo "$line" | awk '{print $1}')
            local pid=$(echo "$line" | awk '{print $2}')
            local proto=$(echo "$line" | awk '{print $8}' | cut -d: -f1)
            local address=$(echo "$line" | awk '{print $9}' | cut -d: -f1)
            local port=$(echo "$line" | awk '{print $9}' | cut -d: -f2)
            local command=$(echo "$line" | awk '{for(i=10;i<=NF;i++) printf "%s ", $i}')

            if [[ "$verbose" == true ]]; then
                printf "%-8s %-6s %-20s %-15s %-10s %s\n" "$pid" "$proto" "$process_name" "$address" "$port" "$command"
            else
                printf "%-6s %-20s %-10s\n" "$pid" "$process_name" "$port"
            fi
        fi
    done
}

# Helper function to kill processes on port
_ST_PORTS_kill_port() {
    local port="$1"
    local force="$2"
    local protocol="${3:-tcp}"

    local port_info
    port_info="$(_ST_PORTS_get_port_info "$port" "$protocol")"

    if [[ -z "$port_info" ]]; then
        echo "No process found listening on port $port" >&2
        return $_ST_PORTS_ERROR_NOT_FOUND
    fi

    local pids=($(echo "$port_info" | awk '{print $2}' | sort -u))

    if [[ ${#pids[@]} -eq 0 ]]; then
        echo "No processes found" >&2
        return $_ST_PORTS_ERROR_NOT_FOUND
    fi

    echo "Found ${#pids[@]} process(es) on port $port:" >&2
    echo "$port_info" | _ST_PORTS_format_output false false >&2
    echo >&2

    for pid in "${pids[@]}"; do
        local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")

        if [[ "$force" == true ]]; then
            echo "Force killing PID $pid ($process_name)..." >&2
            if kill -9 "$pid" 2>/dev/null; then
                echo "✓ Killed PID $pid" >&2
            else
                echo "✗ Failed to kill PID $pid" >&2
                return $_ST_PORTS_ERROR_KILL
            fi
        else
            echo "Terminating PID $pid ($process_name)..." >&2
            if kill -TERM "$pid" 2>/dev/null; then
                echo "✓ Terminated PID $pid" >&2
                # Give it a moment to terminate gracefully
                sleep 1
                # Check if it's still running
                if kill -0 "$pid" 2>/dev/null; then
                    echo "Process $pid still running, you may need to use --force" >&2
                fi
            else
                echo "✗ Failed to terminate PID $pid" >&2
                return $_ST_PORTS_ERROR_KILL
            fi
        fi
    done

    return $_ST_PORTS_SUCCESS
}

ports() {
    # Check requirements first
    if ! _ST_PORTS_check_requirements; then
        return $_ST_PORTS_ERROR_MISSING_TOOLS
    fi

    # Local variables for parsed arguments
    local -A parsed_args
    local -a positional_args

    # Define which options take arguments
    local -A options_with_args=(
        [protocol]=1   # --protocol takes protocol argument
        [p]=1          # -p as alias for protocol
    )

    # Parse arguments using the helper
    getargs ports parsed_args positional_args 0 options_with_args "$@"
    local parse_result=$?

    # handle parse args failures
    if [[ $parse_result -gt 0 ]]; then
        [[ $parse_result -eq ${GETARGS_ERRORS[HELP_REQUESTED]} ]] && return 0 || return 1
    fi

    # Extract options
    local verbose=${parsed_args[verbose]:-${parsed_args[v]:-false}}
    local kill_mode=${parsed_args[kill]:-${parsed_args[k]:-false}}
    local force=${parsed_args[force]:-${parsed_args[f]:-false}}
    local protocol=${parsed_args[protocol]:-${parsed_args[p]:-}}
    local all=${parsed_args[all]:-${parsed_args[a]:-false}}
    local pid_only=${parsed_args[pid]:-false}

    # Validate protocol if specified
    if [[ -n "$protocol" && "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        echo "Error: Protocol must be 'tcp' or 'udp'" >&2
        return $_ST_PORTS_ERROR_ARGS
    fi

    # Handle different modes
    if [[ "$all" == true ]]; then
        # Show all listening ports
        local port_info
        port_info="$(_ST_PORTS_get_all_ports "$protocol")"

        if [[ -z "$port_info" ]]; then
            echo "No listening ports found" >&2
            return $_ST_PORTS_ERROR_NOT_FOUND
        fi

        echo "$port_info" | _ST_PORTS_format_output "$verbose" true
        return $_ST_PORTS_SUCCESS

    elif [[ ${#positional_args[@]} -eq 0 ]]; then
        # No port specified and not --all, show usage hint
        echo "Error: Specify a port number or use --all to show all ports" >&2
        echo "Try: ports --help" >&2
        return $_ST_PORTS_ERROR_ARGS
    fi

    # Port-specific operations
    local port="${positional_args[1]}"

    # Validate port number
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        echo "Error: Invalid port number '$port'. Must be 1-65535" >&2
        return $_ST_PORTS_ERROR_ARGS
    fi

    if [[ "$kill_mode" == true ]]; then
        # Kill processes on port
        _ST_PORTS_kill_port "$port" "$force" "${protocol:-tcp}"
        return $?
    else
        # Show information about specific port
        local port_info
        port_info="$(_ST_PORTS_get_port_info "$port" "${protocol:-tcp}")"

        if [[ -z "$port_info" ]]; then
            echo "No process found listening on port $port" >&2
            return $_ST_PORTS_ERROR_NOT_FOUND
        fi

        if [[ "$pid_only" == true ]]; then
            # Output only PIDs (for piping/scripting)
            echo "$port_info" | awk '{print $2}' | sort -u
        else
            # Show process information
            local process_names=($(echo "$port_info" | awk '{print $1}' | sort -u))

            # Output process names to stderr (like original script)
            echo "${process_names[*]}" >&2

            # Output formatted information or just PIDs
            echo "$port_info" | _ST_PORTS_format_output "$verbose" true
        fi

        return $_ST_PORTS_SUCCESS
    fi
}
