# shellcheck shell=bash
# JWT verification functions

# Warning helper
# @start-kcov-exclude - only called when version warnings trigger (OpenSSL < 3.x)
jwt_warn() {
	[[ -n "${JWT_QUIET:-}" ]] && return 0
	echo "jwt: warning: $1" >&2
	return 0
}
# @end-kcov-exclude

# Check required dependencies are available
# $1: algorithm (optional) - if ECDSA, also checks for xxd
check_dependencies() {
	local alg=${1:-}

	# @start-kcov-exclude - can't mock PATH to test missing dependencies
	if ! command -v openssl &>/dev/null; then
		echo "jwt: error: openssl not found" >&2
		return 1
	fi

	# xxd required for ECDSA signature conversion
	case $alg in
		ES256 | ES384 | ES512)
			if ! command -v xxd &>/dev/null; then
				echo "jwt: error: xxd not found (required for ECDSA)" >&2
				return 1
			fi
			;;
	esac
	# @end-kcov-exclude
}

# Get OpenSSL major version number
# Returns 0 for LibreSSL (not supported for PS/EdDSA)
get_openssl_major_version() {
	local version_string version
	version_string=$(openssl version 2>/dev/null)
	# LibreSSL returns "LibreSSL x.y.z" - not compatible with PS/EdDSA
	# @start-kcov-exclude - only triggers on LibreSSL systems
	if [[ "$version_string" == LibreSSL* ]]; then
		echo "0"
		return
	fi
	# @end-kcov-exclude
	version=$(echo "$version_string" | awk '{print $2}')
	echo "${version%%.*}"
}

# Check if OpenSSL version supports an algorithm
# Returns 0 if supported, 8 if not
check_algorithm_support() {
	local alg=$1
	local major_version
	major_version=$(get_openssl_major_version)

	case $alg in
		PS256 | PS384 | PS512 | EdDSA)
			# These require OpenSSL 3.x
			# @start-kcov-exclude - only triggers on OpenSSL < 3.x or LibreSSL
			if [[ "$major_version" -lt 3 ]]; then
				jwt_warn "algorithm '$alg' requires OpenSSL 3.x (found: $(openssl version))"
				return 1
			fi
			# @end-kcov-exclude
			;;
	esac
	return 0
}

# Get OpenSSL digest name from JWT algorithm
# Uses: JWT_ALG
# Returns empty string for EdDSA (no separate digest step)
get_openssl_digest() {
	case $JWT_ALG in
		HS256 | RS256 | ES256 | PS256) echo "sha256" ;;
		HS384 | RS384 | ES384 | PS384) echo "sha384" ;;
		HS512 | RS512 | ES512 | PS512) echo "sha512" ;;
		EdDSA) echo "" ;; # @kcov-ignore - EdDSA requires OpenSSL 3.x
		# @start-kcov-exclude - verify_signature validates algorithm first
		*)
			echo "jwt: error: unsupported algorithm '$JWT_ALG'" >&2
			return 1
			;;
			# @end-kcov-exclude
	esac
}

