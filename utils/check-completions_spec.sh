# shellcheck shell=bash

Describe 'check-completions.sh'
	setup() {
		TEST_DIR=$(mktemp -d)
	}

	cleanup() {
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	create_script() {
		local name="$1"
		mkdir -p "$TEST_DIR/$name/completions"
	}

	create_options() {
		local name="$1"
		local content="$2"
		echo "$content" > "$TEST_DIR/$name/options.sh"
	}

	create_completion() {
		local name="$1"
		local content="$2"
		echo "$content" > "$TEST_DIR/$name/completions/${name}.bash"
	}

	Describe 'when completions are in sync'
		It 'exits 0 with simple flags'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
	param   PARAM   -p --param
	disp    :usage  -h --help
}'
			create_completion "foo" '
opts="-f --flag -p --param -h --help"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should include "All completions in sync!"
		End

		It 'handles --{no-} pattern flags'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    VERBOSE -v --{no-}verbose
}'
			create_completion "foo" '
opts="-v --verbose --no-verbose"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should include "All completions in sync!"
		End

		It 'handles multiple parser definitions'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    GLOBAL  -g --global
	cmd     sub
}

parser_definition_sub() {
	flag    LOCAL   -l --local
}'
			create_completion "foo" '
global_opts="-g --global"
sub_opts="-l --local"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should include "All completions in sync!"
		End
	End

	Describe 'when completions are missing flags'
		It 'exits 1 and reports missing flags'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
	param   PARAM   -p --param
}'
			create_completion "foo" '
opts="-f --flag"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be failure
			The output should include "Missing in completions:"
			The output should include "--param"
			The output should include "-p"
		End
	End

	Describe 'when completions have extra flags'
		It 'exits 1 and reports extra flags'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
}'
			create_completion "foo" '
opts="-f --flag -x --extra"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be failure
			The output should include "Extra in completions"
			The output should include "--extra"
			The output should include "-x"
		End
	End

	Describe 'when completion file is missing'
		It 'reports no completion file found'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
}'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The output should include "No bash completion file found"
		End
	End

	Describe 'when options.sh is missing'
		It 'skips the script directory'
			mkdir -p "$TEST_DIR/scripts/foo/completions"
			echo 'opts="-f --flag"' > "$TEST_DIR/scripts/foo/completions/foo.bash"

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should not include "foo"
		End
	End

	Describe 'flag extraction'
		It 'ignores var: suffixes on params'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	param   FILE    -f --file var:PATH
}'
			create_completion "foo" '
opts="-f --file"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should include "All completions in sync!"
		End

		It 'handles disp with function reference'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	disp    :usage  -h --help
	disp    VERSION -V --version
}'
			create_completion "foo" '
opts="-h --help -V --version"
'

			When run script ./check-completions.sh "$TEST_DIR/foo"
			The status should be success
			The output should include "All completions in sync!"
		End
	End

	Describe 'multiple scripts'
		It 'checks all scripts and reports each'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
}'
			create_completion "foo" '
opts="-f --flag"
'

			create_script "bar"
			create_options "bar" '
parser_definition() {
	flag    FLAG    -b --bar
}'
			create_completion "bar" '
opts="-b --bar"
'

			When run script ./check-completions.sh "$TEST_DIR/foo" "$TEST_DIR/bar"
			The status should be success
			The output should include "Checking foo"
			The output should include "Checking bar"
		End

		It 'fails if any script is out of sync'
			create_script "foo"
			create_options "foo" '
parser_definition() {
	flag    FLAG    -f --flag
}'
			create_completion "foo" '
opts="-f --flag"
'

			create_script "bar"
			create_options "bar" '
parser_definition() {
	flag    FLAG    -b --bar
}'
			create_completion "bar" '
opts="-x --wrong"
'

			When run script ./check-completions.sh "$TEST_DIR/foo" "$TEST_DIR/bar"
			The status should be failure
			The output should include "Completion files are out of sync"
		End
	End

	Describe 'CLI options'
		It 'shows help with -h'
			When run script ./check-completions.sh -h
			The status should be success
			The output should include 'Usage:'
			The output should include 'script_dir'
		End

		It 'shows version with -V'
			When run script ./check-completions.sh -V
			The status should be success
			The output should match pattern '*.*.*'
		End
	End
End
