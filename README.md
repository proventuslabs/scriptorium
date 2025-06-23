# Scriptorium

A collection of useful shell functions, scripts and utilities targeting Zsh.

## Directory Structure

```
scriptorium/
├── lib/
|   ├── spec_helper.sh              # ShellSpec helper for running library tests
│   └── <scripts>                   # Implementation of each library script
├── scripts/
|   ├── spec_helper.sh              # ShellSpec helper for running scripts tests
|   ├── <scripts>                   # Implementation of each user script
│   └── example/                    # example script - some useful shell function
│       ├── example.[1-8]           # Manual page documentation
│       ├── example.zsh             # Zsh implementation
|       ├── example_spec.sh         # ShellSpec tests
│       └── example_comp.zsh        # Zsh completion
├── scriptorium.plugin.zsh          # Plugin file to source for setup
├── scriptorium.uninstall.zsh       # Runnable uninstallation script
└── README.md                       # This file
```

## Installation

### Manually

Source `scriptorium.plugin.zsh` into your shell.

### Using Sheldon Plugin Manager (Recommended)

Add to your `~/.config/sheldon/plugins.toml`:

```toml
[plugins.scriptorium]
github = "proventuslabs/scriptorium"
use = ["scriptorium.plugin.zsh"]
```

Then run: `sheldon lock && sheldon source`

## Scripts

### mkcd
A shell script that creates a directory and changes into it in one command.

**Usage:**
```bash
mkcd directory_name              # Create and enter directory
mkcd -v directory_name           # Use any `mkdir` flag
mkcd --help                      # Show help
```
