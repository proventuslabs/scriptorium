# shellcheck shell=bash

# BDD tests for dotenv - test all behaviors through CLI invocation
#
# Tests the bundled script as users experience it.
# Run `make build NAME=dotenv` before running tests.

Describe 'dotenv'
	setup() {
		TEST_DIR=$(mktemp -d)
		cd "$TEST_DIR" || return 1
	}

	cleanup() {
		cd /
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	# Path to the built script
	BIN="${SHELLSPEC_PROJECT_ROOT}/dist/dotenv/bin/dotenv"

	#═══════════════════════════════════════════════════════════════
	# HELP AND VERSION
	#═══════════════════════════════════════════════════════════════
	Describe 'help and version'
		It 'shows help with -h'
			When run script "$BIN" -h
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows help with --help'
			When run script "$BIN" --help
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows version with --version'
			When run script "$BIN" --version
			The status should be success
			The output should match pattern '*.*.*'
		End

		It 'shows version with -V'
			When run script "$BIN" -V
			The status should be success
			The output should match pattern '*.*.*'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# BASIC LOADING
	#═══════════════════════════════════════════════════════════════
	Describe 'basic loading'
		It 'loads .env and makes vars available to command'
			echo 'FOO=bar' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'loads specified file with -e'
			echo 'FOO=custom' > custom.env
			When run script "$BIN" -e custom.env printenv FOO
			The status should be success
			The output should equal "custom"
		End

		It 'loads specified file with --env-file'
			echo 'FOO=custom' > custom.env
			When run script "$BIN" --env-file custom.env printenv FOO
			The status should be success
			The output should equal "custom"
		End

		It 'requires a command'
			When run script "$BIN"
			The status should be failure
			The stderr should include "command required"
		End

		It 'passes command exit status'
			echo 'FOO=bar' > .env
			When run script "$BIN" sh -c 'exit 42'
			The status should equal 42
		End

		It 'passes arguments to command'
			echo 'FOO=bar' > .env
			When run script "$BIN" sh -c 'echo "arg: $1"' -- hello
			The status should be success
			The output should equal "arg: hello"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# MULTIPLE FILES
	#═══════════════════════════════════════════════════════════════
	Describe 'multiple files'
		It 'loads multiple files with repeated -e'
			echo 'FOO=first' > a.env
			echo 'BAR=second' > b.env
			When run script "$BIN" -e a.env -e b.env sh -c 'echo "$FOO $BAR"'
			The status should be success
			The output should equal "first second"
		End

		It 'later files override earlier'
			echo 'FOO=first' > a.env
			echo 'FOO=second' > b.env
			When run script "$BIN" -e a.env -e b.env printenv FOO
			The status should be success
			The output should equal "second"
		End

		It 'preserves order of -e flags'
			echo 'FOO=1' > a.env
			echo 'FOO=2' > b.env
			echo 'FOO=3' > c.env
			When run script "$BIN" -e a.env -e b.env -e c.env printenv FOO
			The status should be success
			The output should equal "3"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# ENVIRONMENT PRECEDENCE
	#═══════════════════════════════════════════════════════════════
	Describe 'environment precedence'
		It 'existing env vars take precedence over file'
			echo 'TEST_VAR=from_file' > .env
			export TEST_VAR=from_env
			When run script "$BIN" printenv TEST_VAR
			The status should be success
			The output should equal "from_env"
		End

		It 'file values override env with -o flag'
			echo 'TEST_VAR=from_file' > .env
			export TEST_VAR=from_env
			When run script "$BIN" -o printenv TEST_VAR
			The status should be success
			The output should equal "from_file"
		End

		It 'file values override env with --override flag'
			echo 'TEST_VAR=from_file' > .env
			export TEST_VAR=from_env
			When run script "$BIN" --override printenv TEST_VAR
			The status should be success
			The output should equal "from_file"
		End

		It 'override respects file order (later wins)'
			echo 'TEST_VAR=first' > a.env
			echo 'TEST_VAR=second' > b.env
			export TEST_VAR=from_env
			When run script "$BIN" -o -e a.env -e b.env printenv TEST_VAR
			The status should be success
			The output should equal "second"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# MISSING FILES
	#═══════════════════════════════════════════════════════════════
	Describe 'missing files'
		It 'warns on missing file by default'
			When run script "$BIN" -e missing.env true
			The status should be success
			The stderr should include "not found"
		End

		It 'fails with -s/--strict on missing file'
			When run script "$BIN" -s -e missing.env true
			The status should be failure
			The stderr should include "not found"
		End

		It 'fails with --strict on missing file'
			When run script "$BIN" --strict -e missing.env true
			The status should be failure
			The stderr should include "not found"
		End

		It 'suppresses warnings with -q/--quiet'
			When run script "$BIN" -q -e missing.env true
			The status should be success
			The stderr should equal ""
		End

		It 'suppresses warnings with --quiet'
			When run script "$BIN" --quiet -e missing.env true
			The status should be success
			The stderr should equal ""
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: BASIC
	#═══════════════════════════════════════════════════════════════
	Describe 'parsing basics'
		It 'parses KEY=value'
			echo 'FOO=bar' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'handles empty value'
			echo 'FOO=' > .env
			When run script "$BIN" sh -c 'echo "x${FOO}x"'
			The status should be success
			The output should equal "xx"
		End

		It 'handles underscore in key name'
			echo 'FOO_BAR=value' > .env
			When run script "$BIN" printenv FOO_BAR
			The status should be success
			The output should equal "value"
		End

		It 'handles key starting with underscore'
			echo '_PRIVATE=secret' > .env
			When run script "$BIN" printenv _PRIVATE
			The status should be success
			The output should equal "secret"
		End

		It 'handles digits in key name'
			echo 'API_V2=enabled' > .env
			When run script "$BIN" printenv API_V2
			The status should be success
			The output should equal "enabled"
		End

		It 'ignores comments'
			cat > .env << 'EOF'
# this is a comment
FOO=bar
EOF
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'ignores blank lines'
			cat > .env << 'EOF'
FOO=bar

BAZ=qux
EOF
			When run script "$BIN" sh -c 'echo "$FOO $BAZ"'
			The status should be success
			The output should equal "bar qux"
		End

		It 'handles end-of-line comments'
			echo 'FOO=bar  # comment' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: UNQUOTED VALUES
	#═══════════════════════════════════════════════════════════════
	Describe 'unquoted values'
		It 'trims leading whitespace'
			echo 'FOO=   bar' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'trims trailing whitespace'
			printf 'FOO=bar   \n' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'preserves internal spaces'
			echo 'FOO=hello world' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "hello world"
		End

		It 'treats backslashes literally'
			echo 'WINPATH=C:\Windows\System32' > .env
			When run script "$BIN" printenv WINPATH
			The status should be success
			The output should equal 'C:\Windows\System32'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: SINGLE-QUOTED VALUES
	#═══════════════════════════════════════════════════════════════
	Describe 'single-quoted values'
		It 'preserves literal content'
			echo "FOO='bar baz'" > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar baz"
		End

		It 'preserves leading/trailing whitespace'
			echo "FOO='  spaced  '" > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "  spaced  "
		End

		It 'treats backslashes literally'
			echo "WINPATH='C:\Windows\System32'" > .env
			When run script "$BIN" printenv WINPATH
			The status should be success
			The output should equal 'C:\Windows\System32'
		End

		It 'treats dollar signs literally'
			echo "PRICE='\$100'" > .env
			When run script "$BIN" printenv PRICE
			The status should be success
			The output should equal '$100'
		End

		It 'handles escaped single quote'
			echo "MSG='it'\\''s fine'" > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "it's fine"
		End

		It 'preserves hash character'
			echo "COMMENT='# not a comment'" > .env
			When run script "$BIN" printenv COMMENT
			The status should be success
			The output should equal "# not a comment"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: DOUBLE-QUOTED VALUES
	#═══════════════════════════════════════════════════════════════
	Describe 'double-quoted values'
		It 'preserves content'
			echo 'FOO="bar baz"' > .env
			When run script "$BIN" printenv FOO
			The status should be success
			The output should equal "bar baz"
		End

		It 'processes escaped double quote'
			echo 'MSG="say \"hello\""' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'say "hello"'
		End

		It 'processes escaped backslash'
			printf 'WINPATH="C\\\\Windows"\n' > .env
			When run script "$BIN" printenv WINPATH
			The status should be success
			The output should equal 'C\Windows'
		End

		It 'processes newline escape'
			echo 'MSG="line1\nline2"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "line1
line2"
		End

		It 'processes tab escape'
			echo 'MSG="col1\tcol2"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "col1	col2"
		End

		It 'preserves hash character'
			echo 'COMMENT="# not a comment"' > .env
			When run script "$BIN" printenv COMMENT
			The status should be success
			The output should equal "# not a comment"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: MULTILINE VALUES
	#═══════════════════════════════════════════════════════════════
	Describe 'multiline values'
		It 'handles multiline in single quotes'
			cat > .env << 'EOF'
KEY='line1
line2'
EOF
			When run script "$BIN" printenv KEY
			The status should be success
			The output should equal "line1
line2"
		End

		It 'handles multiline in double quotes'
			cat > .env << 'EOF'
KEY="line1
line2"
EOF
			When run script "$BIN" printenv KEY
			The status should be success
			The output should equal "line1
line2"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: VARIABLE SUBSTITUTION
	#═══════════════════════════════════════════════════════════════
	Describe 'variable substitution'
		It 'substitutes $VAR in double quotes'
			export TEST_VAR=hello
			echo 'MSG="$TEST_VAR world"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "hello world"
		End

		It 'substitutes ${VAR} in double quotes'
			export TEST_VAR=hello
			echo 'MSG="${TEST_VAR}world"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "helloworld"
		End

		It 'handles ${VAR:-default} when unset'
			unset UNSET_VAR
			echo 'MSG="${UNSET_VAR:-fallback}"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "fallback"
		End

		It 'handles ${VAR:-default} when set'
			export SET_VAR=actual
			echo 'MSG="${SET_VAR:-fallback}"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "actual"
		End

		It 'does NOT substitute in single quotes'
			export TEST_VAR=hello
			echo "MSG='\$TEST_VAR world'" > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal '$TEST_VAR world'
		End

		It 'does NOT substitute in unquoted values'
			export TEST_VAR=hello
			echo 'MSG=$TEST_VAR world' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal '$TEST_VAR world'
		End

		It 'handles $ at end of string'
			echo 'MSG="price is $"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'price is $'
		End

		It 'handles ${} malformed syntax (empty braces)'
			echo 'MSG="test ${} value"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'test ${} value'
		End

		It 'handles ${ without closing brace'
			echo 'MSG="test ${ value"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'test ${ value'
		End

		It 'handles $ followed by non-identifier char'
			echo 'MSG="cost: $100"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'cost: $100'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# PARSING: WARNINGS
	#═══════════════════════════════════════════════════════════════
	Describe 'parsing warnings'
		It 'warns on invalid key name starting with digit'
			echo '2FAST=value' > .env
			When run script "$BIN" -s true
			The status should be failure
			The stderr should include "invalid"
		End

		It 'warns on unclosed single quote'
			printf "KEY='unclosed" > .env
			When run script "$BIN" -s true
			The status should be failure
			The stderr should include "unclosed"
		End

		It 'warns on unclosed double quote'
			printf 'KEY="unclosed' > .env
			When run script "$BIN" -s true
			The status should be failure
			The stderr should include "unclosed"
		End

		It 'warns on unrecognized line'
			echo 'this is not valid' > .env
			When run script "$BIN" -s true
			The status should be failure
			The stderr should include "unrecognized"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# ADDITIONAL ESCAPE SEQUENCES
	#═══════════════════════════════════════════════════════════════
	Describe 'additional escape sequences'
		It 'processes carriage return escape'
			echo 'MSG="line1\rline2"' > .env
			# Check that \r is converted to actual carriage return (13 decimal)
			When run script "$BIN" sh -c 'printf "%s" "$MSG" | od -c | head -1'
			The status should be success
			The output should include '\r'
		End

		It 'processes form feed escape'
			echo 'MSG="before\fafter"' > .env
			When run script "$BIN" sh -c 'printf "%s" "$MSG" | od -c | head -1'
			The status should be success
			The output should include '\f'
		End

		It 'processes backspace escape'
			echo 'MSG="back\bspace"' > .env
			When run script "$BIN" sh -c 'printf "%s" "$MSG" | od -c | head -1'
			The status should be success
			The output should include '\b'
		End

		It 'processes vertical tab escape'
			echo 'MSG="vert\vtab"' > .env
			When run script "$BIN" sh -c 'printf "%s" "$MSG" | od -c | head -1'
			The status should be success
			The output should include '\v'
		End

		It 'preserves unknown escapes literally'
			echo 'MSG="foo\xbar"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'foo\xbar'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# VARIABLE SUBSTITUTION EDGE CASES
	#═══════════════════════════════════════════════════════════════
	Describe 'variable substitution edge cases'
		It 'handles ${VAR} without default'
			export TEST_VAR=hello
			echo 'MSG="${TEST_VAR}"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "hello"
		End

		It 'handles ${VAR} unset without default'
			unset UNSET_VAR
			echo 'MSG="${UNSET_VAR}"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal ""
		End

		It 'handles $VAR at end of string'
			export TEST_VAR=world
			echo 'MSG="hello $TEST_VAR"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal "hello world"
		End

		It 'handles $ followed by number'
			echo 'MSG="price is $100"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'price is $100'
		End

		It 'handles $ at end of string'
			echo 'MSG="cost$"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal 'cost$'
		End

		It 'handles ${invalid syntax'
			echo 'MSG="${foo"' > .env
			When run script "$BIN" printenv MSG
			The status should be success
			The output should equal '${foo'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# EXEC MODE
	#═══════════════════════════════════════════════════════════════
	Describe 'exec mode'
		It 'replaces process with -x flag'
			echo 'FOO=bar' > .env
			When run script "$BIN" -x printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'replaces process with --exec flag'
			echo 'FOO=bar' > .env
			When run script "$BIN" --exec printenv FOO
			The status should be success
			The output should equal "bar"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# MULTILINE EDGE CASES
	#═══════════════════════════════════════════════════════════════
	Describe 'multiline edge cases'
		It 'handles multiline with single quote escape continuation'
			cat > .env << 'EOF'
KEY='line1'\''
line2'
EOF
			When run script "$BIN" printenv KEY
			The status should be success
			The output should equal "line1'
line2"
		End

		It 'handles multiple vars with multiline'
			cat > .env << 'EOF'
FIRST='multi
line'
SECOND=normal
EOF
			When run script "$BIN" sh -c 'echo "$SECOND"'
			The status should be success
			The output should equal "normal"
		End
	End
End
