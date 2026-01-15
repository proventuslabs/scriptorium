# shellcheck shell=bash

# BDD tests for jwt - test all behaviors through CLI invocation
#
# Tests the bundled script as users experience it.
# Run `make build NAME=jwt` before running tests.
#
# Note: Some tests require OpenSSL 3.x. If tests fail on your machine (e.g.,
# LibreSSL on macOS), run: nix develop --command make test NAME=jwt

Describe 'jwt'
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
	BIN="${SHELLSPEC_PROJECT_ROOT}/dist/jwt/bin/jwt"
	FIXTURES="${SHELLSPEC_PROJECT_ROOT}/scripts/jwt/fixtures"

	# Test tokens
	# {"alg":"HS256","typ":"JWT"}.{"sub":"1234567890","name":"John Doe","iat":1516239022}
	hs256_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
	hs256_secret="your-256-bit-secret"

	# Same payload signed with HS384
	hs384_token="eyJhbGciOiJIUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.YWN5rATBqOKAycXyORG7CB2JtsbBXzpilYPJrYng-MGCrMTMA0jcCBuVQyRdFd6A"
	hs384_secret="your-384-bit-secret-your-384-bit-secret"

	# Same payload signed with HS512
	hs512_token="eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.9TXC-_IVI8qpJDUutgTn0Tbxctsoty8BI7lXVaaL3QIPMAbj6mwWZ7LuFFYqx3kbxo9ytdH3y3p8D_80koVA5w"
	hs512_secret="your-512-bit-secret-your-512-bit-secret-your-512-bit-secret-your"

	# RS256 token (RSA with SHA-256)
	rs256_token="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.Nz1lEkPD4m15aqE12GhhVvtEX6BwikXVieg9771SZ4GRQNyAt2gKe_4knWpSakVWuWjtSvlNUqOTCIWFXzkhTUPikjYlyH1ljP5HRggm0I4upKcO0-UnVsmirMQr8DoI1zYXOnS-C7xnLD4xhBQNQTNIOE0ITljrg-mKuesRoOVJkWoIus-tyu76U4r2fkgNkzCV0GBcczNVRT-uz1bpDNgJYbhgQMO5QcLKIjGKcWV9xI-Zm7XCInT-I6i2QF3eC-5gcIm3xJuRPHUzA_x7UiMvW1FgfIusF8W_rYR5n2bpON_1HmX0DaN-sXNN8GfPaCsEY7zaqe3Q0RRV9hCNig"

	# PS256 token (RSA-PSS with SHA-256)
	ps256_token="eyJhbGciOiJQUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.m6Le-4Dvr5cvoTG0V0weW4_1st46wgrBJfOsDyvo8YMnkhM_BtIyFC6R8nM7yR07JY575h_YAs3mhyIcWOaH7XSN8RzeSdOsyF4JCdSRb8T_J9Bc79b-s8GzDpLPzK0JEUhRZ8nuwQdlC1bYjpg3j24qVObYrbIGxbyBBw2gZwHlodEiT91dINcwlkCmb9OKY637-Av2opIx2jVAtbEcuoYzPJZZJt3wIVKrPLouHb56WqlnEZq1vQW4_NaYXQWG4N0IhFqNFBWbQozAkGtTtUKnrGYkoHss7xXLIEvgwHCATb129i2t5pOZwUtYXEL-du_zGb_w5szfMmQz36D9UA"

	# ES256 token (ECDSA P-256)
	es256_token="eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.K7EFRvY4VrY8fWQqujS0i74b4LAUKnKjrOyp3RIGT6bhqBcCwB-Bb4IsN7LHuBYKX4oKsvQhjEonglFOtOE0cQ"

	# ES384 token (ECDSA P-384)
	es384_token="eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.p2LTBea-meWo3Ha_ZcXplHZH8PGS_Bd3cpDl1XAYgimBRUDKe7nqNYKFP-g1_3J2gLNMj9Q6ScHHIDRVLWiOwexdaekt9-O7MF9mwCKQFbDxDihBP-RmOv6Q4IqG6ksG"

	# EdDSA token (Ed25519)
	eddsa_token="eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.AtVLeiP1LS1KMQU8uJxObxoU1GVKzJV4JxeUfGa5WAopAYb31nKCx1uvckXYyk4fBq3iTwQ7z6QHa05eL6x9Dw"

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
	# TOKEN INPUT
	#═══════════════════════════════════════════════════════════════
	Describe 'token input'
		It 'reads token from argument'
			When run script "$BIN" "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'reads token from stdin'
			Data "$hs256_token"
			When run script "$BIN"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'fails with empty token from stdin'
			Data ""
			When run script "$BIN"
			The status should be failure
			The stderr should include "empty token"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# OUTPUT MODES
	#═══════════════════════════════════════════════════════════════
	Describe 'output modes'
		It 'outputs payload by default'
			When run script "$BIN" "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
			The output should include '"name":"John Doe"'
		End

		It 'outputs payload with -P'
			When run script "$BIN" -P "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'outputs payload with --payload'
			When run script "$BIN" --payload "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'outputs header with -H'
			When run script "$BIN" -H "$hs256_token"
			The status should be success
			The output should include '"alg":"HS256"'
			The output should include '"typ":"JWT"'
		End

		It 'outputs header with --header'
			When run script "$BIN" --header "$hs256_token"
			The status should be success
			The output should include '"alg":"HS256"'
		End

		It 'outputs raw signature with -S'
			When run script "$BIN" -S "$hs256_token"
			The status should be success
			# Raw signature is binary, just check it produces output
			The output should be present
		End

		It 'outputs all parts as JSON with -A'
			When run script "$BIN" -A "$hs256_token"
			The status should be success
			The output should include '"header":'
			The output should include '"payload":'
			The output should include '"signature":'
		End

		It 'outputs all parts as JSON with --all'
			When run script "$BIN" --all "$hs256_token"
			The status should be success
			The output should include '"header":'
		End
	End

	#═══════════════════════════════════════════════════════════════
	# HMAC VERIFICATION
	#═══════════════════════════════════════════════════════════════
	Describe 'HMAC verification'
		It 'verifies HS256 with correct secret'
			When run script "$BIN" -v "$hs256_secret" "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects HS256 with wrong secret'
			When run script "$BIN" -v "wrong-secret" "$hs256_token"
			The status should be failure
			The stderr should include "verification failed"
		End

		It 'verifies HS384 with correct secret'
			When run script "$BIN" -v "$hs384_secret" "$hs384_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'verifies HS512 with correct secret'
			When run script "$BIN" -v "$hs512_secret" "$hs512_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'reads secret from file with @file'
			echo -n "$hs256_secret" > secret.txt
			When run script "$BIN" -v @secret.txt "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'fails when key file not found'
			When run script "$BIN" -v @nonexistent.txt "$hs256_token"
			The status should be failure
			The stderr should include "cannot read key file"
		End

		It 'reads secret from stdin with @-'
			Data "$hs256_secret"
			When run script "$BIN" -v @- "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'reads secret from stdin with - (requires token as arg)'
			Data "$hs256_secret"
			When run script "$BIN" -v - "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'errors when reading key from stdin without token argument'
			Data "$hs256_secret"
			When run script "$BIN" -v -
			The status should be failure
			The stderr should include "token argument required"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# RSA VERIFICATION
	#═══════════════════════════════════════════════════════════════
	Describe 'RSA verification'
		It 'verifies RS256 with correct public key'
			When run script "$BIN" -v "@$FIXTURES/rs256_public.pem" "$rs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects RS256 with wrong key'
			When run script "$BIN" -v "@$FIXTURES/ed25519_public.pem" "$rs256_token"
			The status should be failure
			The stderr should include "verification failed"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# RSA-PSS VERIFICATION (OpenSSL 3.x)
	#═══════════════════════════════════════════════════════════════
	Describe 'RSA-PSS verification'
		It 'verifies PS256 with correct public key'
			When run script "$BIN" -v "@$FIXTURES/ps256_public.pem" "$ps256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects PS256 with wrong key'
			When run script "$BIN" -v "@$FIXTURES/ed25519_public.pem" "$ps256_token"
			The status should be failure
			The stderr should include "verification failed"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# ECDSA VERIFICATION
	#═══════════════════════════════════════════════════════════════
	Describe 'ECDSA verification'
		It 'verifies ES256 with correct public key'
			When run script "$BIN" -v "@$FIXTURES/es256_public.pem" "$es256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects ES256 with wrong key'
			When run script "$BIN" -v "@$FIXTURES/es384_public.pem" "$es256_token"
			The status should be failure
			The stderr should include "verification failed"
		End

		It 'verifies ES384 with correct public key'
			When run script "$BIN" -v "@$FIXTURES/es384_public.pem" "$es384_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects ES384 with wrong key'
			When run script "$BIN" -v "@$FIXTURES/es256_public.pem" "$es384_token"
			The status should be failure
			The stderr should include "verification failed"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# EdDSA VERIFICATION (OpenSSL 3.x)
	#═══════════════════════════════════════════════════════════════
	Describe 'EdDSA verification'
		It 'verifies EdDSA with correct public key'
			When run script "$BIN" -v "@$FIXTURES/ed25519_public.pem" "$eddsa_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It 'rejects EdDSA with wrong key'
			When run script "$BIN" -v "@$FIXTURES/ps256_public.pem" "$eddsa_token"
			The status should be failure
			The stderr should include "verification failed"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# ERROR HANDLING
	#═══════════════════════════════════════════════════════════════
	Describe 'error handling'
		It 'rejects empty token'
			When run script "$BIN" ""
			The status should be failure
			The stderr should include "empty token"
		End

		It 'rejects token with only 2 parts'
			When run script "$BIN" "header.payload"
			The status should be failure
			The stderr should include "invalid JWT format"
		End

		It 'rejects token with 4 parts'
			When run script "$BIN" "a.b.c.d"
			The status should be failure
			The stderr should include "invalid JWT format"
		End

		It 'rejects invalid base64 in header'
			When run script "$BIN" "!!invalid!!.payload.sig"
			The status should be failure
			The stderr should include "failed to decode"
		End

		It 'rejects non-JSON header'
			# "not json" in base64url = bm90IGpzb24
			When run script "$BIN" "bm90IGpzb24.eyJ0ZXN0IjoxfQ.sig"
			The status should be failure
			The stderr should include "invalid"
		End

		It 'rejects header without alg'
			# {"typ":"JWT"} in base64url = eyJ0eXAiOiJKV1QifQ
			When run script "$BIN" "eyJ0eXAiOiJKV1QifQ.eyJ0ZXN0IjoxfQ.sig"
			The status should be failure
			The stderr should include "missing 'alg'"
		End

		It 'rejects invalid payload JSON'
			# Valid header: {"alg":"HS256","typ":"JWT"} = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
			# Invalid payload: "not json" = bm90IGpzb24
			When run script "$BIN" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.bm90IGpzb24.sig"
			The status should be failure
			The stderr should include "invalid"
		End

		It 'rejects unsupported algorithm during verification'
			# {"alg":"XX99","typ":"JWT"} = eyJhbGciOiJYWDk5IiwidHlwIjoiSldUIn0
			# {"sub":"test"} = eyJzdWIiOiJ0ZXN0In0
			When run script "$BIN" -v "secret" "eyJhbGciOiJYWDk5IiwidHlwIjoiSldUIn0.eyJzdWIiOiJ0ZXN0In0.sig"
			The status should be failure
			The stderr should include "unsupported algorithm"
		End

		It 'fails when no token provided and stdin is empty tty'
			# This tests the "no token provided" error path
			# We can't truly test tty detection, but we test empty stdin
			Data ""
			When run script "$BIN"
			The status should be failure
			The stderr should include "empty token"
		End
	End

	#═══════════════════════════════════════════════════════════════
	# QUIET MODE
	#═══════════════════════════════════════════════════════════════
	Describe 'quiet mode'
		# Note: -q suppresses warnings, not errors.
		# Verification failure is an error (jwt: error:), not a warning.
		# Test that -q works with normal decoding.

		It '-q works with normal operation'
			When run script "$BIN" -q "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End

		It '--quiet works with normal operation'
			When run script "$BIN" --quiet "$hs256_token"
			The status should be success
			The output should include '"sub":"1234567890"'
		End
	End
End
