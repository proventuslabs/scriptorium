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

    It 'shows help with -h'
        man() {
            echo "man called"
        }
        When call mkcd -h
        The status should be success
        The output should include 'man called'
    End

    It 'creates a single directory and enters it'
        When call mkcd testdir
        The status should be success
        The path "$TMPDIR/testdir" should be a directory
        The path $(pwd) should equal "$TMPDIR/testdir"
    End

    It 'creates nested directories with -p and enters the last one'
        When call mkcd -p nested/dir/structure
        The status should be success
        The path "$TMPDIR/nested/dir/structure" should be a directory
        The path $(pwd) should equal "$TMPDIR/nested/dir/structure"
    End

    It 'forwards options to mkdir'
        When call mkcd -illegal testperm
        The status should be failure
        The path "$TMPDIR/testperm" should not be exist
        The error should include 'illegal option'
    End

    It 'fails when mkdir fails (e.g., missing name)'
        When call mkcd
        The status should be failure
        The error should include 'at least 1 argument'
    End

End
