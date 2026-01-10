# Nix package definition for <name>
{ pkgs, mkScript }:

mkScript {
  name = "<name>";
  version = "0.1.0"; # x-release-please-version
  description = "<description>";
  src = ./.;
}
