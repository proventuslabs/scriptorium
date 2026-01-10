# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016  # Variables used indirectly, $VAR in strings intentional

Describe 'dotenv'
	Include ./dotenv.sh

	setup() {
		TEST_DIR=$(mktemp -d)
		# Clear any test vars
		unset DOTENV_STRICT DOTENV_SILENT DOTENV_EXEC
		unset FOO BAR DOTENV_TEST_VAR
	}
	cleanup() {
		rm -rf "$TEST_DIR"
		unset DOTENV_STRICT DOTENV_SILENT DOTENV_EXEC
		unset FOO BAR DOTENV_TEST_VAR
	}
	BeforeEach 'setup'
	AfterEach 'cleanup'

	Describe 'dotenv_exec'
		It 'loads .env file and runs command'
			echo 'FOO=bar' > "$TEST_DIR/.env"
			When call dotenv_exec 1 "$TEST_DIR/.env" printenv FOO
			The status should be success
			The output should equal "bar"
		End

		It 'loads multiple files'
			echo 'FOO=first' > "$TEST_DIR/a.env"
			echo 'BAR=second' > "$TEST_DIR/b.env"
			When call dotenv_exec 2 "$TEST_DIR/a.env" "$TEST_DIR/b.env" sh -c 'echo $FOO $BAR'
			The status should be success
			The output should equal "first second"
		End

		It 'later files override earlier'
			echo 'FOO=first' > "$TEST_DIR/a.env"
			echo 'FOO=second' > "$TEST_DIR/b.env"
			When call dotenv_exec 2 "$TEST_DIR/a.env" "$TEST_DIR/b.env" printenv FOO
			The status should be success
			The output should equal "second"
		End

		It 'environment variables take precedence'
			echo 'DOTENV_TEST_VAR=from_file' > "$TEST_DIR/.env"
			export DOTENV_TEST_VAR=from_env
			When call dotenv_exec 1 "$TEST_DIR/.env" printenv DOTENV_TEST_VAR
			The status should be success
			The output should equal "from_env"
		End

		It 'passes command exit status'
			echo 'FOO=bar' > "$TEST_DIR/.env"
			When call dotenv_exec 1 "$TEST_DIR/.env" sh -c 'exit 42'
			The status should equal 42
		End

		Describe 'missing files'
			It 'warns on missing file by default'
				When call dotenv_exec 1 "$TEST_DIR/missing.env" true
				The status should be success
				The error should include "not found"
			End

			It 'fails with DOTENV_STRICT on missing file'
				DOTENV_STRICT=1
				When call dotenv_exec 1 "$TEST_DIR/missing.env" true
				The status should be failure
				The error should include "not found"
			End

			It 'suppresses warnings with DOTENV_SILENT'
				DOTENV_SILENT=1
				When call dotenv_exec 1 "$TEST_DIR/missing.env" true
				The status should be success
				The error should equal ""
			End
		End
	End

	Describe '-e flag accumulation'
		Include ./options.sh

		setup_parser() {
			eval "$(getoptions parser_definition parse)"
		}
		BeforeEach 'setup_parser'

		It 'accumulates multiple -e flags'
			When call parse -e "$TEST_DIR/a.env" -e "$TEST_DIR/b.env" cmd
			The status should be success
			The variable ENV_FILES[0] should equal "$TEST_DIR/a.env"
			The variable ENV_FILES[1] should equal "$TEST_DIR/b.env"
		End

		It 'accumulates three -e flags'
			When call parse -e "$TEST_DIR/a.env" -e "$TEST_DIR/b.env" -e "$TEST_DIR/c.env" cmd
			The status should be success
			The variable ENV_FILES[0] should equal "$TEST_DIR/a.env"
			The variable ENV_FILES[1] should equal "$TEST_DIR/b.env"
			The variable ENV_FILES[2] should equal "$TEST_DIR/c.env"
		End

		It 'preserves order of -e flags'
			When call parse -e first.env -e second.env -e third.env cmd
			The status should be success
			The variable ENV_FILES[0] should equal "first.env"
			The variable ENV_FILES[1] should equal "second.env"
			The variable ENV_FILES[2] should equal "third.env"
		End

		It 'handles -e mixed with other flags'
			When call parse -e "$TEST_DIR/a.env" -s -e "$TEST_DIR/b.env" -q cmd
			The status should be success
			The variable ENV_FILES[0] should equal "$TEST_DIR/a.env"
			The variable ENV_FILES[1] should equal "$TEST_DIR/b.env"
			The variable STRICT should equal "1"
			The variable SILENT should equal "1"
		End
	End
End
