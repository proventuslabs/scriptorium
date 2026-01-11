# cz: Scope-to-Path Validation

## Overview

Enhance the `cz` commit linter to validate that commit message scopes match the actual files being changed. This prevents mismatched commits like `feat(cz): new feature` when modifying files in `scripts/dotenv/`.

## Motivation

Currently, `cz lint` validates:
- Commit message format (type, scope, description)
- Type against allowed types
- Scope against allowed scopes per type

Missing: validation that the scope matches the actual staged/committed files.

## Config Format

Replace the current pipe-delimited format with INI-style sections:

```ini
# .gitcommitizen

[settings]
strict = false
multi-scope = false
multi-scope-separator = ,

[scopes]
cz = scripts/cz/**
dotenv = scripts/dotenv/**
jwt = scripts/jwt/**
theme = scripts/theme/**
ci = .github/**
nix = flake.nix, flake.lock, */default.nix
docs = *.md, docs/**
* = *

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
```

### Sections

#### `[settings]`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `strict` | bool | `false` | Require scope when files match any defined scope |
| `multi-scope` | bool | `false` | Allow multiple scopes (e.g., `feat(cz,dotenv):`) |
| `multi-scope-separator` | string | `,` | Separator character: `,`, `/`, or `+` |

#### `[scopes]`

Maps scope names to glob patterns (comma-separated for multiple patterns).

| Key | Value |
|-----|-------|
| scope name | glob patterns |
| `*` | wildcard scope (matches any files) |

Patterns support standard glob syntax:
- `**` - recursive directory match
- `*` - single directory/file match
- `?` - single character match
- `{a,b}` - alternation

#### `[types]`

Maps type names to descriptions.

| Key | Value |
|-----|-------|
| type name | human-readable description |

## Validation Behavior

### With Scope Provided

All files must match the scope's glob patterns.

```
feat(cz): add flag
  scripts/cz/main.sh    -> matches 'cz' ✓
  scripts/cz/opts.sh    -> matches 'cz' ✓
  Result: PASS
```

```
feat(cz): add flag
  scripts/cz/main.sh    -> matches 'cz' ✓
  scripts/dotenv/x.sh   -> expected 'cz', got 'dotenv' ✗
  Result: FAIL
```

### With Multi-Scope (when enabled)

All files must match at least one of the provided scopes.

```
feat(cz,dotenv): shared utility
  scripts/cz/main.sh    -> matches 'cz' ✓
  scripts/dotenv/x.sh   -> matches 'dotenv' ✓
  Result: PASS
```

### Without Scope (loose mode, default)

No path validation performed.

```
feat: add flag
  scripts/cz/main.sh    -> no validation
  Result: PASS
```

### Without Scope (strict mode)

Files must NOT match any defined scope.

```
feat: add flag
  scripts/cz/main.sh    -> matches 'cz' ✗
  Result: FAIL
  Hint: use 'feat(cz): add flag'
```

```
feat: update readme
  README.md             -> matches no scope ✓
  Result: PASS
```

### Validation Matrix

| Commit | Files | strict | multi-scope | Result |
|--------|-------|--------|-------------|--------|
| `feat(cz): x` | `scripts/cz/a.sh` | any | any | ✓ Pass |
| `feat(cz): x` | `scripts/cz/a.sh`, `scripts/dotenv/b.sh` | any | any | ✗ Fail |
| `feat(cz,dotenv): x` | `scripts/cz/a.sh`, `scripts/dotenv/b.sh` | any | `true` | ✓ Pass |
| `feat(cz,dotenv): x` | `scripts/cz/a.sh`, `scripts/dotenv/b.sh` | any | `false` | ✗ Fail |
| `feat: x` | `scripts/cz/a.sh` | `false` | any | ✓ Pass |
| `feat: x` | `scripts/cz/a.sh` | `true` | any | ✗ Fail |
| `feat: x` | `README.md` | `true` | any | ✓ Pass |
| `feat(*): x` | any files | any | any | ✓ Pass |

## CLI Changes

### `cz lint`

New flags for path validation:

```bash
# Lint message only (current behavior, no path validation)
echo "feat(cz): add flag" | cz lint

# Lint with path validation (reads staged files)
echo "feat(cz): add flag" | cz lint --staged

# Lint with explicit file list
echo "feat(cz): add flag" | cz lint --files scripts/cz/main.sh scripts/cz/opts.sh

# Override strict mode
echo "feat: add flag" | cz lint --staged --strict
echo "feat: add flag" | cz lint --staged --no-strict
```

### `cz hook`

Path validation enabled by default (uses staged files):

```bash
# In .git/hooks/commit-msg
cz hook "$1"

# Validates:
# 1. Message format (existing)
# 2. Type (existing)
# 3. Scope against staged files (new)
```

### `cz create`

Interactive mode suggests scopes based on staged files:

```bash
$ cz create
Staged files:
  scripts/cz/main.sh
  scripts/cz/opts.sh

Detected scope: cz

? Type: feat
? Scope [cz]:
? Description: add new flag
```

## Error Messages

### Scope mismatch

```
cz: error: files do not match scope 'cz'
  scripts/cz/main.sh    -> ok
  scripts/dotenv/x.sh   -> matches 'dotenv', not 'cz'
```

### Strict mode - scope required

```
cz: error: strict mode requires scope for scoped files
  scripts/cz/main.sh    -> matches 'cz'
  scripts/cz/opts.sh    -> matches 'cz'
Hint: use 'feat(cz): add new flag'
```

### Strict mode - multiple scopes detected

```
cz: error: strict mode requires scope for scoped files
  scripts/cz/main.sh    -> matches 'cz'
  scripts/dotenv/x.sh   -> matches 'dotenv'
Hint: split into separate commits per scope
```

### Multi-scope not allowed

```
cz: error: multi-scope not allowed
Hint: enable with 'multi-scope = true' in .gitcommitizen
```

### Unknown scope

```
cz: error: unknown scope 'foo'
Defined scopes: cz, dotenv, jwt, theme, ci, nix, docs
```

## Migration

### From Current Format

Current `.gitcommitizen`:
```
*||api,core
feat|A new feature|ui
fix|A bug fix|
docs|Documentation changes|-api
```

New `.gitcommitizen`:
```ini
[scopes]
api = src/api/**
core = src/core/**
ui = src/ui/**

[types]
feat = A new feature
fix = A bug fix
docs = Documentation changes
```

### Migration Command

```bash
cz migrate
# Reads old format, outputs new format to stdout
# User manually adds glob patterns to scopes
```

## Implementation Notes

### Glob Matching

Use bash extended globbing or `find`/`git ls-files` with patterns. Consider:
- Performance with large file lists
- Pattern syntax compatibility across shells

### Staged Files Detection

```bash
git diff --cached --name-only
```

### Config Parsing

INI parser in pure bash:
- `[section]` starts new section
- `key = value` within section
- `#` comments
- Blank lines ignored

## Future Considerations

- `cz suggest` command to list matching scopes for staged files
- IDE/editor integrations
- Pre-populate scope in `cz create` based on staged files
- Support for negation patterns (`!pattern`)
