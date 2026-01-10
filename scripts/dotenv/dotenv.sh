# shellcheck shell=bash

# Core dotenv functionality - load .env files and run commands

# @bundle source
. ./parser.sh

# Warning helper
dotenv_warn() {
	[[ -n "${DOTENV_QUIET:-}" ]] && return 0
	echo "dotenv: warning: $1" >&2
	return 0
}

# Load .env files and execute command using env(1)
# Usage: dotenv_exec <num_files> file... command [args...]
# Globals: DOTENV_STRICT, DOTENV_QUIET, DOTENV_EXEC
dotenv_exec() {
	local num_files=$1
	shift

	local -a env_files=("${@:1:num_files}")
	shift "$num_files"

	local -a env_args=()
	declare -A env_vars=()

	# Callback for parser
	# shellcheck disable=SC2329  # Invoked indirectly by parse_env
	_dotenv_callback() {
		env_vars[$1]=$2
	}

	# Parse each file
	for file in "${env_files[@]}"; do
		if [[ ! -f "$file" ]]; then
			dotenv_warn "file not found: $file"
			[[ -n "${DOTENV_STRICT:-}" ]] && return 1
			continue
		fi
		if ! parse_env _dotenv_callback <"$file"; then
			[[ -n "${DOTENV_STRICT:-}" ]] && return 1
		fi
	done

	# Build env args (skip vars already in environment)
	for key in "${!env_vars[@]}"; do
		[[ -z "${!key+x}" ]] && env_args+=("$key=${env_vars[$key]}")
	done

	# Execute with env
	if [[ -n "${DOTENV_EXEC:-}" ]]; then
		exec env "${env_args[@]}" "$@"
	else
		env "${env_args[@]}" "$@"
	fi
}
