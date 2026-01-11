# Templates

Templates for `make new-script NAME=<name>`. Placeholders like `<name>` are replaced automatically.

## Files

| File | Purpose |
|------|---------|
| `main.sh` | Script entry point with argument parsing; flat, never sourced but called; import all scripts |
| `options.sh` | CLI options using getoptions DSL |
| `default.nix` | Nix package definition |
| `*_spec.sh` | ShellSpec test template |
| `*.sh` | Additional scripts to split code; each source and bundle their dependencies |
| `docs/command.adoc` | AsciiDoc manpage (section 1) |
| `docs/*.adoc` | Additional manpages (e.g., section 5 for file formats) |
| `completions/command.bash` | Bash completion script |
| `completions/_command` | Zsh completion script |
