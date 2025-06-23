#compdef ports

_ports() {
    local context state line
    typeset -A opt_args

    _arguments -C \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '(-v --verbose)'{-v,--verbose}'[Show verbose output with additional details]' \
        '(-a --all)'{-a,--all}'[Show all listening ports]' \
        '(-k --kill)'{-k,--kill}'[Kill process(es) listening on specified port]' \
        '(-f --force)'{-f,--force}'[Use SIGKILL instead of SIGTERM when killing]' \
        '--pid[Output only process IDs]' \
        '(-p --protocol)'{-p,--protocol}'[Specify protocol]:protocol:(tcp udp)' \
        '*::port number:->port'

    case $state in
        port)
            if [[ $CURRENT -eq 1 ]]; then
                # Complete with common port numbers and currently listening ports
                local listening_ports
                if command -v lsof >/dev/null 2>&1; then
                    listening_ports=($(lsof -i -P -n 2>/dev/null | grep LISTEN | awk -F: '{print $NF}' | awk '{print $1}' | sort -n | uniq))
                fi

                local common_ports=(
                    "21:FTP"
                    "22:SSH"
                    "23:Telnet"
                    "25:SMTP"
                    "53:DNS"
                    "80:HTTP"
                    "110:POP3"
                    "143:IMAP"
                    "443:HTTPS"
                    "993:IMAPS"
                    "995:POP3S"
                    "1433:SQL Server"
                    "3000:Dev server"
                    "3306:MySQL"
                    "5432:PostgreSQL"
                    "5672:RabbitMQ"
                    "6379:Redis"
                    "8000:HTTP alt"
                    "8080:HTTP alt"
                    "8443:HTTPS alt"
                    "9000:HTTP alt"
                )

                _describe -t ports 'listening ports' listening_ports
                _describe -t common-ports 'common ports' common_ports
            fi
            ;;
    esac
}
