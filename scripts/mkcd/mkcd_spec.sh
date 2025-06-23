Describe 'mkcd'
	Include ./mkcd.zsh

	BeforeEach 'setup'
	AfterEach 'cleanup'

	setup() {
		TMPDIR=$(mktemp -d)
		cd "$TMPDIR" || exit 1
	}

	cleanup() {
		rm -rf "$TMPDIR"
	}

	It 'should show help with -h'
		man() {
			echo "man called"
		}
		When call mkcd -h
		The status should be success
		The output should include 'man called'
	End

	It 'should create a single directory and enter it'
		When call mkcd testdir
		The status should be success
		The path "$TMPDIR/testdir" should be a directory
		The path $(pwd) should equal "$TMPDIR/testdir"
	End

	It 'should create multiple directories and enter the last one'
		When call mkcd testsome testdirectories testinarow
		The status should be success
		The path "$TMPDIR/testsome" should be a directory
		The path "$TMPDIR/testdirectories" should be a directory
		The path "$TMPDIR/testinarow" should be a directory
		The path $(pwd) should equal "$TMPDIR/testinarow"
	End

	It 'should fail if its missing at least 1 directory'
		When call mkcd
		The status should be failure
		The error should include 'at least 1 argument'
	End

	It 'should forward options to mkdir'
		When call mkcd -p some/nested/directory
		The status should be success
		The path "$TMPDIR/some/nested/directory" should be a directory
		The path $(pwd) should equal "$TMPDIR/some/nested/directory"
	End

End
