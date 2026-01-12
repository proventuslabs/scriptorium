# shellcheck shell=bash

Describe 'bundle.sh'
	setup() {
		TEST_DIR=$(mktemp -d)
	}

	cleanup() {
		rm -rf "$TEST_DIR"
	}

	BeforeEach 'setup'
	AfterEach 'cleanup'

	Describe 'CLI options'
		It 'shows help with -h'
			When run script ./bundle.sh -h
			The status should be success
			The output should include 'Usage:'
			The output should include '--strip-comments'
			The output should include '--hide-markers'
		End

		It 'shows help with --help'
			When run script ./bundle.sh --help
			The status should be success
			The output should include 'Usage:'
		End

		It 'shows version with -V'
			When run script ./bundle.sh -V
			The status should be success
			The output should match pattern '*.*.*'
		End

		It 'shows version with --version'
			When run script ./bundle.sh --version
			The status should be success
			The output should match pattern '*.*.*'
		End
	End

	Describe 'basic functionality'
		It 'preserves shebang from entry file'
			echo '#!/usr/bin/env bash' > "$TEST_DIR/entry.sh"
			echo 'echo hello' >> "$TEST_DIR/entry.sh"

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The line 1 of output should equal '#!/usr/bin/env bash'
		End

		It 'outputs file content'
			echo '#!/bin/bash' > "$TEST_DIR/entry.sh"
			echo 'echo hello' >> "$TEST_DIR/entry.sh"

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'echo hello'
		End

		It 'fails when file not found'
			When run script ./bundle.sh "$TEST_DIR/nonexistent.sh"
			The status should be failure
			The stderr should include 'file not found'
		End

		It 'shows usage when no arguments'
			When run script ./bundle.sh
			The status should be failure
			The stderr should include 'Usage:'
		End
	End

	Describe 'source inlining with # @bundle source'
		It 'inlines sourced files with dot notation when marked'
			echo 'SOURCED=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'SOURCED=yes'
			The output should include '# --- begin:'
			The output should include '# --- end:'
		End

		It 'inlines sourced files with source keyword when marked'
			echo 'SOURCED=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
source ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'SOURCED=yes'
		End

		It 'keeps source verbatim without # @bundle source'
			echo 'SOURCED=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should not include 'SOURCED=yes'
			The output should include '. ./lib.sh'
		End

		It 'handles recursive sourcing when marked'
			echo 'DEEP=yes' > "$TEST_DIR/deep.sh"
			cat > "$TEST_DIR/lib.sh" << 'EOF'
# @bundle source
. ./deep.sh
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'DEEP=yes'
		End

		It 'skips duplicate includes'
			echo 'ONCE=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include '# --- skipped (already included):'
		End

		It 'removes shebang from sourced files'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
#!/bin/bash
LIB=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			# Output: shebang, begin marker, LIB=yes, end marker (4 lines)
			The lines of output should equal 4
		End

		It 'errors when # @bundle source is followed by non-source'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
echo "not a source"
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be failure
			The stderr should include "must be followed by a source statement"
			# Partial output before error
			The output should include '#!/bin/bash'
		End

		It 'errors when bundled file not found'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./nonexistent.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be failure
			The stderr should include 'file not found'
			# Partial output before error
			The output should include '#!/bin/bash'
		End
	End

	Describe '@bundle cmd directive'
		It 'inlines command output and skips block until @bundle end'
			echo '#!/bin/bash' > "$TEST_DIR/entry.sh"
			echo '# @bundle cmd echo "GENERATED"' >> "$TEST_DIR/entry.sh"
			echo 'THIS_SHOULD_BE_SKIPPED=yes' >> "$TEST_DIR/entry.sh"
			echo '# @bundle end' >> "$TEST_DIR/entry.sh"
			echo 'AFTER_END=yes' >> "$TEST_DIR/entry.sh"

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'GENERATED'
			The output should include '# --- begin:'
			The output should not include 'THIS_SHOULD_BE_SKIPPED'
			The output should include 'AFTER_END=yes'
		End

		It 'runs command in context of source file directory'
			mkdir -p "$TEST_DIR/subdir"
			echo 'SUBFILE' > "$TEST_DIR/subdir/data.txt"
			echo '#!/bin/bash' > "$TEST_DIR/subdir/entry.sh"
			echo '# @bundle cmd cat data.txt' >> "$TEST_DIR/subdir/entry.sh"
			echo '# @bundle end' >> "$TEST_DIR/subdir/entry.sh"

			When run script ./bundle.sh "$TEST_DIR/subdir/entry.sh"
			The status should be success
			The output should include 'SUBFILE'
		End

		It 'replaces runtime code with generated output from file'
			cat > "$TEST_DIR/generated.sh" << 'EOF'
