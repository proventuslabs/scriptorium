# getargs - powerful argument parser with support for flags and options with POSIX and GNU-style compliance

typeset -grA GETARGS_ERRORS=(
	HELP_REQUESTED 1
	MISSING_ARGUMENTS 2
	MISSING_VALUE 3
)

getargs() {
	local func_name=$1
	local parsed_args_name=$2
	local positional_args_name=$3
	local positional_args_min_count=$4
	local options_with_args_name=$5
	shift 5

	local -A local_parsed_args=()
	local -a local_positional_args=()
	local options_ended=false  # Track if we've encountered `--` for POSIX compliance

	# Check if options_with_args was provided
	local has_options_spec=false
	if [[ -n "$options_with_args_name" ]]; then
		# Test if the variable exists and is an associative array
		if (( ${(P)+options_with_args_name} )); then
			has_options_spec=true
		fi
	fi

	local bail_missing_value() {
		local key=$1
		echo "Error: Option --$key requires an argument" >&2
		echo "Try: $func_name --help" >&2
		return ${GETARGS_ERRORS[MISSING_VALUE]}
	}

	local bail_missing_arguments() {
		echo "Error: $func_name requires at least $positional_args_min_count argument(s)" >&2
		echo "Try: $func_name --help" >&2
		return ${GETARGS_ERRORS[MISSING_ARGUMENTS]}
	}

	local bail_help_requested() {
		man "$func_name"
		return ${GETARGS_ERRORS[HELP_REQUESTED]}
	}

	while [[ $# -gt 0 ]]; do
		# Short circuit for `--` delimiter
		if [[ "$1" == "--" ]]; then
			options_ended=true
			shift
			continue
		fi

		# If we've seen `--`, treat everything as positional arguments for POSIX compliance
		# Short circuit for `-` (positional argument)
		if [[ "$1" == "-" || $options_ended == true ]]; then
			local_positional_args+=("$1")
			shift
			continue
		fi

		case $1 in
			-h|--help)
				bail_help_requested "$func_name"
				return $?
				;;
			--*=*)
				local key="${1%%=*}"
				local value="${1#*=}"
				key="${key#--}"

				# Always create/append to array for --key=value format
				if [[ -n "${local_parsed_args[$key]:-}" ]]; then
					# Key already exists, append to array
					local_parsed_args[$key]="${local_parsed_args[$key]} $value"
				else
					# New key, start array
					local_parsed_args[$key]="$value"
				fi
				shift
				;;
			-*=*)
				local key="${1%%=*}"
				local value="${1#*=}"
				key="${key#-}"

				# Handle short form with equals (e.g., -e=value)
				if [[ -n "${local_parsed_args[$key]:-}" ]]; then
					# Key already exists, append to array
					local_parsed_args[$key]="${local_parsed_args[$key]} $value"
				else
					# New key, start array
					local_parsed_args[$key]="$value"
				fi
				shift
				;;
			--*)
				local key="${1#--}"

				# Check if this option expects an argument
				local expects_arg=false
				if [[ $has_options_spec == true ]]; then
					local spec_key="${options_with_args_name}[$key]"
					if [[ -n "${(P)spec_key:-}" ]]; then
						expects_arg=true
					fi
				fi

				if [[ $expects_arg == true ]]; then
					if [[ $# -gt 1 && ! "$2" =~ ^-[a-zA-Z] && ! "$2" =~ ^--[a-zA-Z] ]]; then
						# Space-separated long option with argument
						shift
						local value="$1"
						if [[ -n "${local_parsed_args[$key]:-}" ]]; then
							local_parsed_args[$key]="${local_parsed_args[$key]} $value"
						else
							local_parsed_args[$key]="$value"
						fi
					else
						# Expected argument but none found
						bail_missing_value "$key"
						return $?
					fi
				else
					# Flag option
					local_parsed_args[$key]=true
				fi
				shift
				;;
			-*)
				local opts="${1#-}"
				local i=1

				# Process each character in the option string
				while [[ $i -le ${#opts} ]]; do
					# option character (e.g. `-eyu` at i=1 -> `e`)
					local opt="${opts[i]}"

					# Check if this option expects an argument
					local expects_arg=false
					if [[ $has_options_spec == true ]]; then
						local spec_key="${options_with_args_name}[$opt]"
						if [[ -n "${(P)spec_key:-}" ]]; then
							expects_arg=true
						fi
					fi

					# Check if this is the last character and if it expects an argument
					if [[ $i -eq ${#opts} && $expects_arg == true ]]; then
						if [[ $# -gt 1 && ! "$2" =~ ^-[a-zA-Z] && ! "$2" =~ ^--[a-zA-Z] ]]; then
							# Space-separated short option with argument (last char in group)
							shift
							local value="$1"
							if [[ -n "${local_parsed_args[$opt]:-}" ]]; then
								local_parsed_args[$opt]="${local_parsed_args[$opt]} $value"
							else
								local_parsed_args[$opt]="$value"
							fi
							break
						else
							# Expected argument but none found
							bail_missing_value "$opt"
							return $?
						fi
					else
						# Flag option
						local_parsed_args[$opt]=true
					fi

					((i++))
				done
				shift
				;;
			*)
				local_positional_args+=("$1")
				shift
				;;
		esac
	done

	local array_size=${#local_positional_args}
	if [[ $positional_args_min_count -gt 0 && $array_size -lt $positional_args_min_count ]]; then
		bail_missing_arguments
		return $?
	fi

	# Convert associative array to key-value pairs
	local -a kv_pairs=()
	local key_to_set
	for key_to_set in "${(@k)local_parsed_args}"; do
		local value="${local_parsed_args[$key_to_set]}"
		kv_pairs+=("$key_to_set" "$value")
	done

	# Use set -A to assign the associative array
	if [[ ${#kv_pairs[@]} -gt 0 ]]; then
		set -A "$parsed_args_name" "${kv_pairs[@]}"
	fi

	# Use set -A to assign positional array to caller
	set -A "$positional_args_name" "${local_positional_args[@]}"

	return 0
}
