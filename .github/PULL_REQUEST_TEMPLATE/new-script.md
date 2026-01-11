## Summary

<!-- Brief description of the new script -->

## Checklist

### Script files

- [ ] `scripts/<name>/main.sh` - Entry point with `#!/usr/bin/env bash`
- [ ] `scripts/<name>/options.sh` - CLI options (getoptions DSL)
- [ ] `scripts/<name>/default.nix` - Nix package definition
- [ ] `scripts/<name>/*_spec.sh` - Tests (ShellSpec)
- [ ] `scripts/<name>/docs/<name>.adoc` - Manpage documentation
- [ ] `scripts/<name>/completions/<name>.bash` - Bash completions
- [ ] `scripts/<name>/completions/_<name>` - Zsh completions

### Integration

- [ ] `release-please-config.json` - Added package with `component` and `extra-files`
- [ ] `flake.nix` - Imported script in root flake
- [ ] `README.md` - Added script entry

### Verification

- [ ] Tests pass (`make test NAME=<name>`)
- [ ] Linting passes (`make lint NAME=<name>`)
- [ ] Build succeeds (`make build NAME=<name>`)