generated_func() {
	echo "this was generated"
}
EOF
			echo '#!/bin/bash' > "$TEST_DIR/entry.sh"
			echo '# @bundle cmd cat ./generated.sh' >> "$TEST_DIR/entry.sh"
			echo '. ./runtime_only.sh' >> "$TEST_DIR/entry.sh"
			# shellcheck disable=SC2016 # Single quotes intentional - writing literal file content.
			echo 'eval "$(generate_at_runtime)"' >> "$TEST_DIR/entry.sh"
			echo '# @bundle end' >> "$TEST_DIR/entry.sh"
			echo 'generated_func' >> "$TEST_DIR/entry.sh"

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'generated_func()'
			The output should not include '. ./runtime_only.sh'
			# shellcheck disable=SC2016 # Single quotes intentional - matching literal output.
			The output should not include 'eval "$(generate_at_runtime'
		End

		It 'handles indented @bundle cmd directive'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
case $cmd in
	foo)
		# @bundle cmd echo "INDENTED_CMD"
		SKIPPED=yes
		# @bundle end
		echo "after"
		;;
esac
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'INDENTED_CMD'
			The output should not include 'SKIPPED=yes'
			The output should include 'echo "after"'
		End

		It 'handles indented @bundle end directive'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
if true; then
	# @bundle cmd echo "IN_IF"
	SKIPPED=yes
	# @bundle end
	KEPT=yes
fi
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'IN_IF'
			The output should not include 'SKIPPED=yes'
			The output should include 'KEPT=yes'
		End

		It 'converts << to <<- in indented command output for heredocs'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
case $cmd in
	foo)
		# @bundle cmd printf '%s\n' 'usage() {' 'cat<<DELIM' 'hello' 'DELIM' '}'
		SKIPPED=yes
		# @bundle end
		;;
esac
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			# Heredoc should be converted to <<- so it works when indented
			The output should include 'cat<<-DELIM'
			The output should not include 'SKIPPED=yes'
		End
	End

	Describe '@bundle keep directive'
		# Helper: create a mock command that accepts -f and outputs "GENERATED"
		mock_generator() {
			cat > "$TEST_DIR/mockgen" << 'SCRIPT'
#!/bin/bash
echo "GENERATED"
SCRIPT
			chmod +x "$TEST_DIR/mockgen"
		}

		It 'extracts keep blocks from -f referenced file'
			mock_generator
			cat > "$TEST_DIR/opts.sh" << 'EOF'
# @bundle keep
VERSION=1.0
# @bundle end

parser_definition() {
	echo "parser code"
}
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle cmd ./mockgen -f ./opts.sh
eval "$(generate_parser)"
# @bundle end
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include '# --- keep from:'
			The output should include 'VERSION=1.0'
			The output should not include 'parser_definition'
			The output should include 'GENERATED'
		End

		It 'handles multiple keep blocks'
			mock_generator
			cat > "$TEST_DIR/opts.sh" << 'EOF'
# @bundle keep
VAR1=one
# @bundle end

middle_stuff() { :; }

# @bundle keep
VAR2=two
# @bundle end
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle cmd ./mockgen -f ./opts.sh
skipped
# @bundle end
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'VAR1=one'
			The output should include 'VAR2=two'
			The output should not include 'middle_stuff'
		End

		It 'outputs nothing when no keep blocks exist'
			mock_generator
			cat > "$TEST_DIR/opts.sh" << 'EOF'
