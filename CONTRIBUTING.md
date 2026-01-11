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
make build NAME=cz
```

## Directory Structure

```
scriptorium/
├── scripts/                    # User-facing scripts
│   ├── spec_helper.sh          # ShellSpec helper for script tests
│   └── <name>/                 # Script implementation
│       ├── main.sh             # Entry point
│       ├── options.sh          # CLI options (getoptions format)
│       ├── default.nix         # Nix package definition
│       ├── docs/               # Documentation
│       │   └── <name>.adoc     # Manpage (AsciiDoc)
│       ├── completions/        # Shell completions
│       │   ├── <name>.bash     # Bash completions
│       │   └── _<name>         # Zsh completions
│       └── *_spec.sh           # ShellSpec tests
├── utils/                      # Build utilities
│   ├── bundle.sh               # Script bundler
│   └── bundle_spec.sh          # Bundler tests
├── dist/                       # Build output (generated)
│   └── <name>/
│       ├── bin/
│       ├── man/
│       └── completions/
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
| `make build [NAME=x]` | Build all scripts or specific one to `dist/` |
| `make install DESTDIR=x [NAME=y]` | Install scripts to DESTDIR |
| `make clean` | Remove generated files in `dist/` |
| `make test [NAME=x]` | Run tests (all, specific script, or `NAME=utils`) |
| `make lint [NAME=x]` | Run shellcheck and shfmt (all, specific, or `NAME=utils`) |
| `make fmt [NAME=x]` | Format with shfmt (all, specific, or `NAME=utils`) |
| `make new-script NAME=x` | Create a new script from templates |

### Bundler

The bundler (`utils/bundle.sh`) combines source files into single executables. See the script header for directives and usage.

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
4. Add package to `release-please-config.json`
5. Import script in root `flake.nix` (add to `let` block and `packages`)
6. Add `docs/<name>.adoc` for manpage
7. Add `<name>_spec.sh` for tests
8. Build: `make build NAME=<name>`
