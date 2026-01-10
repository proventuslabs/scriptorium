## Summary

<!-- Brief description of the changes -->

## Checklist

### For new scripts

- [ ] `scripts/<name>/main.sh` - Entry point with `#!/usr/bin/env bash`
- [ ] `scripts/<name>/options.sh` - CLI options (getoptions DSL)
- [ ] `scripts/<name>/default.nix` - Nix package definition
- [ ] `scripts/<name>/*_spec.sh` - Tests (ShellSpec)
- [ ] `scripts/<name>/docs/<name>.adoc` - Manpage documentation
- [ ] `scripts/<name>/completions/<name>.bash` - Bash completions
- [ ] `scripts/<name>/completions/_<name>` - Zsh completions
- [ ] `release-please-config.json` - Added script component
- [ ] `flake.nix` - Imported script in root flake
- [ ] `README.md` - Added script entry with link to docs
- [ ] Built artifacts committed (`make build NAME=<name>`)

### For all changes

- [ ] Tests pass (`make test NAME=<name>`)
- [ ] Linting passes (`make lint NAME=<name>`)
- [ ] Artifacts up to date (`make build NAME=<name>`)
