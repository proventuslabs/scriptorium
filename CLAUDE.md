# Claude Context

Shell script collection with build system. Bash 4+.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development commands and build system.

## Key Files

- `scripts/<name>/main.sh` - Script entry point
- `scripts/<name>/options.sh` - CLI options (getoptions DSL)
- `scripts/<name>/docs/<name>.adoc` - Manpage (AsciiDoc)
- `scripts/<name>/completions/` - Shell completions (`.bash`, `_zsh`)
- `scripts/<name>/*_spec.sh` - Tests (ShellSpec)
- `utils/bundle.sh` - Bundles scripts into single executables

## Conventions

- Inline shellcheck directives with an explanation when possible
- Use `#!/usr/bin/env bash` shebang
- Use `utils/bundle.sh` for build-time code generation
- Runtime getoptions eval, bundle-time gengetoptions parser generation
