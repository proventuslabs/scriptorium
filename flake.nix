{
  description = "Shell script development environment for scriptorium";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            zsh
            shellspec
            shellcheck
            shfmt
            getoptions
            asciidoctor
            zsh
          ];

          shellHook = ''
            # Suppress Ruby/Bundler warnings about local gems
            export RUBYOPT="-W0"

            echo "Scriptorium dev environment loaded"
            echo "ShellSpec: $(shellspec --version)"

            # Only exec into zsh for interactive shells (not when using --command)
            if [[ $- == *i* ]]; then
              export SHELL=${pkgs.zsh}/bin/zsh
              exec $SHELL
            fi
          '';
        };
      }
    );
}
