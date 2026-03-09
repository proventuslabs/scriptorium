# Changelog

## [0.2.0](https://github.com/proventuslabs/scriptorium/compare/cz-v0.1.0...cz-v0.2.0) (2026-03-09)


### ⚠ BREAKING CHANGES

* **cz:** align validation and errors to Conventional Commits spec ([#76](https://github.com/proventuslabs/scriptorium/issues/76))
* **cz:** --paths no longer accepts space-separated paths. Use repeated --paths flags: --paths "file one" --paths "file two"

### Features

* **cz:** add --{no-}breaking-footer flag ([#72](https://github.com/proventuslabs/scriptorium/issues/72)) ([d22921f](https://github.com/proventuslabs/scriptorium/commit/d22921f9de08f6aaf838822e2d8babf865ae43ee))
* **cz:** align validation and errors to Conventional Commits spec ([#76](https://github.com/proventuslabs/scriptorium/issues/76)) ([dde2edc](https://github.com/proventuslabs/scriptorium/commit/dde2edc9907027d2dd70f5ae6efe0202a54908f0))


### Bug Fixes

* **cz:** handle spaces in --paths file arguments ([#67](https://github.com/proventuslabs/scriptorium/issues/67)) ([d84893c](https://github.com/proventuslabs/scriptorium/commit/d84893c4bb7b37cbc86dfa3ac9f2bf9ee7880c7e))
* **cz:** parse leftovers and cleanup ([#74](https://github.com/proventuslabs/scriptorium/issues/74)) ([75dcbf3](https://github.com/proventuslabs/scriptorium/commit/75dcbf3496b9e0b9673d52ceb6e00013aa04831f))

## 0.1.0 (2026-01-21)


### ⚠ BREAKING CHANGES

* **cz:** split scope flags into explicit -r/-d/-e options ([#62](https://github.com/proventuslabs/scriptorium/issues/62))
* **cz:** Users must update scripts using lint -f to use -p.

### Features

* **cz:** add -m/--{no-}multi-scope flag ([681b2c5](https://github.com/proventuslabs/scriptorium/commit/681b2c5c6d3419d5d417c91e626c426a2ede2f23))
* **cz:** initial implementation ([#9](https://github.com/proventuslabs/scriptorium/issues/9)) ([e8f1f48](https://github.com/proventuslabs/scriptorium/commit/e8f1f48de5272965da739d39ecdd614e961e8c34))
* **cz:** make init print to stdout by default ([#17](https://github.com/proventuslabs/scriptorium/issues/17)) ([b910944](https://github.com/proventuslabs/scriptorium/commit/b910944a49c2896af013f1253d76f90ae2c5a52e))
* **cz:** scope-to-path validation with INI config format ([#16](https://github.com/proventuslabs/scriptorium/issues/16)) ([ef29e1b](https://github.com/proventuslabs/scriptorium/commit/ef29e1bedaa516996d4c2162362e4ef80f8b691c))


### Bug Fixes

* **cz:** rename lint -f/--files to -p/--paths ([#55](https://github.com/proventuslabs/scriptorium/issues/55)) ([0680011](https://github.com/proventuslabs/scriptorium/commit/0680011d4f3369833332c3fee2e7e67f4b9ef7a3))


### Code Refactoring

* **cz:** split scope flags into explicit -r/-d/-e options ([#62](https://github.com/proventuslabs/scriptorium/issues/62)) ([2f570c3](https://github.com/proventuslabs/scriptorium/commit/2f570c36e33d2d8d807287897820b9a9427bb48e))
