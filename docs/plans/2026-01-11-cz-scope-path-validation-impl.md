# cz Scope-to-Path Validation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add scope-to-path validation to cz, replacing the pipe-delimited config with INI format.

**Architecture:** New INI parser replaces existing pipe parser. New `path_validator.sh` module handles glob matching. Settings stored in global variables. Lint and hook commands gain file validation.

**Tech Stack:** Bash 4+, ShellSpec tests, getoptions CLI parsing

---

## Task 1: INI Config Parser

**Files:**
- Create: `scripts/cz/ini_parser.sh`
- Create: `scripts/cz/ini_parser_spec.sh`

**Step 1: Write failing test for section parsing**

```bash
# scripts/cz/ini_parser_spec.sh
# shellcheck shell=bash

Describe 'parse_ini'
	Include ./ini_parser.sh

	It 'parses empty input'
		When call parse_ini
		The status should be success
	End

	It 'ignores comments and blank lines'
		Data
			#|# comment
			#|
			#|  # indented comment
		End
		When call parse_ini
		The status should be success
	End

	It 'parses settings section'
		Data
			#|[settings]
			#|strict = true
			#|multi-scope = false
		End
		When call parse_ini
		The status should be success
		The variable INI_SETTINGS_strict should equal "true"
		The variable INI_SETTINGS_multi_scope should equal "false"
	End

	It 'parses scopes section'
		Data
			#|[scopes]
			#|cz = scripts/cz/**
			#|ci = .github/**
		End
		When call parse_ini
		The status should be success
		The variable INI_SCOPES_cz should equal "scripts/cz/**"
		The variable INI_SCOPES_ci should equal ".github/**"
	End

	It 'parses types section'
		Data
			#|[types]
			#|feat = A new feature
			#|fix = A bug fix
		End
		When call parse_ini
		The status should be success
		The variable INI_TYPES_feat should equal "A new feature"
		The variable INI_TYPES_fix should equal "A bug fix"
	End

	It 'parses full config'
		Data
			#|[settings]
			#|strict = true
			#|
			#|[scopes]
			#|api = src/api/**
			#|
			#|[types]
			#|feat = A new feature
		End
		When call parse_ini
		The status should be success
		The variable INI_SETTINGS_strict should equal "true"
		The variable INI_SCOPES_api should equal "src/api/**"
		The variable INI_TYPES_feat should equal "A new feature"
	End

	It 'handles values with spaces'
		Data
			#|[types]
			#|feat = A new feature for users
		End
		When call parse_ini
		The status should be success
		The variable INI_TYPES_feat should equal "A new feature for users"
	End

	It 'handles multi-value scopes'
		Data
			#|[scopes]
			#|nix = flake.nix, flake.lock, */default.nix
		End
		When call parse_ini
		The status should be success
		The variable INI_SCOPES_nix should equal "flake.nix, flake.lock, */default.nix"
	End
End
```

**Step 2: Run test to verify it fails**

Run: `make test NAME=cz`
Expected: FAIL - ini_parser.sh not found

**Step 3: Write INI parser implementation**

```bash
# scripts/cz/ini_parser.sh
# shellcheck shell=bash

# Parse INI-style .gitcommitizen configuration from stdin
# Sets variables: INI_SETTINGS_*, INI_SCOPES_*, INI_TYPES_*
# Also sets arrays: INI_SCOPE_NAMES, INI_TYPE_NAMES
parse_ini() {
	# Clear previous state
	unset "${!INI_SETTINGS_@}" "${!INI_SCOPES_@}" "${!INI_TYPES_@}"
	INI_SCOPE_NAMES=()
	INI_TYPE_NAMES=()

	[[ -t 0 ]] && return 0

	local section="" line key value

	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and blank lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# Section header
		if [[ "$line" =~ ^\[([a-z]+)\]$ ]]; then
			section="${BASH_REMATCH[1]}"
			continue
		fi

		# Key = value
		if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"

			# Trim whitespace
			key="${key#"${key%%[![:space:]]*}"}"
			key="${key%"${key##*[![:space:]]}"}"
			value="${value#"${value%%[![:space:]]*}"}"
			value="${value%"${value##*[![:space:]]}"}"

			# Normalize key (replace - with _)
			local norm_key="${key//-/_}"

			case "$section" in
				settings)
					declare -g "INI_SETTINGS_$norm_key=$value"
					;;
				scopes)
					declare -g "INI_SCOPES_$key=$value"
					INI_SCOPE_NAMES+=("$key")
					;;
				types)
					declare -g "INI_TYPES_$key=$value"
					INI_TYPE_NAMES+=("$key")
					;;
			esac
		fi
	done
}

# Get setting value with default
# Usage: get_setting <key> [default]
get_setting() {
	local key="${1//-/_}"
	local default="${2:-}"
	local var="INI_SETTINGS_$key"
	echo "${!var:-$default}"
}

# Check if scope exists
# Usage: scope_exists <name>
scope_exists() {
	local var="INI_SCOPES_$1"
	[[ -n "${!var+x}" ]]
}

# Get scope patterns
# Usage: get_scope_patterns <name>
get_scope_patterns() {
	local var="INI_SCOPES_$1"
	echo "${!var:-}"
}

# Check if type exists
# Usage: type_exists <name>
type_exists() {
	local var="INI_TYPES_$1"
	[[ -n "${!var+x}" ]]
}
```

