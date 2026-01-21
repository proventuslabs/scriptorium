#!/usr/bin/env bash
# jwt - decode and verify JSON Web Tokens

set -euo pipefail

# Option parsing (runtime: uses getoptions, bundle: inlines generated parser)
# @start-kcov-exclude
# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
. ./options.sh
eval "$(getoptions parser_definition parse)"
# @bundle end
# @end-kcov-exclude

# @bundle source
. ./decode.sh
# @bundle source
. ./verify.sh

# Parse options
parse "$@" || exit 2
eval "set -- $REST"

# Set globals for jwt functions
JWT_QUIET="${QUIET:-}"

# Handle -k value: secret string, @file, @-, or -
# Always pass content to verify_signature (it handles temp files for asymmetric)
verify_key=${KEY:-}
if [[ -n $verify_key ]]; then
	case $verify_key in
		- | @-)
			# Read key from stdin
			if [[ $# -eq 0 ]]; then
				echo "jwt: error: token argument required when reading key from stdin" >&2
				exit 1
			fi
			# Read all stdin (may be multiline PEM)
			verify_key=$(cat)
			;;
		@*)
			# Read key from file
			keyfile=${verify_key#@}
			if [[ ! -r $keyfile ]]; then
				echo "jwt: error: cannot read key file '$keyfile'" >&2
				exit 1
			fi
			verify_key=$(<"$keyfile")
			;;
	esac
fi

# Get token from argument or stdin
if [[ $# -gt 0 ]]; then
	token=$1
elif [[ ! -t 0 ]]; then
	# Read from stdin
	read -r token
else
	# @start-kcov-exclude - TTY + no args can't be tested in ShellSpec (uses pipes)
	echo "jwt: error: no token provided" >&2
	exit 1
	# @end-kcov-exclude
fi

# Split and decode token
jwt_split "$token" || exit $?
jwt_decode_header || exit $?
jwt_decode_payload || exit $?

# Verify if requested
if [[ -n $verify_key ]]; then
	verify_signature "$verify_key" || exit $?
fi

# Output based on mode
case ${OUTPUT:-payload} in
	header)
		printf '%s\n' "$JWT_HEADER"
		;;
	payload)
		printf '%s\n' "$JWT_PAYLOAD"
		;;
	sig)
		base64url_decode "$JWT_SIG_B64"
		;;
	all)
		sig_b64=$(base64url_decode "$JWT_SIG_B64" | base64 | tr -d '\n')
		printf '{"header":%s,"payload":%s,"signature":"%s"}\n' \
			"$JWT_HEADER" "$JWT_PAYLOAD" "$sig_b64"
		;;
esac
