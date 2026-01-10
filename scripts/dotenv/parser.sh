# shellcheck shell=bash
# shellcheck disable=SC1003  # Intentional backslash comparison

# Parse .env content from stdin, call callback for each key=value
# Usage: parse_env <callback_fn>
# Callback receives: callback_fn "KEY" "value"
parse_env() {
	local callback=$1
	local line key value
	local in_single_quote=false
	local in_double_quote=false
	local accumulated_value=""
	local current_key=""

	while IFS= read -r line || [[ -n "$line" ]]; do
		# If we're in a multiline quoted value, append to it
		if $in_single_quote || $in_double_quote; then
			accumulated_value+=$'\n'"$line"

			if $in_single_quote; then
				if _ends_single_quote "$accumulated_value"; then
					value=$(_extract_single_quoted "$accumulated_value")
					"$callback" "$current_key" "$value"
					in_single_quote=false
					current_key=""
					accumulated_value=""
				fi
			elif $in_double_quote; then
				if _ends_double_quote "$accumulated_value"; then
					value=$(_extract_double_quoted "$accumulated_value")
					value=$(_process_escapes "$value")
					value=$(_substitute_vars "$value")
					"$callback" "$current_key" "$value"
					in_double_quote=false
					current_key=""
					accumulated_value=""
				fi
			fi
			continue
		fi

		# Skip blank lines
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# Skip comment lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		# Parse KEY=value
		if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)= ]]; then
			key="${BASH_REMATCH[1]}"
			value="${line#*=}"

			# Check for quoted values
			if [[ "$value" =~ ^\'(.*)\'([[:space:]]*(#.*)?)?$ ]]; then
				# Complete single-quoted value on one line
				value="${BASH_REMATCH[1]}"
				# Handle escaped single quotes (end quote, escaped quote, start quote)
				value="${value//\'\\\'\'/\'}"
				"$callback" "$key" "$value"
			elif [[ "$value" =~ ^\' ]]; then
				# Start of multiline single-quoted value
				in_single_quote=true
				current_key="$key"
				accumulated_value="$value"
			elif [[ "$value" =~ ^\"(.*)\"([[:space:]]*(#.*)?)?$ ]]; then
				# Complete double-quoted value on one line
				value="${BASH_REMATCH[1]}"
				value=$(_process_escapes "$value")
				value=$(_substitute_vars "$value")
				"$callback" "$key" "$value"
			elif [[ "$value" =~ ^\" ]]; then
				# Start of multiline double-quoted value
				in_double_quote=true
				current_key="$key"
				accumulated_value="$value"
			else
				# Unquoted value - trim whitespace, handle end-of-line comments
				value=$(_parse_unquoted "$value")
				"$callback" "$key" "$value"
			fi
		elif [[ "$line" =~ ^[0-9] ]]; then
			echo "dotenv: warning: invalid key name starting with digit: ${line%%=*}" >&2
		fi
	done

	# Handle unclosed quotes
	if $in_single_quote; then
		echo "dotenv: warning: unclosed single quote for key: $current_key" >&2
		# Still emit what we have
		value="${accumulated_value#\'}"
		"$callback" "$current_key" "$value"
	elif $in_double_quote; then
		echo "dotenv: warning: unclosed double quote for key: $current_key" >&2
		value="${accumulated_value#\"}"
		value=$(_process_escapes "$value")
		value=$(_substitute_vars "$value")
		"$callback" "$current_key" "$value"
	fi

	return 0
}

# Check if string ends with unescaped single quote
_ends_single_quote() {
	local s=$1
	# Single quotes: only '\'' escapes a quote (end, escape, begin pattern)
	# For simplicity, check if it ends with ' and count quotes
	[[ "$s" =~ \'([[:space:]]*(#.*)?)?$ ]] && return 0
	return 1
}

# Check if string ends with unescaped double quote
_ends_double_quote() {
	local s=$1
	local len=${#s}
	local i=$((len - 1))

	# Find the last double quote, skipping trailing comment
	while [[ $i -ge 0 ]]; do
		local char="${s:$i:1}"
		if [[ "$char" == '"' ]]; then
			# Check if escaped
			local backslashes=0
			local j=$((i - 1))
			while [[ $j -ge 0 && "${s:$j:1}" == '\' ]]; do
				((backslashes++))
				((j--))
			done
			# Even number of backslashes = unescaped quote
			if ((backslashes % 2 == 0)); then
				return 0
			fi
		fi
		((i--))
	done
	return 1
}

# Extract content from single-quoted string
_extract_single_quoted() {
	local s=$1
	# Remove leading quote
	s="${s#\'}"
	# Remove trailing quote and any comment
	s="${s%\'*}"
	# Handle '\'' escape pattern
	s="${s//\'\\\'\'/\'}"
	printf '%s' "$s"
}

# Extract content from double-quoted string
_extract_double_quoted() {
	local s=$1
	# Remove leading quote
	s="${s#\"}"
	# Find the closing quote (handling escapes)
	local result=""
	local i=0
	local len=${#s}

	while [[ $i -lt $len ]]; do
		local char="${s:$i:1}"
		if [[ "$char" == '\' && $((i + 1)) -lt $len ]]; then
			local next="${s:$((i + 1)):1}"
			result+="$char$next"
			((i += 2))
		elif [[ "$char" == '"' ]]; then
			break
		else
			result+="$char"
			((i++))
		fi
	done

	printf '%s' "$result"
}

# Parse unquoted value - trim whitespace, handle end-of-line comments
_parse_unquoted() {
	local value=$1

	# Handle end-of-line comments (# preceded by space)
	if [[ "$value" =~ ^([^#]*[^[:space:]])[[:space:]]+#.*$ ]]; then
		value="${BASH_REMATCH[1]}"
	elif [[ "$value" =~ ^([^#]*)[[:space:]]*#.*$ ]]; then
		value="${BASH_REMATCH[1]}"
	fi

	# Trim leading whitespace
	value="${value#"${value%%[![:space:]]*}"}"
	# Trim trailing whitespace
	value="${value%"${value##*[![:space:]]}"}"

	printf '%s' "$value"
}

# Process escape sequences in double-quoted values
_process_escapes() {
	local value=$1
	local result=""
	local i=0
	local len=${#value}

	while [[ $i -lt $len ]]; do
		local char="${value:$i:1}"
		if [[ "$char" == '\' && $((i + 1)) -lt $len ]]; then
			local next="${value:$((i + 1)):1}"
			case "$next" in
				n) result+=$'\n' ;;
				t) result+=$'\t' ;;
				r) result+=$'\r' ;;
				f) result+=$'\f' ;;
				b) result+=$'\b' ;;
				v) result+=$'\v' ;;
				\\) result+='\' ;;
				'"') result+='"' ;;
				*) result+="\\$next" ;;
			esac
			((i += 2))
		else
			result+="$char"
			((i++))
		fi
	done

	printf '%s' "$result"
}

# Perform variable substitution in double-quoted values
_substitute_vars() {
	local value=$1
	local result=""
	local i=0
	local len=${#value}

	while [[ $i -lt $len ]]; do
		local char="${value:$i:1}"
		if [[ "$char" == '$' && $((i + 1)) -lt $len ]]; then
			local next="${value:$((i + 1)):1}"
			if [[ "$next" == '{' ]]; then
				# ${VAR} or ${VAR:-default} syntax
				local rest="${value:$((i + 2))}"
				if [[ "$rest" =~ ^([a-zA-Z_][a-zA-Z0-9_]*):-([^}]*)\}(.*)$ ]]; then
					local varname="${BASH_REMATCH[1]}"
					local default="${BASH_REMATCH[2]}"
					local varvalue="${!varname:-}"
					if [[ -z "$varvalue" ]]; then
						result+="$default"
					else
						result+="$varvalue"
					fi
					((i += 2 + ${#varname} + 2 + ${#default} + 1))
				elif [[ "$rest" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\}(.*)$ ]]; then
					local varname="${BASH_REMATCH[1]}"
					local varvalue="${!varname:-}"
					result+="$varvalue"
					((i += 2 + ${#varname} + 1))
				else
					result+='$'
					((i++))
				fi
			elif [[ "$next" =~ ^[a-zA-Z_] ]]; then
				# $VAR syntax
				local rest="${value:$((i + 1))}"
				if [[ "$rest" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)(.*)$ ]]; then
					local varname="${BASH_REMATCH[1]}"
					local varvalue="${!varname:-}"
					result+="$varvalue"
					((i += 1 + ${#varname}))
				else
					result+='$'
					((i++))
				fi
			else
				result+='$'
				((i++))
			fi
		else
			result+="$char"
			((i++))
		fi
	done

	printf '%s' "$result"
}
