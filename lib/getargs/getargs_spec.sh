Describe 'getargs'
	Include ./getargs.zsh

	# Mock function for testing basic flag parsing
	mock_func() {
		typeset -gA parsed_args=()
		typeset -ga positional_args=()
		typeset -gA options_with_args=()
		getargs mock_func parsed_args positional_args 0 options_with_args "$@"
		return $?
	}

	# Mock function with options that take arguments
	mock_func_with_opts() {
		typeset -gA parsed_args=()
		typeset -ga positional_args=()
		typeset -gA options_with_args=(
			[file]=1
			[e]=1
			[output]=1
			[o]=1
		)
		getargs mock_func_with_opts parsed_args positional_args 0 options_with_args "$@"
		return $?
	}

	# Mock function for minimum arguments testing
	mock_func_min_args() {
		typeset -gA parsed_args=()
		typeset -ga positional_args=()
		typeset -gA options_with_args=()
		getargs mock_func_min_args parsed_args positional_args 2 options_with_args "$@"
		return $?
	}

	# Mock function for no specification testing
	no_spec_func() {
		typeset -gA parsed_args=()
		typeset -ga positional_args=()
		getargs no_spec_func parsed_args positional_args 0 "" "$@"
		return $?
	}

	Context 'Help system'
		man() {
			echo "man called"
		}

		It 'returns help requested error code for -h'
			When call mock_func -h
			The status should equal ${GETARGS_ERRORS[HELP_REQUESTED]}
			The output should include "man called"
		End

		It 'returns help requested error code for --help'
			When call mock_func --help
			The status should equal ${GETARGS_ERRORS[HELP_REQUESTED]}
			The output should include "man called"
		End

		It 'prioritizes help over other options'
			When call mock_func --verbose -h --debug
			The status should equal ${GETARGS_ERRORS[HELP_REQUESTED]}
			The output should include "man called"
		End
	End

	Context 'Basic flag parsing'
		It 'parses short flags'
			When call mock_func -v -d
			The status should be success
			The variable "parsed_args[v]" should equal "true"
			The variable "parsed_args[d]" should equal "true"
		End

		It 'parses long flags'
			When call mock_func --verbose --debug
			The status should be success
			The variable "parsed_args[verbose]" should equal "true"
			The variable "parsed_args[debug]" should equal "true"
		End

		It 'parses combined short flags'
			When call mock_func -vd
			The status should be success
			The variable "parsed_args[v]" should equal "true"
			The variable "parsed_args[d]" should equal "true"
		End

		It 'handles options with hyphens in names'
			When call mock_func --dry-run --output-file=test.txt
			The status should be success
			The variable "parsed_args[dry-run]" should equal "true"
			The variable "parsed_args[output-file]" should equal "test.txt"
		End

		It 'handles options that are not in the spec as flags'
			When call mock_func_with_opts --unknown-option
			The status should be success
			The variable "parsed_args[unknown-option]" should equal "true"
		End
	End

	Context 'Options with arguments - equals syntax'
		It 'parses long option with equals syntax'
			When call mock_func_with_opts --file=test.txt
			The status should be success
			The variable "parsed_args[file]" should equal "test.txt"
		End

		It 'parses short option with equals syntax'
			When call mock_func_with_opts -e=test.env
			The status should be success
			The variable "parsed_args[e]" should equal "test.env"
		End

		It 'handles empty string values'
			When call mock_func_with_opts --file=""
			The status should be success
			The variable "parsed_args[file]" should equal ""
		End

		It 'handles options with special characters in values'
			When call mock_func_with_opts --file="path with spaces.txt" -e='env=production'
			The status should be success
			The variable "parsed_args[file]" should equal "path with spaces.txt"
			The variable "parsed_args[e]" should equal "env=production"
		End

		It 'handles numeric arguments'
			When call mock_func_with_opts --file=123 456
			The status should be success
			The variable "parsed_args[file]" should equal "123"
			The variable "positional_args[1]" should equal "456"
		End
	End

	Context 'Options with arguments - space syntax'
		It 'parses long option with space syntax'
			When call mock_func_with_opts --file test.txt
			The status should be success
			The variable "parsed_args[file]" should equal "test.txt"
		End

		It 'parses short option with space syntax'
			When call mock_func_with_opts -e test.env
			The status should be success
			The variable "parsed_args[e]" should equal "test.env"
		End

		It 'handles multiple values for same option'
			When call mock_func_with_opts -e first.env -e second.env
			The status should be success
			The variable "parsed_args[e]" should equal "first.env second.env"
		End

		It 'handles multiple values with different syntaxes'
			When call mock_func_with_opts -e=first.env --file second.txt -o=output.log
			The status should be success
			The variable "parsed_args[e]" should equal "first.env"
			The variable "parsed_args[file]" should equal "second.txt"
			The variable "parsed_args[o]" should equal "output.log"
		End
	End

	Context 'Error handling - missing option values'
		It 'fails when option expecting argument has none (space syntax)'
			When call mock_func_with_opts --file
			The status should equal ${GETARGS_ERRORS[MISSING_VALUE]}
			The error should include "Option --file requires an argument"
		End

		It 'fails when option expecting argument is followed by another option'
			When call mock_func_with_opts --file --verbose
			The status should equal ${GETARGS_ERRORS[MISSING_VALUE]}
			The error should include "Option --file requires an argument"
		End

		It 'fails when short option expecting argument has none'
			When call mock_func_with_opts -e
			The status should equal ${GETARGS_ERRORS[MISSING_VALUE]}
			The error should include "Option --e requires an argument"
		End

		It 'fails when short option in group expects argument but has none'
			When call mock_func_with_opts -ve
			The status should equal ${GETARGS_ERRORS[MISSING_VALUE]}
			The error should include "Option --e requires an argument"
		End
	End

	Context 'Positional arguments handling'
		It 'captures positional arguments'
			When call mock_func arg1 arg2 arg3
			The status should be success
			The variable "positional_args[1]" should equal "arg1"
			The variable "positional_args[2]" should equal "arg2"
			The variable "positional_args[3]" should equal "arg3"
		End

		It 'preserves argument order for positional args'
			When call mock_func first second third
			The status should be success
			The variable "positional_args[1]" should equal "first"
			The variable "positional_args[2]" should equal "second"
			The variable "positional_args[3]" should equal "third"
		End

		It 'captures positional arguments mixed with options'
			When call mock_func_with_opts -v --file=test.txt arg1 arg2
			The status should be success
			The variable "parsed_args[v]" should equal "true"
			The variable "parsed_args[file]" should equal "test.txt"
			The variable "positional_args[1]" should equal "arg1"
			The variable "positional_args[2]" should equal "arg2"
		End

		It 'treats single dash as positional argument'
			When call mock_func -v - arg2
			The status should be success
			The variable "parsed_args[v]" should equal "true"
			The variable "positional_args[1]" should equal "-"
			The variable "positional_args[2]" should equal "arg2"
		End

		It 'handles arguments that look like options after --'
			When call mock_func -- --not-an-option -also-not
			The status should be success
			The variable "positional_args[1]" should equal "--not-an-option"
			The variable "positional_args[2]" should equal "-also-not"
		End
	End

	Context 'Minimum arguments validation'
		It 'succeeds when minimum arguments are provided'
			When call mock_func_min_args arg1 arg2
			The status should be success
			The variable "positional_args[1]" should equal "arg1"
			The variable "positional_args[2]" should equal "arg2"
		End

		It 'fails when insufficient arguments are provided'
			When call mock_func_min_args arg1
			The status should equal ${GETARGS_ERRORS[MISSING_ARGUMENTS]}
			The error should include "requires at least 2 argument(s)"
		End

		It 'succeeds with extra arguments beyond minimum'
			When call mock_func_min_args arg1 arg2 arg3 arg4
			The status should be success
			The variable "positional_args[1]" should equal "arg1"
			The variable "positional_args[2]" should equal "arg2"
			The variable "positional_args[3]" should equal "arg3"
			The variable "positional_args[4]" should equal "arg4"
		End
	End

	Context 'No options specification fallback'
		It 'works without options specification'
			When call no_spec_func --verbose -d arg1
			The status should be success
			The variable "parsed_args[verbose]" should equal "true"
			The variable "parsed_args[d]" should equal "true"
			The variable "positional_args[1]" should equal "arg1"
		End

		It 'treats all options as flags when no spec provided'
			When call no_spec_func --file value
			The status should be success
			The variable "parsed_args[file]" should equal "true"
			The variable "positional_args[1]" should equal "value"
		End
	End

	Context 'Edge cases and integration'
		It 'handles empty arguments list'
			When call mock_func
			The status should be success
			The value "${#parsed_args[@]}" should equal 0
			The value "${#positional_args[@]}" should equal 0
		End

		It 'handles mixed short and long options'
			When call mock_func_with_opts -v --debug -e=test.env --output result.txt arg1
			The status should be success
			The variable "parsed_args[v]" should equal "true"
			The variable "parsed_args[debug]" should equal "true"
			The variable "parsed_args[e]" should equal "test.env"
			The variable "parsed_args[output]" should equal "result.txt"
			The variable "positional_args[1]" should equal "arg1"
		End
	End
End
