# Scriptorium

A collection of useful shell scripts and utilities targeting Bash 4+.

## Scripts

| Script | Description | Dependencies | Coverage |
|--------|-------------|--------------|----------|
| [cz](scripts/cz/docs/cz.adoc) | Conventional commit message builder | [`gum`](https://github.com/charmbracelet/gum) (interactive mode) | ![coverage](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/vabatta/d172222e308e253e2cb3e02f103d5c8c/raw/coverage.json&query=$.cz.coverage&suffix=%25&label=) |
| [dotenv](scripts/dotenv/docs/dotenv.adoc) | Load environment variables from .env files | None | ![coverage](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/vabatta/d172222e308e253e2cb3e02f103d5c8c/raw/coverage.json&query=$.dotenv.coverage&suffix=%25&label=) |
| [jwt](scripts/jwt/docs/jwt.adoc) | Decode and verify JSON Web Tokens | `openssl`, `xxd` (ECDSA only) | ![coverage](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/vabatta/d172222e308e253e2cb3e02f103d5c8c/raw/coverage.json&query=$.jwt.coverage&suffix=%25&label=) |
| [theme](scripts/theme/docs/theme.adoc) | Extensible theme orchestrator for shell environments | None | ![coverage](https://img.shields.io/badge/dynamic/json?url=https://gist.githubusercontent.com/vabatta/d172222e308e253e2cb3e02f103d5c8c/raw/coverage.json&query=$.theme.coverage&suffix=%25&label=) |

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