# Verify HMAC signature (HS256, HS384, HS512)
# Uses: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64, JWT_ALG
verify_hmac() {
	local secret=$1
	local digest expected_sig actual_sig

	digest=$(get_openssl_digest) || return $?

	# Compute expected signature: HMAC(header.payload, secret)
	local signing_input="${JWT_HEADER_B64}.${JWT_PAYLOAD_B64}"
	expected_sig=$(printf '%s' "$signing_input" | openssl dgst -"$digest" -hmac "$secret" -binary | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')

	# Decode actual signature from token (normalize by removing padding)
	actual_sig=${JWT_SIG_B64//=/}

	if [[ "$expected_sig" != "$actual_sig" ]]; then
		echo "jwt: error: signature verification failed" >&2
		return 1
	fi
}

# Verify RSA signature (RS256, RS384, RS512)
# Uses: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64, JWT_ALG
# $1: PEM public key content
verify_rsa() {
	local key=$1
	local digest sig_file key_file result=0

	digest=$(get_openssl_digest) || return $?

	# Create temp files for signature and key
	# Note: manual cleanup instead of trap - kcov triggers RETURN trap prematurely
	sig_file=$(mktemp)
	key_file=$(mktemp)

	# Decode signature and write to temp file
	base64url_decode "$JWT_SIG_B64" >"$sig_file"
	printf '%s\n' "$key" >"$key_file"

	# Verify signature
	local signing_input="${JWT_HEADER_B64}.${JWT_PAYLOAD_B64}"
	if ! printf '%s' "$signing_input" | openssl dgst -"$digest" -verify "$key_file" -signature "$sig_file" &>/dev/null; then
		echo "jwt: error: signature verification failed" >&2
		result=1
	fi

	rm -f "$sig_file" "$key_file"
	return $result
}

# Convert JWT ECDSA signature (R||S) to DER format for OpenSSL
# ECDSA signatures in JWT are raw R||S concatenation
# OpenSSL expects DER-encoded SEQUENCE { INTEGER R, INTEGER S }
jwt_sig_to_der() {
	local sig_hex=$1
	local key_bits=$2
	local r_len r_hex s_hex

	# R and S are each half the signature
	case $key_bits in
		256) r_len=64 ;;  # 32 bytes = 64 hex chars
		384) r_len=96 ;;  # 48 bytes = 96 hex chars
		512) r_len=132 ;; # 66 bytes = 132 hex chars (P-521)
		# @start-kcov-exclude - only called with valid key_bits from verify_ecdsa
		*) return 1 ;;
			# @end-kcov-exclude
	esac

	r_hex=${sig_hex:0:$r_len}
	s_hex=${sig_hex:$r_len:$r_len}

	# Remove leading zeros but ensure positive (add 00 if high bit set)
	r_hex=$(echo "$r_hex" | sed 's/^0*//')
	s_hex=$(echo "$s_hex" | sed 's/^0*//')

	# Ensure even length
	[[ $((${#r_hex} % 2)) -eq 1 ]] && r_hex="0$r_hex"
	[[ $((${#s_hex} % 2)) -eq 1 ]] && s_hex="0$s_hex"

	# Add leading 00 if high bit is set (to keep positive)
	[[ ${r_hex:0:1} =~ [89a-fA-F] ]] && r_hex="00$r_hex"
	[[ ${s_hex:0:1} =~ [89a-fA-F] ]] && s_hex="00$s_hex"

	local r_bytes=$((${#r_hex} / 2))
	local s_bytes=$((${#s_hex} / 2))

	# Build DER: 30 <total_len> 02 <r_len> <r> 02 <s_len> <s>
	# Note: For ES512 (P-521), total_len may exceed 127, requiring long-form length
	local total_len=$((2 + r_bytes + 2 + s_bytes))
	if [[ $total_len -gt 127 ]]; then
		# Long form: 0x81 <len> for lengths 128-255
		printf '3081%02x02%02x%s02%02x%s' "$total_len" "$r_bytes" "$r_hex" "$s_bytes" "$s_hex"
	else
		printf '30%02x02%02x%s02%02x%s' "$total_len" "$r_bytes" "$r_hex" "$s_bytes" "$s_hex"
	fi
}

# Verify ECDSA signature (ES256, ES384, ES512)
# Uses: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64, JWT_ALG
# $1: PEM public key content
verify_ecdsa() {
	local key=$1
	local digest sig_file key_file key_bits result=0

	digest=$(get_openssl_digest) || return $?

	# Determine key size from algorithm
	case $JWT_ALG in
		ES256) key_bits=256 ;;
		ES384) key_bits=384 ;;
		ES512) key_bits=512 ;;
	esac

	# Create temp files for DER signature and key
	# Note: manual cleanup instead of trap - kcov triggers RETURN trap prematurely
	sig_file=$(mktemp)
	key_file=$(mktemp)

	# Decode signature to hex, convert to DER
	local sig_hex der_hex
	sig_hex=$(base64url_decode "$JWT_SIG_B64" | xxd -p | tr -d '\n')
	# @start-kcov-exclude - jwt_sig_to_der only fails with invalid key_bits (defensive)
	der_hex=$(jwt_sig_to_der "$sig_hex" "$key_bits") || {
		echo "jwt: error: failed to convert ECDSA signature" >&2
		rm -f "$sig_file" "$key_file"
		return 1
	}
	# @end-kcov-exclude

	# Write DER signature as binary and key to temp files
	echo "$der_hex" | xxd -r -p >"$sig_file"
	printf '%s\n' "$key" >"$key_file"

	# Verify signature
	local signing_input="${JWT_HEADER_B64}.${JWT_PAYLOAD_B64}"
	if ! printf '%s' "$signing_input" | openssl dgst -"$digest" -verify "$key_file" -signature "$sig_file" &>/dev/null; then
		echo "jwt: error: signature verification failed" >&2
		result=1
	fi

	rm -f "$sig_file" "$key_file"
	return $result
}

# Verify RSA-PSS signature (PS256, PS384, PS512)
# Uses: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64, JWT_ALG
# Requires OpenSSL 3.x
# $1: PEM public key content
verify_pss() {
	local key=$1
	local digest sig_file key_file result=0

	check_algorithm_support "$JWT_ALG" || return $?
	digest=$(get_openssl_digest) || return $?

	# Create temp files for signature and key
	# Note: manual cleanup instead of trap - kcov triggers RETURN trap prematurely
	sig_file=$(mktemp)
	key_file=$(mktemp)

	# Decode signature and write to temp file
	base64url_decode "$JWT_SIG_B64" >"$sig_file"
	printf '%s\n' "$key" >"$key_file"

	# Verify with RSA-PSS padding
	local signing_input="${JWT_HEADER_B64}.${JWT_PAYLOAD_B64}"
	if ! printf '%s' "$signing_input" | openssl dgst -"$digest" -verify "$key_file" -signature "$sig_file" -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 &>/dev/null; then
		echo "jwt: error: signature verification failed" >&2
		result=1
	fi

	rm -f "$sig_file" "$key_file"
	return $result
}

# Verify EdDSA signature (Ed25519)
# Uses: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64
# Requires OpenSSL 3.x
# $1: PEM public key content
verify_eddsa() {
	local key=$1
	local sig_file input_file key_file result=0

	check_algorithm_support "EdDSA" || return $?

	# Create temp files for signature, input, and key
	# Note: manual cleanup instead of trap - kcov triggers RETURN trap prematurely
	sig_file=$(mktemp)
	input_file=$(mktemp)
	key_file=$(mktemp)

	# Decode signature and write to temp file
	base64url_decode "$JWT_SIG_B64" >"$sig_file"

	# Write signing input to temp file (Ed25519 needs -rawin with file input)
	local signing_input="${JWT_HEADER_B64}.${JWT_PAYLOAD_B64}"
	printf '%s' "$signing_input" >"$input_file"
	printf '%s\n' "$key" >"$key_file"

	# Verify with pkeyutl
	if ! openssl pkeyutl -verify -pubin -inkey "$key_file" -rawin -in "$input_file" -sigfile "$sig_file" &>/dev/null; then
		echo "jwt: error: signature verification failed" >&2
		result=1
	fi

	rm -f "$sig_file" "$input_file" "$key_file"
	return $result
}

# Main verification dispatcher
# Uses: JWT_ALG, and calls appropriate verify_* function
# $1: secret string for HMAC, or PEM public key content for asymmetric
verify_signature() {
	local key=$1

	check_dependencies "$JWT_ALG" || return $?

	case $JWT_ALG in
		HS256 | HS384 | HS512)
			verify_hmac "$key"
			;;
		RS256 | RS384 | RS512)
			verify_rsa "$key"
			;;
		ES256 | ES384 | ES512)
			verify_ecdsa "$key"
			;;
		PS256 | PS384 | PS512)
			verify_pss "$key"
			;;
		EdDSA)
			verify_eddsa "$key"
			;;
		# @start-kcov-exclude - jwt_decode_header validates alg exists; defensive only
		*)
			echo "jwt: error: unsupported algorithm '$JWT_ALG'" >&2
			return 1
			;;
			# @end-kcov-exclude
	esac
}
