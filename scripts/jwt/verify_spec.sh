# shellcheck shell=bash disable=SC2034

Describe 'verify'
	Include ./decode.sh
	Include ./verify.sh

	# Test JWT: {"alg":"HS256","typ":"JWT"}.{"sub":"1234567890","name":"John Doe","iat":1516239022}
	# Signed with secret "your-256-bit-secret"
	hs256_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
	hs256_secret="your-256-bit-secret"

	# Same payload signed with HS384, secret "your-384-bit-secret-your-384-bit-secret"
	hs384_token="eyJhbGciOiJIUzM4NCIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.YWN5rATBqOKAycXyORG7CB2JtsbBXzpilYPJrYng-MGCrMTMA0jcCBuVQyRdFd6A"
	hs384_secret="your-384-bit-secret-your-384-bit-secret"

	# Same payload signed with HS512
	hs512_token="eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.9TXC-_IVI8qpJDUutgTn0Tbxctsoty8BI7lXVaaL3QIPMAbj6mwWZ7LuFFYqx3kbxo9ytdH3y3p8D_80koVA5w"
	hs512_secret="your-512-bit-secret-your-512-bit-secret-your-512-bit-secret-your"

	# PS256 token (RSA-PSS with SHA-256)
	ps256_token="eyJhbGciOiJQUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.m6Le-4Dvr5cvoTG0V0weW4_1st46wgrBJfOsDyvo8YMnkhM_BtIyFC6R8nM7yR07JY575h_YAs3mhyIcWOaH7XSN8RzeSdOsyF4JCdSRb8T_J9Bc79b-s8GzDpLPzK0JEUhRZ8nuwQdlC1bYjpg3j24qVObYrbIGxbyBBw2gZwHlodEiT91dINcwlkCmb9OKY637-Av2opIx2jVAtbEcuoYzPJZZJt3wIVKrPLouHb56WqlnEZq1vQW4_NaYXQWG4N0IhFqNFBWbQozAkGtTtUKnrGYkoHss7xXLIEvgwHCATb129i2t5pOZwUtYXEL-du_zGb_w5szfMmQz36D9UA"
	ps256_pubkey=$(cat ./fixtures/ps256_public.pem)

	# EdDSA token (Ed25519)
	eddsa_token="eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.AtVLeiP1LS1KMQU8uJxObxoU1GVKzJV4JxeUfGa5WAopAYb31nKCx1uvckXYyk4fBq3iTwQ7z6QHa05eL6x9Dw"
	eddsa_pubkey=$(cat ./fixtures/ed25519_public.pem)

	Describe 'verify_hmac'
		It 'verifies valid HS256 signature'
			jwt_split "$hs256_token"
			jwt_decode_header
			When call verify_hmac "$hs256_secret"
			The status should be success
		End

		It 'rejects invalid HS256 signature with wrong secret'
			jwt_split "$hs256_token"
			jwt_decode_header
			When call verify_hmac "wrong-secret"
			The status should equal 3
			The stderr should include "verification failed"
		End

		It 'verifies valid HS384 signature'
			jwt_split "$hs384_token"
			jwt_decode_header
			When call verify_hmac "$hs384_secret"
			The status should be success
		End

		It 'verifies valid HS512 signature'
			jwt_split "$hs512_token"
			jwt_decode_header
			When call verify_hmac "$hs512_secret"
			The status should be success
		End
	End

	Describe 'get_openssl_digest'
		It 'returns sha256 for HS256'
			JWT_ALG="HS256"
			When call get_openssl_digest
			The output should equal "sha256"
		End

		It 'returns sha384 for HS384'
			JWT_ALG="HS384"
			When call get_openssl_digest
			The output should equal "sha384"
		End

		It 'returns sha512 for HS512'
			JWT_ALG="HS512"
			When call get_openssl_digest
			The output should equal "sha512"
		End

		It 'returns sha256 for RS256'
			JWT_ALG="RS256"
			When call get_openssl_digest
			The output should equal "sha256"
		End

		It 'returns sha256 for ES256'
			JWT_ALG="ES256"
			When call get_openssl_digest
			The output should equal "sha256"
		End

		It 'fails for unsupported algorithm'
			JWT_ALG="UNKNOWN"
			When call get_openssl_digest
			The status should equal 7
			The stderr should include "unsupported algorithm"
		End
	End

	Describe 'check_dependencies'
		It 'succeeds when openssl is available'
			When call check_dependencies
			The status should be success
		End
	End

	Describe 'check_openssl_version'
		It 'returns OpenSSL major version'
			When call get_openssl_major_version
			The status should be success
			The output should match pattern '[0-9]*'
		End
	End

	Describe 'verify_pss'
		It 'verifies valid PS256 signature'
			jwt_split "$ps256_token"
			jwt_decode_header
			When call verify_pss "$ps256_pubkey"
			The status should be success
		End

		It 'rejects invalid PS256 signature with wrong key'
			jwt_split "$ps256_token"
			jwt_decode_header
			# Use EdDSA key (wrong type) to trigger failure
			When call verify_pss "$eddsa_pubkey"
			The status should equal 3
			The stderr should include "verification failed"
		End
	End

	Describe 'verify_eddsa'
		It 'verifies valid EdDSA signature'
			jwt_split "$eddsa_token"
			jwt_decode_header
			When call verify_eddsa "$eddsa_pubkey"
			The status should be success
		End

		It 'rejects invalid EdDSA signature with wrong key'
			jwt_split "$eddsa_token"
			jwt_decode_header
			When call verify_eddsa "$ps256_pubkey"
			The status should equal 3
			The stderr should include "verification failed"
		End
	End

	Describe 'get_openssl_digest with new algorithms'
		It 'returns sha256 for PS256'
			JWT_ALG="PS256"
			When call get_openssl_digest
			The output should equal "sha256"
		End

		It 'returns sha384 for PS384'
			JWT_ALG="PS384"
			When call get_openssl_digest
			The output should equal "sha384"
		End

		It 'returns sha512 for PS512'
			JWT_ALG="PS512"
			When call get_openssl_digest
			The output should equal "sha512"
		End

		It 'returns empty for EdDSA (no digest needed)'
			JWT_ALG="EdDSA"
			When call get_openssl_digest
			The output should equal ""
		End
	End
End
