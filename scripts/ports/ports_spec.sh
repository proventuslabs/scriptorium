Describe 'ports'
    Include ./ports.zsh

    BeforeEach 'setup'
    AfterEach 'cleanup'

    setup() {
        # Mock lsof for testing
        lsof() {
            case "$*" in
                *"tcp:3000"*)
                    echo "node      12345 user   10u  IPv4 0x123456      0t0  TCP *:3000 (LISTEN)"
                    ;;
                *"tcp:8080"*)
                    echo "java      54321 user   15u  IPv4 0x789012      0t0  TCP localhost:8080 (LISTEN)"
                    echo "nginx     11111 root   20u  IPv4 0x345678      0t0  TCP *:8080 (LISTEN)"
                    ;;
                *"udp:53"*)
                    echo "dnsmasq   9999  root    5u  IPv4 0x111111      0t0  UDP *:53"
                    ;;
                *"tcp:9999"*)
                    # No output - port not in use
                    ;;
                *"-i tcp"*|*"-i -P"*)
                    # All ports
                    echo "node      12345 user   10u  IPv4 0x123456      0t0  TCP *:3000 (LISTEN)"
                    echo "java      54321 user   15u  IPv4 0x789012      0t0  TCP localhost:8080 (LISTEN)"
                    echo "nginx     11111 root   20u  IPv4 0x345678      0t0  TCP *:8080 (LISTEN)"
                    echo "sshd      22222 root    3u  IPv4 0x999999      0t0  TCP *:22 (LISTEN)"
                    ;;
                *"-i udp"*)
                    echo "dnsmasq   9999  root    5u  IPv4 0x111111      0t0  UDP *:53"
                    ;;
                *)
                    # Default - return some common ports
                    echo "node      12345 user   10u  IPv4 0x123456      0t0  TCP *:3000 (LISTEN)"
                    echo "sshd      22222 root    3u  IPv4 0x999999      0t0  TCP *:22 (LISTEN)"
                    ;;
            esac
        }

        # Mock ps for process info
        ps() {
            case "$*" in
                *12345*)
                    echo "node"
                    ;;
                *54321*)
                    echo "java"
                    ;;
                *11111*)
                    echo "nginx"
                    ;;
                *9999*)
                    echo "dnsmasq"
                    ;;
                *22222*)
                    echo "sshd"
                    ;;
            esac
        }

        # Mock kill for testing
        kill() {
            local signal=""
            local pid=""

            # Parse arguments
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -9|-KILL)
                        signal="KILL"
                        shift
                        ;;
                    -TERM|-15)
                        signal="TERM"
                        shift
                        ;;
                    -0)
                        signal="CHECK"
                        shift
                        ;;
                    *)
                        pid="$1"
                        shift
                        ;;
                esac
            done

            # Simulate kill behavior
            case "$signal" in
                "KILL")
                    echo "Sent SIGKILL to $pid" >&2
                    return 0
                    ;;
                "TERM"|"")
                    echo "Sent SIGTERM to $pid" >&2
                    return 0
                    ;;
                "CHECK")
                    # For testing - simulate process is gone after kill
                    return 1
                    ;;
            esac
        }

        # Mock man for help
        man() {
            echo "man called with: $*"
        }
    }

    cleanup() {
        unset -f lsof ps kill man
    }

    It 'returns help requested error code for -h'
        man() {
            echo 'man called'
        }
        When call ports -h
        The status should be success
        The output should include "man called"
    End

    Context 'Basic port checking'
        It 'shows process on specific port'
            When call ports 3000
            The status should be success
            The output should include "12345"
            The output should include "node"
            The output should include "3000"
            The error should include "node"
        End

        It 'handles port with multiple processes'
            When call ports 8080
            The status should be success
            The output should include "54321"
            The output should include "11111"
            The error should include "java"
            The error should include "nginx"
        End

        It 'reports when no process found on port'
            When call ports 9999
            The status should equal 2
            The error should include "No process found listening on port 9999"
        End

        It 'validates port number range'
            When call ports 99999
            The status should equal 1
            The error should include "Invalid port number"
        End

        It 'validates port number format'
            When call ports abc
            The status should equal 1
            The error should include "Invalid port number"
        End
    End

    Context 'Protocol specification'
        It 'handles TCP protocol specification'
            When call ports --protocol tcp 3000
            The status should be success
            The error should include "node"
        End

        It 'handles UDP protocol specification'
            When call ports -p udp 53
            The status should be success
            The output should include "dnsmasq"
        End

        It 'validates protocol values'
            When call ports --protocol invalid 3000
            The status should equal 1
            The error should include "Protocol must be 'tcp' or 'udp'"
        End
    End

    Context 'Show all ports'
        It 'shows all listening ports with --all'
            When call ports --all
            The status should be success
            The output should include "node"
            The output should include "sshd"
            The output should include "3000"
            The output should include "22"
        End

        It 'shows all TCP ports with protocol filter'
            When call ports --all --protocol tcp
            The status should be success
            The output should include "node"
            The output should include "sshd"
        End

        It 'shows all UDP ports with protocol filter'
            When call ports --all -p udp
            The status should be success
            The output should include "dnsmasq"
        End

        It 'requires either port number or --all'
            When call ports
            The status should equal 1
            The error should include "Specify a port number or use --all"
        End
    End

    Context 'Verbose output'
        It 'shows verbose information for specific port'
            When call ports --verbose 3000
            The status should be success
            The output should include "PID"
            The output should include "PROTO"
            The output should include "PROCESS"
            The output should include "ADDRESS"
            The output should include "COMMAND"
        End

        It 'shows verbose information for all ports'
            When call ports -v --all
            The status should be success
            The output should include "PID"
            The output should include "PROTO"
        End
    End

    Context 'PID-only output'
        It 'outputs only PIDs with --pid option'
            When call ports --pid 3000
            The status should be success
            The output should equal "12345"
            # Should not include headers or process names in stdout
            The output should not include "PID"
            The output should not include "node"
        End

        It 'outputs multiple PIDs for port with multiple processes'
            When call ports --pid 8080
            The status should be success
            The output should include "11111"
            The output should include "54321"
        End
    End

    Context 'Process killing'
        It 'kills process on port with --kill'
            When call ports --kill 3000
            The status should be success
            The error should include "Found 1 process(es) on port 3000"
            The error should include "Terminating PID 12345"
            The error should include "✓ Terminated PID 12345"
        End

        It 'force kills process with --kill --force'
            When call ports -k -f 3000
            The status should be success
            The error should include "Force killing PID 12345"
            The error should include "✓ Killed PID 12345"
        End

        It 'kills multiple processes on same port'
            When call ports --kill 8080
            The status should be success
            The error should include "Found 2 process(es) on port 8080"
            The error should include "Terminating PID 54321"
            The error should include "Terminating PID 11111"
        End

        It 'reports error when no process to kill'
            When call ports --kill 9999
            The status should equal 2
            The error should include "No process found listening on port 9999"
        End
    End

    Context 'Mixed options and combinations'
        It 'combines verbose and kill options'
            When call ports -v --kill 3000
            The status should be success
            The error should include "Found 1 process(es)"
            The error should include "Terminating PID 12345"
        End

        It 'handles protocol specification with kill'
            When call ports --kill --protocol tcp 3000
            The status should be success
            The error should include "Terminating PID 12345"
        End

        It 'processes combined short flags'
            When call ports -vk 3000
            The status should be success
            The error should include "Terminating PID 12345"
        End
    End

    Context 'Error conditions'
        It 'handles missing lsof command'
            # Override lsof to simulate missing command
            command() {
                if [[ "$1" == "-v" && "$2" == "lsof" ]]; then
                    return 1
                fi
            }

            When call ports 3000
            The status should equal 4
            The error should include "Missing required tools: lsof"
        End
    End

    Context 'Output formatting'
        It 'formats basic output with headers'
            When call ports 3000
            The status should be success
            The output should include "PID"
            The output should include "PROCESS"
            The output should include "PORT"
            The output should include "---"
        End

        It 'formats verbose output with additional headers'
            When call ports --verbose 3000
            The status should be success
            The output should include "PROTO"
            The output should include "ADDRESS"
            The output should include "COMMAND"
        End
    End
End