parser_definition() {
	echo "parser code"
}
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle cmd ./mockgen -f ./opts.sh
skipped
# @bundle end
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should not include '# --- keep from:'
			The output should include 'GENERATED'
		End

		It 'preserves indentation for keep blocks'
			mock_generator
			cat > "$TEST_DIR/opts.sh" << 'EOF'
# @bundle keep
VERSION=1.0
# @bundle end
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
case $cmd in
	foo)
		# @bundle cmd ./mockgen -f ./opts.sh
		skipped
		# @bundle end
		;;
esac
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include $'\t\t# --- keep from:'
			The output should include $'\t\tVERSION=1.0'
		End

		It 'excludes the keep/end directives themselves'
			mock_generator
			cat > "$TEST_DIR/opts.sh" << 'EOF'
# @bundle keep
KEPT=yes
# @bundle end
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle cmd ./mockgen -f ./opts.sh
skipped
# @bundle end
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'KEPT=yes'
			The output should not match pattern '*# @bundle keep*'
		End
	End

	Describe 'shebang validation'
		It 'errors on mismatched shebang'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
#!/usr/bin/env zsh
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/usr/bin/env bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be failure
			The stderr should include 'shebang mismatch'
			The stderr should include '#!/usr/bin/env bash'
			The stderr should include '#!/usr/bin/env zsh'
			# Partial output before error
			The output should include '#!/usr/bin/env bash'
		End

		It 'allows matching shebangs'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
#!/usr/bin/env bash
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/usr/bin/env bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'LIB_VAR=yes'
		End

		It 'allows sourced files without shebang'
			echo 'LIB_VAR=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/usr/bin/env bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'LIB_VAR=yes'
		End

		It 'errors on nested file with mismatched shebang'
			cat > "$TEST_DIR/deep.sh" << 'EOF'
#!/bin/sh
DEEP_VAR=yes
EOF
			cat > "$TEST_DIR/lib.sh" << 'EOF'
# @bundle source
. ./deep.sh
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/usr/bin/env bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be failure
			The stderr should include 'shebang mismatch'
			# Partial output before error
			The output should include '#!/usr/bin/env bash'
		End

		It 'ignores shebang-like content in heredocs'
			cat > "$TEST_DIR/lib.sh" << 'OUTER'
generate_script() {
	cat <<EOF
#!/bin/sh
echo "generated"
EOF
}
OUTER
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/usr/bin/env bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include '#!/bin/sh'
			The output should include 'generate_script()'
		End
	End

	Describe 'indentation preservation'
		It 'preserves indentation for inlined source files'
			echo 'LIB_VAR=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
if true; then
	# @bundle source
	. ./lib.sh
fi
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include $'\t# --- begin:'
			The output should include $'\tLIB_VAR=yes'
			The output should include $'\t# --- end:'
		End

		It 'preserves indentation for @bundle cmd output'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
case $cmd in
	foo)
		# @bundle cmd echo "GENERATED_LINE"
		SKIPPED=yes
		# @bundle end
		;;
esac
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include $'\t\t# --- begin:'
			The output should include $'\t\tGENERATED_LINE'
			The output should include $'\t\t# --- end:'
		End

		It 'preserves indentation for multiline @bundle cmd output'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
	# @bundle cmd printf 'LINE1\nLINE2\nLINE3\n'
	SKIPPED=yes
	# @bundle end
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include $'\t# --- begin:'
			The output should include $'\tLINE1'
			The output should include $'\tLINE2'
			The output should include $'\tLINE3'
		End

		It 'accumulates indentation in nested sourcing'
			echo 'DEEP_VAR=yes' > "$TEST_DIR/deep.sh"
			cat > "$TEST_DIR/lib.sh" << 'EOF'
if nested; then
	# @bundle source
	. ./deep.sh
fi
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
if outer; then
	# @bundle source
	. ./lib.sh
fi
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			# lib.sh is indented once (from entry.sh)
			The output should include $'\t# --- begin:'
			# deep.sh is indented twice (from entry.sh + lib.sh)
			The output should include $'\t\t# --- begin:'
			The output should include $'\t\tDEEP_VAR=yes'
		End

		It 'preserves space indentation'
			echo 'LIB_VAR=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
if true; then
    # @bundle source
    . ./lib.sh
