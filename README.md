# Scriptorium

A collection of useful shell scripts and utilities targeting Bash 4+.

## Scripts

| Script | Description | Dependencies |
|--------|-------------|--------------|
| [cz](scripts/cz/docs/cz.adoc) | Conventional commit message builder | [`gum`](https://github.com/charmbracelet/gum) (interactive mode) |
| [dotenv](scripts/dotenv/docs/dotenv.adoc) | Load environment variables from .env files | None |
| [theme](scripts/theme/docs/theme.adoc) | Extensible theme orchestrator for shell environments | None |

## Installation

### Via Nix

```bash
# Install individual script
nix profile install github:proventuslabs/scriptorium#dotenv

# Install all scripts
nix profile install github:proventuslabs/scriptorium

# Run without installing
nix run github:proventuslabs/scriptorium#dotenv -- --help
```

### From source

```bash
# Clone and build
git clone https://github.com/proventuslabs/scriptorium.git
cd scriptorium
nix develop  # or install dependencies manually
make build

# Add to PATH
export PATH="$PWD/bin:$PATH"

# Or install to ~/.local/bin
cp bin/* ~/.local/bin/
```

### Shell plugin

Source the plugin in your shell config for completions:

```bash
# Bash (~/.bashrc)
source /path/to/scriptorium/scriptorium.plugin.sh

# Zsh (~/.zshrc)
source /path/to/scriptorium/scriptorium.plugin.zsh
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, build system, and how to add new scripts.

## License

See LICENSE file.
