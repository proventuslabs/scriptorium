# shellcheck shell=bash disable=SC2034,SC2329

Describe 'decode'
	Include ./decode.sh

	Describe 'base64url_to_base64'
		It 'converts URL-safe characters to standard base64'
			When call base64url_to_base64 "abc-def_ghi"
			The output should equal "abc+def/ghi="
		End

		It 'adds padding for length % 4 == 1'
			When call base64url_to_base64 "abcde"
			The output should equal "abcde==="
		End

		It 'adds padding for length % 4 == 2'
			When call base64url_to_base64 "abcdef"
			The output should equal "abcdef=="
		End

		It 'adds padding for length % 4 == 3'
			When call base64url_to_base64 "abcdefg"
			The output should equal "abcdefg="
		End

		It 'does not add padding when length % 4 == 0'
			When call base64url_to_base64 "abcd"
			The output should equal "abcd"
		End
	End

	Describe 'base64url_decode'
		It 'decodes base64url to raw bytes'
			# "hello" in base64url is "aGVsbG8"
			When call base64url_decode "aGVsbG8"
			The output should equal "hello"
		End

		It 'handles URL-safe characters'
			# Test with characters that differ between base64 and base64url
			When call base64url_decode "PDw_Pz4-"
			The output should equal "<<??>>"
		End
	End

	Describe 'jwt_split'
		It 'splits valid JWT into 3 parts'
			When call jwt_split "header.payload.signature"
			The status should be success
			The variable JWT_HEADER_B64 should equal "header"
			The variable JWT_PAYLOAD_B64 should equal "payload"
			The variable JWT_SIG_B64 should equal "signature"
		End

		It 'rejects empty token'
			When call jwt_split ""
			The status should equal 2
			The stderr should include "empty token"
		End

		It 'rejects token with only 2 parts'
			When call jwt_split "header.payload"
			The status should equal 2
			The stderr should include "invalid JWT format"
		End

		It 'rejects token with 4 parts'
			When call jwt_split "a.b.c.d"
			The status should equal 2
			The stderr should include "invalid JWT format"
		End

		It 'strips whitespace and newlines'
			When call jwt_split $'  header.payload.signature\n'
			The status should be success
			The variable JWT_HEADER_B64 should equal "header"
		End
	End

	Describe 'jwt_decode_header'
		setup() {
			JWT_HEADER_B64="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
		}
		BeforeEach 'setup'

		It 'decodes header JSON and extracts algorithm'
			When call jwt_decode_header
			The status should be success
			The variable JWT_ALG should equal "HS256"
		End

		It 'rejects invalid base64'
			JWT_HEADER_B64="!!invalid!!"
			When call jwt_decode_header
			The status should equal 2
			The stderr should include "failed to decode header"
		End

		It 'rejects non-JSON header'
			# "not json" in base64url
			JWT_HEADER_B64="bm90IGpzb24"
			When call jwt_decode_header
			The status should equal 2
			The stderr should include "invalid header JSON"
		End

		It 'rejects header without alg'
			# {"typ":"JWT"} in base64url
			JWT_HEADER_B64="eyJ0eXAiOiJKV1QifQ"
			When call jwt_decode_header
			The status should equal 2
			The stderr should include "missing 'alg'"
		End
	End

	Describe 'jwt_decode_payload'
		setup() {
			JWT_PAYLOAD_B64="eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0"
		}
		BeforeEach 'setup'

		It 'decodes payload JSON'
			When call jwt_decode_payload
			The status should be success
			The variable JWT_PAYLOAD should include '"sub":"1234567890"'
		End

		It 'rejects invalid base64'
			JWT_PAYLOAD_B64="!!invalid!!"
			When call jwt_decode_payload
			The status should equal 2
			The stderr should include "failed to decode payload"
		End

		It 'rejects non-JSON payload'
			# "not json" in base64url
			JWT_PAYLOAD_B64="bm90IGpzb24"
			When call jwt_decode_payload
			The status should equal 2
			The stderr should include "invalid payload JSON"
		End
	End
End