**Step 4: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/cz/ini_parser.sh scripts/cz/ini_parser_spec.sh
git commit -m "feat(cz): add INI config parser"
```

---

## Task 2: Path Validator Module

**Files:**
- Create: `scripts/cz/path_validator.sh`
- Create: `scripts/cz/path_validator_spec.sh`

**Step 1: Write failing tests for glob matching**

```bash
# scripts/cz/path_validator_spec.sh
# shellcheck shell=bash

Describe 'path_validator'
	Include ./ini_parser.sh
	Include ./path_validator.sh

	Describe 'file_matches_pattern'
		It 'matches exact file'
			When call file_matches_pattern "README.md" "README.md"
			The status should be success
		End

		It 'matches glob star'
			When call file_matches_pattern "src/main.sh" "src/*.sh"
			The status should be success
		End

		It 'matches glob double star'
			When call file_matches_pattern "scripts/cz/main.sh" "scripts/cz/**"
			The status should be success
		End

		It 'matches nested double star'
			When call file_matches_pattern "scripts/cz/sub/deep/file.sh" "scripts/cz/**"
			The status should be success
		End

		It 'rejects non-matching path'
			When call file_matches_pattern "scripts/dotenv/main.sh" "scripts/cz/**"
			The status should be failure
		End

		It 'matches wildcard in path'
			When call file_matches_pattern "scripts/cz/default.nix" "*/default.nix"
			The status should be success
		End
	End

	Describe 'file_matches_scope'
		BeforeEach 'parse_ini <<< "[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**
nix = flake.nix, flake.lock, */default.nix"'

		It 'matches single pattern scope'
			When call file_matches_scope "scripts/cz/main.sh" "cz"
			The status should be success
		End

		It 'rejects wrong scope'
			When call file_matches_scope "scripts/dotenv/main.sh" "cz"
			The status should be failure
		End

		It 'matches multi-pattern scope'
			When call file_matches_scope "flake.nix" "nix"
			The status should be success
		End

		It 'matches any pattern in multi-pattern scope'
			When call file_matches_scope "scripts/cz/default.nix" "nix"
			The status should be success
		End

		It 'handles wildcard scope'
			parse_ini <<< "[scopes]
* = *"
			When call file_matches_scope "any/file.txt" "*"
			The status should be success
		End
	End

	Describe 'find_matching_scope'
		BeforeEach 'parse_ini <<< "[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**"'

		It 'finds matching scope'
			When call find_matching_scope "scripts/cz/main.sh"
			The status should be success
			The output should equal "cz"
		End

		It 'returns empty for no match'
			When call find_matching_scope "README.md"
			The status should be failure
			The output should equal ""
		End
	End

	Describe 'validate_files_against_scope'
		BeforeEach 'parse_ini <<< "[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**"'

		It 'passes when all files match scope'
			When call validate_files_against_scope "cz" "scripts/cz/main.sh" "scripts/cz/opts.sh"
			The status should be success
		End

		It 'fails when file does not match scope'
			When call validate_files_against_scope "cz" "scripts/cz/main.sh" "scripts/dotenv/x.sh"
			The status should be failure
		End
	End

	Describe 'validate_files_against_scopes (multi-scope)'
		BeforeEach 'parse_ini <<< "[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**"'

		It 'passes when files match any of multiple scopes'
			When call validate_files_against_scopes "cz,dotenv" "scripts/cz/main.sh" "scripts/dotenv/x.sh"
			The status should be success
		End

		It 'fails when file matches none of the scopes'
			When call validate_files_against_scopes "cz,dotenv" "scripts/cz/main.sh" "README.md"
			The status should be failure
		End
	End
