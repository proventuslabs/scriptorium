# Scriptorium

A collection of useful shell scripts and utilities targeting Bash 4+.

## Scripts

*No scripts yet - contributions welcome!*

## Installation

### From source

```bash
# Clone and build
git clone https://github.com/user/scriptorium.git
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
