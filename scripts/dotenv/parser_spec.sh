# shellcheck shell=bash
# shellcheck disable=SC2016  # $VAR in test names is intentional

Describe 'parse_env'
	Include ./parser.sh

	# Helper to collect parsed key=value pairs
	setup() {
		PARSED_VARS=()
	}
	BeforeEach 'setup'

	collector() {
		PARSED_VARS+=("$1=$2")
	}

	Describe 'basic parsing'
		It 'parses simple KEY=value'
			Data
				#|FOO=bar
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'parses multiple variables'
			Data
				#|FOO=bar
				#|BAZ=qux
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
			The variable PARSED_VARS[1] should equal "BAZ=qux"
		End

		It 'handles empty value'
			Data
				#|FOO=
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO="
		End

		It 'handles underscore in key name'
			Data
				#|FOO_BAR=value
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO_BAR=value"
		End

		It 'handles key starting with underscore'
			Data
				#|_PRIVATE=secret
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "_PRIVATE=secret"
		End

		It 'handles digits in key name'
			Data
				#|API_V2=enabled
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "API_V2=enabled"
		End

		It 'handles empty input'
			Data
				#|
			End
			When call parse_env collector
			The status should be success
			The value "${#PARSED_VARS[@]}" should equal 0
		End

		It 'handles file with only comments'
			Data
				#|# This is a comment
				#|# Another comment
				#|   # Indented comment
			End
			When call parse_env collector
			The status should be success
			The value "${#PARSED_VARS[@]}" should equal 0
		End
	End

	Describe 'comments'
		It 'ignores full-line comments'
			Data
				#|# this is a comment
				#|FOO=bar
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'ignores indented comments'
			Data
				#|   # indented comment
				#|FOO=bar
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'handles end-of-line comments'
			Data
				#|FOO=bar  # this is a comment
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'ignores blank lines'
			Data
				#|FOO=bar
				#|
				#|BAZ=qux
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
			The variable PARSED_VARS[1] should equal "BAZ=qux"
		End
	End

	Describe 'unquoted values'
		It 'trims leading whitespace'
			Data
				#|FOO=   bar
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'trims trailing whitespace'
			Data
				#|FOO=bar
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar"
		End

		It 'preserves internal spaces'
			Data
				#|FOO=hello world
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=hello world"
		End

		It 'treats backslashes literally'
			Data
				#|PATH=C:\Windows\System32
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "PATH=C:\Windows\System32"
		End
	End

	Describe 'single-quoted values'
		It 'preserves literal content'
			Data
				#|FOO='bar baz'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar baz"
		End

		It 'preserves leading/trailing whitespace'
			Data
				#|FOO='  spaced  '
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=  spaced  "
		End

		It 'treats backslashes literally'
			Data
				#|PATH='C:\Windows\System32'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "PATH=C:\Windows\System32"
		End

		It 'treats dollar signs literally'
			Data
				#|PRICE='$100'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "PRICE=\$100"
		End

		It 'handles escaped single quote'
			Data
				#|MSG='it'\''s fine'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=it's fine"
		End

		It 'preserves hash character'
			Data
				#|COMMENT='# not a comment'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "COMMENT=# not a comment"
		End
	End

	Describe 'double-quoted values'
		It 'preserves content'
			Data
				#|FOO="bar baz"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "FOO=bar baz"
		End

		It 'processes escaped double quote'
			Data
				#|MSG="say \"hello\""
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal 'MSG=say "hello"'
		End

		It 'processes escaped backslash'
			create_backslash_data() { printf 'PATH="C\\\\Windows"\n'; }
			Data create_backslash_data
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal 'PATH=C\Windows'
		End

		It 'processes newline escape'
			Data
				#|MSG="line1\nline2"
			End
			When call parse_env collector
			The status should be success
			The variable "PARSED_VARS[0]" should equal "MSG=line1
line2"
		End

		It 'processes tab escape'
			Data
				#|MSG="col1\tcol2"
			End
			When call parse_env collector
			The status should be success
			The variable "PARSED_VARS[0]" should equal "MSG=col1	col2"
		End

		It 'preserves hash character'
			Data
				#|COMMENT="# not a comment"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "COMMENT=# not a comment"
		End
	End

	Describe 'multiline values'
		It 'handles multiline in single quotes'
			Data
				#|KEY='line1
				#|line2'
			End
			When call parse_env collector
			The status should be success
			The variable "PARSED_VARS[0]" should equal "KEY=line1
line2"
		End

		It 'handles multiline in double quotes'
			Data
				#|KEY="line1
				#|line2"
			End
			When call parse_env collector
			The status should be success
			The variable "PARSED_VARS[0]" should equal "KEY=line1
line2"
		End

		It "handles '\\'' escape spanning lines"
			Data
				#|KEY='line1'\''
				#|line2'
			End
			When call parse_env collector
			The status should be success
			The variable "PARSED_VARS[0]" should equal "KEY=line1'
line2"
		End
	End

	Describe 'variable substitution'
		It 'substitutes $VAR in double quotes'
			export TEST_VAR=hello
			Data
				#|MSG="$TEST_VAR world"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=hello world"
		End

		It 'substitutes ${VAR} in double quotes'
			export TEST_VAR=hello
			Data
				#|MSG="${TEST_VAR}world"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=helloworld"
		End

		It 'handles ${VAR:-default} when unset'
			unset UNSET_VAR
			Data
				#|MSG="${UNSET_VAR:-fallback}"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=fallback"
		End

		It 'handles ${VAR:-default} when set'
			export SET_VAR=actual
			Data
				#|MSG="${SET_VAR:-fallback}"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=actual"
		End

		It 'handles ${VAR:-default} when empty'
			export EMPTY_VAR=
			Data
				#|MSG="${EMPTY_VAR:-fallback}"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=fallback"
		End

		It 'expands empty for undefined $VAR'
			unset UNDEFINED_VAR
			Data
				#|MSG="prefix${UNDEFINED_VAR}suffix"
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=prefixsuffix"
		End

		It 'does NOT substitute in single quotes'
			export TEST_VAR=hello
			Data
				#|MSG='$TEST_VAR world'
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=\$TEST_VAR world"
		End

		It 'does NOT substitute in unquoted values'
			export TEST_VAR=hello
			Data
				#|MSG=$TEST_VAR world
			End
			When call parse_env collector
			The status should be success
			The variable PARSED_VARS[0] should equal "MSG=\$TEST_VAR world"
		End
	End

	Describe 'warnings'
		It 'warns on invalid key name starting with digit'
			Data
				#|2FAST=value
			End
			When call parse_env collector
			The status should equal 1
			The error should include "invalid"
		End

		It 'warns on unclosed single quote'
			Data
				#|KEY='unclosed
			End
			When call parse_env collector
			The status should equal 1
			The error should include "unclosed"
		End

		It 'warns on unclosed double quote'
			Data
				#|KEY="unclosed
			End
			When call parse_env collector
			The status should equal 1
			The error should include "unclosed"
		End

		It 'warns on unrecognized line'
			Data
				#|this is not valid
			End
			When call parse_env collector
			The status should equal 1
			The error should include "unrecognized"
		End
	End
End
