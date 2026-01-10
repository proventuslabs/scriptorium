# Contributing to Scriptorium

## Requirements

- Nix (for development environment)
- Or manually: `bash 4+`, `shellspec`, `shellcheck`, `shfmt`, `getoptions`, `asciidoctor`

## Quick Start

```bash
# Enter development environment
nix develop

# Run all tests
make test

# Build all scripts
make build

# Build a specific script
make build-script NAME=cz
```

## Directory Structure

```
scriptorium/
├── scripts/                    # User-facing scripts
│   ├── spec_helper.sh          # ShellSpec helper for script tests
│   └── <name>/                 # Script implementation
│       ├── main.sh             # Entry point
│       ├── options.sh          # CLI options (getoptions format)
│       ├── docs/               # Documentation
│       │   └── <name>.adoc     # Manpage (AsciiDoc)
│       ├── completions/        # Shell completions
│       │   ├── <name>.bash     # Bash completions
│       │   └── _<name>         # Zsh completions
│       └── *_spec.sh           # ShellSpec tests
├── utils/                      # Build utilities
│   ├── bundle.sh               # Script bundler
│   └── bundle_spec.sh          # Bundler tests
├── bin/                        # Built executables (generated)
├── man/                        # Built manpages (generated)
├── templates/                  # Script templates for new-script
├── scriptorium.plugin.sh       # Bash plugin (source in .bashrc)
├── scriptorium.plugin.zsh      # Zsh plugin (source in .zshrc)
├── flake.nix                   # Nix packages and dev environment
└── Makefile                    # Build targets
```

## Build System

### Make Targets

| Target | Description |
|--------|-------------|
| `make build` | Build all (manpages + binaries) |
| `make build-script NAME=x` | Build a specific script |
| `make build-man` | Generate manpages from `.adoc` files |
| `make build-bin` | Bundle scripts into `bin/` |
| `make clean` | Remove generated files |
| `make test` | Run all tests |
| `make test-scripts` | Run script tests |
| `make test-utils` | Run utils tests |
| `make lint` | Run shellcheck and check formatting |
| `make fmt` | Format shell scripts with shfmt |
| `make new-script NAME=x` | Create a new script from templates |

### Bundler

The bundler (`utils/bundle.sh`) combines source files into single executables:

- Inlines `source`/`.` statements marked with `# @bundle source`
- Tracks included files to avoid duplicates
- Preserves shebang from entry file

#### Directives

```bash
# Inline the next source statement
# @bundle source
. ./lib.sh

# Run command at bundle time, skip block until @bundle end
# @bundle cmd gengetoptions parser -f ./options.sh parser_definition parse
. ./options.sh
eval "$(getoptions parser_definition parse)"
# @bundle end

# Mark content to preserve when referenced by @bundle cmd -f
# @bundle keep
VERSION=1.0
# @bundle end
```

## Versioning

Scripts are versioned independently using [Semantic Versioning](https://semver.org/). Releases are automated via [release-please](https://github.com/googleapis/release-please).

## Adding a New Script

```bash
make new-script NAME=<name>
```

This creates `scripts/<name>/` with `main.sh`, `options.sh`, and `default.nix` from templates.

Then:
1. Implement your script in `main.sh`
2. Add CLI options in `options.sh`
3. Update description in `default.nix`
4. Add component to `release-please-config.json`
5. Import script in root `flake.nix` (add to `let` block and `packages`)
6. Add `docs/<name>.adoc` for manpage
7. Add `<name>_spec.sh` for tests
8. Build: `make build-script NAME=<name>`
