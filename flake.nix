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

        # Build tools needed for scripts
        buildTools = with pkgs; [
          bash
          gnumake
          coreutils
          getoptions
          asciidoctor
        ];

        # Bash 4+ runtime dependency
        bash4 = pkgs.bash;

        # Helper to build individual script packages
        mkScript =
          {
            name,
            version,
            description,
          }:
          pkgs.stdenv.mkDerivation {
            pname = name;
            inherit version;
            src = self;

            nativeBuildInputs = buildTools;
            propagatedBuildInputs = [ bash4 ];

            buildPhase = ''
              make build NAME=${name}
            '';

            installPhase = ''
              make install NAME=${name} DESTDIR=$out
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

        scripts = {
          # Scripts imported here as they're merged
          cz = import ./scripts/cz { inherit mkScript; };
          dotenv = import ./scripts/dotenv { inherit mkScript; };
          jwt = import ./scripts/jwt { inherit mkScript; };
          theme = import ./scripts/theme { inherit mkScript; };
        };
      in
      {
        packages = scripts // {
          # Individual scripts exposed via: nix build .#<name>

          # Meta-package with all scripts and plugins
          default = pkgs.stdenv.mkDerivation {
            pname = "scriptorium";
            version = self.shortRev or self.dirtyShortRev or "dev";
            src = self;

            nativeBuildInputs = buildTools;
            propagatedBuildInputs = [ bash4 ];

            buildPhase = ''
              make build
            '';

            installPhase = ''
              make install DESTDIR=$out
            '';

            meta = with pkgs.lib; {
              description = "Shell script collection";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs =
            buildTools
            ++ (with pkgs; [
              zsh
              shellspec
              shellcheck
              shfmt
              gum
              openssl
            ]);

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
