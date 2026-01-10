{
  description = "Shell script collection for scriptorium";

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

        # Helper to build script packages
        mkScript = { name, version, description, src }:
          pkgs.stdenv.mkDerivation {
            pname = name;
            inherit version src;

            nativeBuildInputs = with pkgs; [ bash getoptions ];

            buildPhase = ''
              # Bundle script using project bundler
              ${pkgs.bash}/bin/bash ${./utils/bundle.sh} main.sh > ${name}
            '';

            installPhase = ''
              mkdir -p $out/bin $out/share/man/man1 $out/share/man/man5
              install -m755 ${name} $out/bin/

              # Install manpages if they exist
              for section in 1 5; do
                if [ -f "${name}.$section" ]; then
                  install -m644 "${name}.$section" "$out/share/man/man$section/"
                fi
              done
            '';

            meta = with pkgs.lib; {
              inherit description;
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = name;
            };
          };

        # Import script packages (added as scripts are merged)
        # Example: dotenv = import ./scripts/dotenv { inherit pkgs mkScript; };

        allScripts = [
          # Scripts added here as they're merged
        ];
      in
      {
        packages = {
          # Individual script packages added here as they're merged
          # Example: inherit dotenv;

          # Meta-package with all scripts
          default = pkgs.symlinkJoin {
            name = "scriptorium";
            paths = allScripts;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            zsh
            shellspec
            shellcheck
            shfmt
            getoptions
            asciidoctor
          ];

          shellHook = ''
            export RUBYOPT="-W0"
            echo "Scriptorium dev environment loaded"
            echo "ShellSpec: $(shellspec --version)"

            if [[ $- == *i* ]]; then
              export SHELL=${pkgs.zsh}/bin/zsh
              exec $SHELL
            fi
          '';
        };
      }
    );
}
