# shellcheck shell=bash

# Error code registry - centralized error messages for cz
# Each code maps to a printf format string
# Usage: _err <code> [args...]

# shellcheck disable=SC2034 # ERR_CODES is used by _err in helpers.sh
declare -gA ERR_CODES=(
	["empty-message"]="empty commit message"
	["header-format"]="commits MUST be prefixed with a type, followed by a colon and space"
	["type-enum"]="unknown type '%s'"
	["description-empty"]="description MUST immediately follow the colon and space"
	["body-leading-blank"]="body MUST begin one blank line after the description"
	["breaking-footer"]="if included in the type/scope prefix, breaking changes MUST be indicated by a BREAKING CHANGE footer"
	["scope-required"]="scope required"
	["scope-enum"]="unknown scope '%s'"
	["scope-missing-config"]="scope '%s' used but no scopes defined in config"
	["scope-file-required"]="scope required for scoped files"
	["multi-scope-disabled"]="multi-scope not enabled"
	["files-scope-mismatch"]="files do not match scope '%s'"
	["files-scopes-mismatch"]="files do not match scopes '%s'"
	["config-not-found"]="config file not found: %s"
	["gum-not-found"]="gum is required for interactive mode"
	["description-required"]="description MUST NOT be empty"
	["breaking-explanation"]="breaking change explanation is required"
	["file-exists"]="'%s' already exists (use -f to overwrite)"
	["not-git-repo"]="not a git repository"
	["hook-action-unknown"]="unknown hook action '%s'"
	["hook-exists"]="existing commit-msg hook found"
	["hook-foreign"]="commit-msg hook was not installed by cz"
)
