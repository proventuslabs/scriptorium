# shellcheck shell=bash
# JWT decoding functions

# Convert base64url to standard base64
base64url_to_base64() {
	local input=$1
	local output

	# Replace URL-safe characters with standard base64
	output=${input//-/+}
	output=${output//_/\/}

	# Add padding if needed (base64 requires length % 4 == 0)
	local remainder=$((${#output} % 4))
	case $remainder in
		1) printf '%s===' "$output" ;;
		2) printf '%s==' "$output" ;;
		3) printf '%s=' "$output" ;;
		*) printf '%s' "$output" ;;
	esac
}

# Decode base64url string to raw bytes
base64url_decode() {
	local input=$1
	local b64
	b64=$(base64url_to_base64 "$input")
	printf '%s' "$b64" | base64 -d 2>/dev/null
}

# Split JWT into parts and validate format
# Sets: JWT_HEADER_B64, JWT_PAYLOAD_B64, JWT_SIG_B64
jwt_split() {
	local token=$1

	# Remove whitespace and newlines
	token=${token//[$'\n\r\t ']/}

	# Check for empty token
	if [[ -z $token ]]; then
		echo "jwt: empty token" >&2
		return 2
	fi

	# Check for exactly 2 dots
	local dot_count
	dot_count=$(tr -cd '.' <<<"$token" | wc -c)
	dot_count=${dot_count// /} # trim whitespace from wc
	if [[ $dot_count -ne 2 ]]; then
		echo "jwt: invalid JWT format (expected exactly 2 dots)" >&2
		return 2
	fi

	# Split by dots
	IFS='.' read -r JWT_HEADER_B64 JWT_PAYLOAD_B64 JWT_SIG_B64 <<<"$token"

	# Validate we have all 3 parts
	if [[ -z $JWT_HEADER_B64 || -z $JWT_PAYLOAD_B64 || -z $JWT_SIG_B64 ]]; then
		echo "jwt: invalid JWT format (expected header.payload.signature)" >&2
		return 2
	fi
}

# Decode and validate header JSON
# Sets: JWT_HEADER, JWT_ALG (used by verify.sh)
jwt_decode_header() {
	JWT_HEADER=$(base64url_decode "$JWT_HEADER_B64")

	if [[ -z $JWT_HEADER ]]; then
		echo "jwt: failed to decode header" >&2
		return 2
	fi

	# Basic JSON validation - should start with { and end with }
	if [[ ! $JWT_HEADER =~ ^\{.*\}$ ]]; then
		echo "jwt: invalid header JSON" >&2
		return 2
	fi

	# Extract algorithm - matches "alg":"VALUE" or "alg": "VALUE"
	if [[ $JWT_HEADER =~ \"alg\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
		# shellcheck disable=SC2034 # JWT_ALG used by verify.sh
		JWT_ALG=${BASH_REMATCH[1]}
	else
		echo "jwt: missing 'alg' in header" >&2
		return 2
	fi
}

# Decode and validate payload JSON
# Sets: JWT_PAYLOAD
jwt_decode_payload() {
	JWT_PAYLOAD=$(base64url_decode "$JWT_PAYLOAD_B64")

	if [[ -z $JWT_PAYLOAD ]]; then
		echo "jwt: failed to decode payload" >&2
		return 2
	fi

	# Basic JSON validation
	if [[ ! $JWT_PAYLOAD =~ ^\{.*\}$ ]]; then
		echo "jwt: invalid payload JSON" >&2
		return 2
	fi
}