End
```

**Step 2: Run test to verify it fails**

Run: `make test NAME=cz`
Expected: FAIL - path_validator.sh not found

**Step 3: Write path validator implementation**

```bash
# scripts/cz/path_validator.sh
# shellcheck shell=bash

# Check if a file matches a glob pattern
# Usage: file_matches_pattern <file> <pattern>
file_matches_pattern() {
	local file="$1" pattern="$2"

	# Handle * = match everything
	[[ "$pattern" == "*" ]] && return 0

	# Convert glob to regex
	# ** matches any path (including /)
	# * matches anything except /
	local regex="$pattern"
	regex="${regex//./\\.}"           # Escape dots
	regex="${regex//\*\*/__DSTAR__}"  # Placeholder for **
	regex="${regex//\*/__STAR__}"     # Placeholder for *
	regex="${regex//__DSTAR__/.*}"    # ** -> .*
	regex="${regex//__STAR__/[^/]*}"  # * -> [^/]*
	regex="^${regex}$"

	[[ "$file" =~ $regex ]]
}

# Check if a file matches a scope's patterns
# Usage: file_matches_scope <file> <scope>
file_matches_scope() {
	local file="$1" scope="$2"
	local patterns
	patterns="$(get_scope_patterns "$scope")"

	[[ -z "$patterns" ]] && return 1

	# Split comma-separated patterns
	local IFS=','
	local pattern
	for pattern in $patterns; do
		# Trim whitespace
		pattern="${pattern#"${pattern%%[![:space:]]*}"}"
		pattern="${pattern%"${pattern##*[![:space:]]}"}"

		if file_matches_pattern "$file" "$pattern"; then
			return 0
		fi
	done

	return 1
}

# Find which scope a file matches
# Usage: find_matching_scope <file>
# Outputs: scope name or empty
find_matching_scope() {
	local file="$1"

	for scope in "${INI_SCOPE_NAMES[@]}"; do
		[[ "$scope" == "*" ]] && continue  # Skip wildcard
		if file_matches_scope "$file" "$scope"; then
			echo "$scope"
			return 0
		fi
	done

	echo ""
	return 1
}

# Validate all files match a single scope
# Usage: validate_files_against_scope <scope> <file>...
# Returns: 0 if all match, 1 if any fails
# Sets: VALIDATION_ERRORS array with details
validate_files_against_scope() {
	local scope="$1"
	shift
	local files=("$@")

	VALIDATION_ERRORS=()

	for file in "${files[@]}"; do
		if ! file_matches_scope "$file" "$scope"; then
			local actual_scope
			actual_scope="$(find_matching_scope "$file")"
			if [[ -n "$actual_scope" ]]; then
				VALIDATION_ERRORS+=("$file -> matches '$actual_scope', not '$scope'")
			else
				VALIDATION_ERRORS+=("$file -> matches no scope")
			fi
		fi
	done

	[[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# Validate all files match at least one of multiple scopes
# Usage: validate_files_against_scopes <scope,scope,...> <file>...
validate_files_against_scopes() {
	local scopes_str="$1"
	shift
	local files=("$@")

	VALIDATION_ERRORS=()

	# Split scopes
	local IFS=','
	local -a scopes=($scopes_str)

	for file in "${files[@]}"; do
		local matched=false
		for scope in "${scopes[@]}"; do
			# Trim whitespace
			scope="${scope#"${scope%%[![:space:]]*}"}"
			scope="${scope%"${scope##*[![:space:]]}"}"

			if file_matches_scope "$file" "$scope"; then
				matched=true
				break
			fi
		done

		if [[ "$matched" == false ]]; then
			local actual_scope
			actual_scope="$(find_matching_scope "$file")"
			if [[ -n "$actual_scope" ]]; then
				VALIDATION_ERRORS+=("$file -> matches '$actual_scope', not any of '$scopes_str'")
			else
				VALIDATION_ERRORS+=("$file -> matches no scope")
			fi
		fi
	done

	[[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# Check strict mode: all files must NOT match any defined scope
# Usage: validate_strict_no_scope <file>...
# Returns: 0 if no files match scopes, 1 if any match
# Sets: STRICT_MATCHES array with scope suggestions
validate_strict_no_scope() {
	local files=("$@")

	STRICT_MATCHES=()

	for file in "${files[@]}"; do
		local scope
		scope="$(find_matching_scope "$file")"
		if [[ -n "$scope" ]]; then
			STRICT_MATCHES+=("$file -> matches '$scope'")
		fi
	done

	[[ ${#STRICT_MATCHES[@]} -eq 0 ]]
}
```

**Step 4: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/cz/path_validator.sh scripts/cz/path_validator_spec.sh
git commit -m "feat(cz): add path validator for scope-to-file matching"
```

---

## Task 3: Update Config Loader for INI Format

**Files:**
- Modify: `scripts/cz/config.sh`
- Modify: `scripts/cz/config_defaults.sh`

**Step 1: Write failing test for INI config loading**

Add to a new test file or extend existing:

```bash
# Add to scripts/cz/config_spec.sh (create if needed)
# shellcheck shell=bash

Describe 'load_config with INI format'
	Include ./config.sh

	setup_temp_config() {
		TEMP_DIR=$(mktemp -d)
		CONFIG_FILE="$TEMP_DIR/.gitcommitizen"
	}

	cleanup_temp_config() {
		rm -rf "$TEMP_DIR"
	}

	BeforeEach 'setup_temp_config'
	AfterEach 'cleanup_temp_config'

	It 'detects INI format by [section]'
		cat > "$CONFIG_FILE" << 'EOF'
[settings]
strict = true

[scopes]
cz = scripts/cz/**

[types]
feat = A new feature
EOF
		When call load_config
		The status should be success
		The variable CONFIG_FORMAT should equal "ini"
	End

	It 'detects legacy format by pipe'
		cat > "$CONFIG_FILE" << 'EOF'
feat|A new feature|
fix|A bug fix|
EOF
		When call load_config
		The status should be success
		The variable CONFIG_FORMAT should equal "legacy"
	End
End
```

**Step 2: Run test to verify it fails**

Run: `make test NAME=cz`
Expected: FAIL

**Step 3: Update config.sh to support both formats**

```bash
# scripts/cz/config.sh
# shellcheck shell=bash

# Find and load .gitcommitizen configuration

# @bundle source
. ./config_defaults.sh
# @bundle source
. ./config_parser.sh
# @bundle source
. ./ini_parser.sh
# @bundle source
. ./path_validator.sh

# Sets: TYPES, DESCRIPTIONS, SCOPES, GLOBAL_SCOPES, CONFIG_FILE, CONFIG_FORMAT

# Find config file by walking up directory tree
# Usage: find_config [start_dir]
# Returns: 0 if found (path in CONFIG_FILE), 1 if not found
find_config() {
	local dir="${1:-$PWD}"

	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/.gitcommitizen" ]]; then
			CONFIG_FILE="$dir/.gitcommitizen"
			return 0
		fi
		dir="$(dirname "$dir")"
	done

	CONFIG_FILE=""
	return 1
}

# Detect config format (ini or legacy pipe-delimited)
# Usage: detect_config_format < config_file
detect_config_format() {
	local line
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comments and blank lines
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ "$line" =~ ^[[:space:]]*$ ]] && continue

		# INI format starts with [section]
		if [[ "$line" =~ ^\[[a-z]+\]$ ]]; then
			echo "ini"
			return 0
		fi

		# Legacy format has pipes
		if [[ "$line" == *"|"* ]]; then
			echo "legacy"
			return 0
		fi
	done

	echo "unknown"
}

# Load configuration from file or use defaults
# Usage: load_config
# Requires: CONFIG_FILE to be set (empty = use defaults)
# Exits with error if CONFIG_FILE is set but file doesn't exist
load_config() {
	if [[ -n "$CONFIG_FILE" ]]; then
		if [[ ! -f "$CONFIG_FILE" ]]; then
			echo "cz: error: config file not found: $CONFIG_FILE" >&2
			exit 1
		fi

		CONFIG_FORMAT="$(detect_config_format < "$CONFIG_FILE")"

		case "$CONFIG_FORMAT" in
			ini)
				parse_ini < "$CONFIG_FILE"
				# Build TYPES array from INI_TYPE_NAMES for compatibility
				TYPES=("${INI_TYPE_NAMES[@]}")
				DESCRIPTIONS=()
				for t in "${TYPES[@]}"; do
					local var="INI_TYPES_$t"
					DESCRIPTIONS+=("${!var}")
				done
				;;
			legacy)
				parse_config < "$CONFIG_FILE"
				;;
			*)
				echo "cz: error: unknown config format in $CONFIG_FILE" >&2
				exit 1
				;;
		esac
	else
		default_config
		CONFIG_FORMAT="default"
	fi
}
```

**Step 4: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 5: Commit**

```bash
git add scripts/cz/config.sh
git commit -m "feat(cz): support INI config format with auto-detection"
```

---

## Task 4: Update Lint Command with Path Validation

**Files:**
- Modify: `scripts/cz/options.sh`
- Modify: `scripts/cz/cmd_lint.sh`
- Modify: `scripts/cz/cmd_lint_spec.sh`

**Step 1: Add new CLI options for lint**

```bash
# Update parser_definition_lint in scripts/cz/options.sh
parser_definition_lint() {
	setup   REST help:usage abbr:true -- \
		"Usage: cz lint [options...]"
	msg -- '' 'Validate a commit message from stdin' ''
	msg -- 'Options:'
	flag    QUIET       -q --quiet      -- "Suppress output, exit status only"
	flag    STAGED      -s --staged     -- "Validate scope against staged files"
	param   FILES       -f --files      -- "Validate scope against specified files"
	flag    STRICT      --strict        -- "Require scope for scoped files"
	flag    NO_STRICT   --no-strict     -- "Allow missing scope (override config)"
	disp    :usage      -h --help
}
```

**Step 2: Write failing tests for path validation in lint**

```bash
# Add to scripts/cz/cmd_lint_spec.sh

Describe 'path validation'
	# Helper to set up INI config
	setup_ini_config() {
		parse_ini <<< "[settings]
strict = false

[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**

[types]
feat = A new feature
fix = A bug fix"
		CONFIG_FORMAT="ini"
	}

	BeforeEach 'setup_ini_config'

	Describe 'with --files'
		It 'passes when files match scope'
			FILES="scripts/cz/main.sh scripts/cz/opts.sh"
			Data "feat(cz): add feature"
			When call cmd_lint
			The status should be success
		End

		It 'fails when files do not match scope'
			FILES="scripts/cz/main.sh scripts/dotenv/x.sh"
			Data "feat(cz): add feature"
			When call cmd_lint
			The status should be failure
			The stderr should include "do not match scope"
		End

		It 'passes with multi-scope when enabled'
			parse_ini <<< "[settings]
multi-scope = true

[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**

[types]
feat = A new feature"
			FILES="scripts/cz/main.sh scripts/dotenv/x.sh"
			Data "feat(cz,dotenv): shared change"
			When call cmd_lint
			The status should be success
		End

		It 'fails with multi-scope when disabled'
			FILES="scripts/cz/main.sh scripts/dotenv/x.sh"
			Data "feat(cz,dotenv): shared change"
			When call cmd_lint
			The status should be failure
			The stderr should include "multi-scope not allowed"
		End
	End

	Describe 'strict mode'
		It 'fails when no scope but files match scopes'
			parse_ini <<< "[settings]
strict = true

[scopes]
cz = scripts/cz/**

[types]
feat = A new feature"
			FILES="scripts/cz/main.sh"
			Data "feat: add feature"
			When call cmd_lint
			The status should be failure
			The stderr should include "strict mode requires scope"
		End

		It 'passes when no scope and files match no scopes'
			parse_ini <<< "[settings]
strict = true

[scopes]
cz = scripts/cz/**

[types]
feat = A new feature"
			FILES="README.md"
			Data "feat: update readme"
			When call cmd_lint
			The status should be success
		End

		It 'can be overridden with --no-strict'
			parse_ini <<< "[settings]
strict = true

[scopes]
cz = scripts/cz/**

[types]
feat = A new feature"
			FILES="scripts/cz/main.sh"
			NO_STRICT=1
			Data "feat: add feature"
			When call cmd_lint
			The status should be success
		End
	End

	Describe 'wildcard scope'
		It 'matches any files'
			parse_ini <<< "[scopes]
* = *
cz = scripts/cz/**

[types]
feat = A new feature"
			FILES="scripts/cz/main.sh anything/else.txt"
			Data "feat(*): big change"
			When call cmd_lint
			The status should be success
		End
	End
End
```

**Step 3: Run test to verify it fails**

Run: `make test NAME=cz`
Expected: FAIL

**Step 4: Update cmd_lint.sh with path validation**

```bash
# scripts/cz/cmd_lint.sh
# shellcheck shell=bash disable=SC2034

# cz lint - validate a commit message from stdin

# @bundle source
. ./config.sh

cmd_lint() {
	local message
	message="$(cat)"

	if [[ -z "$message" ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: empty commit message" >&2
		return 1
	fi

	# Load config if not already loaded
	if [[ -z "${TYPES+x}" || ${#TYPES[@]} -eq 0 ]]; then
		if [[ -z "${CONFIG_FILE:-}" ]]; then
			find_config || true
		fi
		load_config
	fi

	# Parse first line: type[(scope)][!]: description
	local first_line="${message%%$'\n'*}"
	local pattern='^([a-z]+)(\(([a-zA-Z0-9_@/,+-]+)\))?(!)?: (.+)$'

	if [[ ! "$first_line" =~ $pattern ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: invalid commit format" >&2
		[[ -z "${QUIET:-}" ]] && echo "Expected: <type>[(scope)]: <description>" >&2
		return 1
	fi

	local type="${BASH_REMATCH[1]}"
	local scope="${BASH_REMATCH[3]}"
	local breaking="${BASH_REMATCH[4]}"
	local description="${BASH_REMATCH[5]}"

	# Validate type
	local type_valid=false
	if [[ "$CONFIG_FORMAT" == "ini" ]]; then
		type_exists "$type" && type_valid=true
	else
		for t in "${TYPES[@]}"; do
			[[ "$t" == "$type" ]] && type_valid=true && break
		done
	fi

	if [[ "$type_valid" != true ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: unknown type '$type'" >&2
		[[ -z "${QUIET:-}" ]] && echo "Allowed types: ${TYPES[*]}" >&2
		return 1
	fi

	# Validate scope if present (INI format with path validation)
	if [[ "$CONFIG_FORMAT" == "ini" ]]; then
		local multi_scope
		multi_scope="$(get_setting multi-scope false)"
		local separator
		separator="$(get_setting multi-scope-separator ,)"

		# Check for multi-scope
		if [[ -n "$scope" && "$scope" == *"$separator"* ]]; then
			if [[ "$multi_scope" != "true" ]]; then
				[[ -z "${QUIET:-}" ]] && echo "cz: error: multi-scope not allowed" >&2
				[[ -z "${QUIET:-}" ]] && echo "Hint: enable with 'multi-scope = true' in .gitcommitizen" >&2
				return 1
			fi
		fi

		# Validate scope exists
		if [[ -n "$scope" ]]; then
			local IFS="$separator"
			for s in $scope; do
				s="${s#"${s%%[![:space:]]*}"}"
				s="${s%"${s##*[![:space:]]}"}"
				if ! scope_exists "$s"; then
					[[ -z "${QUIET:-}" ]] && echo "cz: error: unknown scope '$s'" >&2
					[[ -z "${QUIET:-}" ]] && echo "Defined scopes: ${INI_SCOPE_NAMES[*]}" >&2
					return 1
				fi
			done
		fi

		# Path validation (only if files provided)
		local -a files_to_check=()
		if [[ -n "${STAGED:-}" ]]; then
			# Get staged files
			mapfile -t files_to_check < <(git diff --cached --name-only 2>/dev/null)
		elif [[ -n "${FILES:-}" ]]; then
			# Split FILES by space
			read -ra files_to_check <<< "$FILES"
		fi

		if [[ ${#files_to_check[@]} -gt 0 ]]; then
			# Determine strict mode
			local strict
			if [[ -n "${NO_STRICT:-}" ]]; then
				strict="false"
			elif [[ -n "${STRICT:-}" ]]; then
				strict="true"
			else
				strict="$(get_setting strict false)"
			fi

			if [[ -n "$scope" ]]; then
				# Validate files match scope(s)
				if [[ "$scope" == *"$separator"* ]]; then
					if ! validate_files_against_scopes "$scope" "${files_to_check[@]}"; then
						[[ -z "${QUIET:-}" ]] && echo "cz: error: files do not match scopes '$scope'" >&2
						for err in "${VALIDATION_ERRORS[@]}"; do
							[[ -z "${QUIET:-}" ]] && echo "  $err" >&2
						done
						return 1
					fi
				else
					if ! validate_files_against_scope "$scope" "${files_to_check[@]}"; then
						[[ -z "${QUIET:-}" ]] && echo "cz: error: files do not match scope '$scope'" >&2
						for err in "${VALIDATION_ERRORS[@]}"; do
							[[ -z "${QUIET:-}" ]] && echo "  $err" >&2
						done
						return 1
					fi
				fi
			elif [[ "$strict" == "true" ]]; then
				# Strict mode: no scope provided, files must not match any scope
				if ! validate_strict_no_scope "${files_to_check[@]}"; then
					[[ -z "${QUIET:-}" ]] && echo "cz: error: strict mode requires scope for scoped files" >&2
					for match in "${STRICT_MATCHES[@]}"; do
						[[ -z "${QUIET:-}" ]] && echo "  $match" >&2
					done
					# Suggest scope
					local suggested
					suggested="$(find_matching_scope "${files_to_check[0]}")"
					if [[ -n "$suggested" ]]; then
						[[ -z "${QUIET:-}" ]] && echo "Hint: use '$type($suggested): $description'" >&2
					fi
					return 1
				fi
			fi
		fi
	else
		# Legacy format: validate scope against allowed scopes per type
		if [[ -n "$scope" ]]; then
			local type_index=-1
			for i in "${!TYPES[@]}"; do
				[[ "${TYPES[$i]}" == "$type" ]] && type_index=$i && break
			done

			if [[ $type_index -ge 0 ]]; then
				local allowed_scopes="${SCOPES[$type_index]}"
				if [[ -n "$allowed_scopes" ]]; then
					local scope_valid=false
					for allowed in $allowed_scopes; do
						[[ "$allowed" == "$scope" ]] && scope_valid=true && break
					done

					if [[ "$scope_valid" != true ]]; then
						[[ -z "${QUIET:-}" ]] && echo "cz: error: invalid scope '$scope' for type '$type'" >&2
						[[ -z "${QUIET:-}" ]] && echo "Allowed scopes: $allowed_scopes" >&2
						return 1
					fi
				fi
			fi
		fi
	fi

	# Validate description is not empty
	if [[ -z "$description" || "$description" =~ ^[[:space:]]*$ ]]; then
		[[ -z "${QUIET:-}" ]] && echo "cz: error: description cannot be empty" >&2
		return 1
	fi

	# Validate breaking change has BREAKING CHANGE footer
	if [[ -n "$breaking" ]]; then
		if [[ ! "$message" =~ BREAKING[[:space:]]CHANGE: ]]; then
			[[ -z "${QUIET:-}" ]] && echo "cz: error: breaking change (!) requires 'BREAKING CHANGE:' footer" >&2
			return 1
		fi
	fi

	return 0
}
```

**Step 5: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 6: Commit**

```bash
git add scripts/cz/options.sh scripts/cz/cmd_lint.sh scripts/cz/cmd_lint_spec.sh
git commit -m "feat(cz): add path validation to lint command"
```

---

## Task 5: Update Hook Command

**Files:**
- Modify: `scripts/cz/cmd_hook.sh`
- Modify: `scripts/cz/cmd_hook_spec.sh`

**Step 1: Write failing test for hook path validation**

```bash
# Add to scripts/cz/cmd_hook_spec.sh

Describe 'hook with path validation'
	# ... setup for INI config ...

	It 'validates staged files when running as commit-msg hook'
		# Setup: create temp git repo, stage files, run hook
		# This is an integration test
	End
End
```

**Step 2: Update cmd_hook.sh**

The hook command already calls `cmd_lint` internally. Update to pass `--staged` flag:

```bash
# In the commit-msg hook validation section of cmd_hook.sh
# Set STAGED=1 before calling cmd_lint
STAGED=1 cmd_lint < "$commit_msg_file"
```

**Step 3: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 4: Commit**

```bash
git add scripts/cz/cmd_hook.sh scripts/cz/cmd_hook_spec.sh
git commit -m "feat(cz): enable path validation in commit-msg hook"
```

---

## Task 6: Update Init Command for INI Format

**Files:**
- Modify: `scripts/cz/cmd_init.sh`

**Step 1: Update init to generate INI format**

```bash
# scripts/cz/cmd_init.sh - update generate_config function

generate_config() {
	cat << 'EOF'
# Conventional Commits configuration
# See: gitcommitizen(5)

[settings]
# strict = false
# multi-scope = false
# multi-scope-separator = ,

[scopes]
# Define scopes and their file patterns
# example = src/example/**

[types]
feat = A new feature
fix = A bug fix
docs = Documentation only changes
style = Formatting, white-space, etc
refactor = Code change that neither fixes a bug nor adds a feature
perf = Performance improvement
test = Adding or correcting tests
build = Build system or external dependencies
ci = CI configuration files and scripts
chore = Other changes that don't modify src or test files
revert = Reverts a previous commit
EOF
}
```

**Step 2: Run test to verify it passes**

Run: `make test NAME=cz`
Expected: PASS

**Step 3: Commit**

```bash
git add scripts/cz/cmd_init.sh
git commit -m "feat(cz): update init to generate INI config format"
```

---

## Task 7: Update Documentation

**Files:**
- Modify: `scripts/cz/docs/gitcommitizen.adoc`
- Modify: `scripts/cz/docs/cz.adoc`

**Step 1: Update gitcommitizen.adoc for INI format**

```asciidoc
= GITCOMMITIZEN(5)
...

== FILE FORMAT

INI-style configuration with three sections:

[.literal]
----
[settings]
strict = false
multi-scope = false
multi-scope-separator = ,

[scopes]
name = glob-pattern[, glob-pattern]...

[types]
name = description
----

=== Settings

*strict*:: Require scope when files match defined scopes (default: false)
*multi-scope*:: Allow multiple scopes like `feat(api,db):` (default: false)
*multi-scope-separator*:: Separator for multi-scopes: `,`, `/`, or `+` (default: `,`)

=== Scopes

Maps scope names to glob patterns. Multiple patterns separated by commas.

[.literal]
----
[scopes]
api = src/api/**
config = *.json, *.yaml
* = *
----

Special scope `*` matches any files (wildcard).

=== Types

Maps type names to descriptions.

[.literal]
----
[types]
feat = A new feature
fix = A bug fix
----

== EXAMPLES

[.literal]
----
[settings]
strict = true

[scopes]
api = src/api/**
web = src/web/**
ci = .github/**
docs = *.md, docs/**

[types]
feat = A new feature
fix = A bug fix
docs = Documentation only changes
ci = CI configuration changes
----
...
```

**Step 2: Update cz.adoc with new options**

Add documentation for `--staged`, `--files`, `--strict`, `--no-strict` options.

**Step 3: Commit**

```bash
git add scripts/cz/docs/gitcommitizen.adoc scripts/cz/docs/cz.adoc
git commit -m "docs(cz): update documentation for INI format and path validation"
```

---

## Task 8: Final Integration Test

**Files:**
- Create: `scripts/cz/integration_spec.sh` (optional)

**Step 1: Build and run full test suite**

Run: `make test NAME=cz && make lint NAME=cz && make build NAME=cz`
Expected: All pass

**Step 2: Manual testing**

```bash
# Test with sample config
cat > /tmp/.gitcommitizen << 'EOF'
[settings]
strict = true

[scopes]
cz = scripts/cz/**

[types]
feat = A new feature
EOF

# Should pass
echo "feat(cz): test" | ./dist/cz/bin/cz lint --files scripts/cz/main.sh

# Should fail (wrong scope)
echo "feat(cz): test" | ./dist/cz/bin/cz lint --files README.md
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "test(cz): add integration tests for scope-path validation"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | INI parser | `ini_parser.sh`, `ini_parser_spec.sh` |
| 2 | Path validator | `path_validator.sh`, `path_validator_spec.sh` |
| 3 | Config loader update | `config.sh` |
| 4 | Lint command update | `cmd_lint.sh`, `options.sh` |
| 5 | Hook command update | `cmd_hook.sh` |
| 6 | Init command update | `cmd_init.sh` |
| 7 | Documentation | `gitcommitizen.adoc`, `cz.adoc` |
| 8 | Integration test | Manual verification |