fi
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			The output should include '    # --- begin:'
			The output should include '    LIB_VAR=yes'
		End

		It 'does not indent top-level sources'
			echo 'TOP_VAR=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
echo done
EOF

			When run script ./bundle.sh "$TEST_DIR/entry.sh"
			The status should be success
			# Begin marker should start at column 0 (no leading whitespace)
			The line 2 of output should start with '# --- begin:'
			The line 3 of output should equal 'TOP_VAR=yes'
		End
	End

	Describe '--strip-comments option'
		It 'strips full-line comments from source files'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# This is a comment
echo hello
# Another comment
echo world
EOF

			When run script ./bundle.sh --strip-comments "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'echo hello'
			The output should include 'echo world'
			The output should not include 'This is a comment'
			The output should not include 'Another comment'
		End

		It 'preserves shebang'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# comment
echo hello
EOF

			When run script ./bundle.sh --strip-comments "$TEST_DIR/entry.sh"
			The status should be success
			The line 1 of output should equal '#!/bin/bash'
		End

		It 'preserves inline comments on code lines'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
echo hello # inline comment
EOF

			When run script ./bundle.sh --strip-comments "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'echo hello # inline comment'
		End

		It 'strips comments from inlined source files'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
# lib comment
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh --strip-comments "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'LIB_VAR=yes'
			The output should not include 'lib comment'
		End

		It 'works with short option -s'
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# comment
echo hello
EOF

			When run script ./bundle.sh -s "$TEST_DIR/entry.sh"
			The status should be success
			The output should not include '# comment'
		End

		It 'preserves bundle marker comments by default'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh --strip-comments "$TEST_DIR/entry.sh"
			The status should be success
			The output should include '# --- begin:'
			The output should include '# --- end:'
		End
	End

	Describe '--hide-markers option'
		It 'suppresses begin/end markers for inlined sources'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh --hide-markers "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'LIB_VAR=yes'
			The output should not include '# --- begin:'
			The output should not include '# --- end:'
		End

		It 'suppresses skipped markers for duplicates'
			echo 'ONCE=yes' > "$TEST_DIR/lib.sh"
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh --hide-markers "$TEST_DIR/entry.sh"
			The status should be success
			The output should not include '# --- skipped'
		End

		It 'suppresses markers for @bundle cmd output'
			echo '#!/bin/bash' > "$TEST_DIR/entry.sh"
			echo '# @bundle cmd echo "GENERATED"' >> "$TEST_DIR/entry.sh"
			echo 'SKIPPED=yes' >> "$TEST_DIR/entry.sh"
			echo '# @bundle end' >> "$TEST_DIR/entry.sh"

			When run script ./bundle.sh --hide-markers "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'GENERATED'
			The output should not include '# --- begin:'
			The output should not include '# --- end:'
		End

		It 'suppresses keep markers'
			cat > "$TEST_DIR/mockgen" << 'SCRIPT'
#!/bin/bash
echo "GENERATED"
SCRIPT
			chmod +x "$TEST_DIR/mockgen"
			cat > "$TEST_DIR/opts.sh" << 'EOF'
# @bundle keep
VERSION=1.0
# @bundle end
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle cmd ./mockgen -f ./opts.sh
skipped
# @bundle end
EOF

			When run script ./bundle.sh --hide-markers "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'VERSION=1.0'
			The output should not include '# --- keep from:'
		End

		It 'works with short option -n'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh -n "$TEST_DIR/entry.sh"
			The status should be success
			The output should not include '# ---'
		End

		It 'combines with --strip-comments'
			cat > "$TEST_DIR/lib.sh" << 'EOF'
# lib comment
LIB_VAR=yes
EOF
			cat > "$TEST_DIR/entry.sh" << 'EOF'
#!/bin/bash
# entry comment
# @bundle source
. ./lib.sh
EOF

			When run script ./bundle.sh --strip-comments --hide-markers "$TEST_DIR/entry.sh"
			The status should be success
			The output should include 'LIB_VAR=yes'
			The output should not include '# lib comment'
			The output should not include '# entry comment'
			The output should not include '# ---'
		End
	End
End
