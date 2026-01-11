# TODOs

Pending fixes and improvements for the project.

## `.editorconfig`

- [x] Verify we support formatting for all relevant files

## `templates`

- [x] Add docs templates for `command.adoc`
- [x] Verify what else is being done for new scripts and update the templates to have them as foundation guidance
- [x] Add a simple `README.md` to explain layout/structure of files and their content with a short sentence

## `templates/default.nix`

- [x] Remove `pkgs` from function arguments (`{ pkgs, mkScript }:` → `{ mkScript }:`)
- [x] Remove unused `src = ./.;` field

## `.github/PULL_REQUEST_TEMPLATE.md`

- [x] Update checklist

## `CONTRIBUTING.md`

- [x] Step 4: "Add component" → "Add package" in release-please-config.json instructions
- [x] Shave off Bundler section, point it to the script file to read how it works

## `Makefile`

- [x] new-script target: "Add component" → "Add package" in printed instructions

## `flake.nix`

- [x] Root flake default package version: use `self.shortRev or self.dirtyShortRev or "dev"` instead of hardcoded version

## `scripts/**/docs/*.adoc`

- [x] Add versions number with magic tag for injection

## `LICENSE`

- [x] Add to the root

## Open PRs

- [ ] Align all to use the same error/warning wording and exit codes semantics
- [ ] Align all to conform to current templates for PR, scripts files, and everything else
