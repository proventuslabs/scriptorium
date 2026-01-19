{
  description = "Shell script collection for scriptorium";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    kcov-src = {
      url = "github:SimonKagstrom/kcov";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      kcov-src,
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
              patchShebangs $out/bin
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

        # kcov built from source for macOS (nixpkgs kcov doesn't support Darwin)
        kcov-darwin = pkgs.stdenv.mkDerivation {
          pname = "kcov";
          version = kcov-src.shortRev or "dev";
          src = kcov-src;

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            darwin.bootstrap_cmds
            darwin.sigtool
          ];

          buildInputs = with pkgs; [
            zlib
            openssl
            python3
            curl
            libdwarf
          ];

          cmakeFlags = [
            "-G"
            "Ninja"
            "-DCMAKE_BUILD_TYPE=Release"
            "-DDWARFUTILS_INCLUDE_DIR=${pkgs.libdwarf.dev}/include/libdwarf-2"
            "-DDWARFUTILS_LIBRARY=${pkgs.libdwarf.lib}/lib/libdwarf.2.dylib"
          ];

          meta = with pkgs.lib; {
            description = "Code coverage tool for compiled programs";
            homepage = "https://github.com/SimonKagstrom/kcov";
            license = licenses.gpl2Only;
            platforms = platforms.darwin;
          };
        };
      in
      {
        packages = scripts // {
          # Individual scripts exposed via: nix build .#<name>

          # kcov for macOS (nixpkgs doesn't support Darwin)
          kcov = if pkgs.stdenv.isDarwin then kcov-darwin else pkgs.kcov;

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
            ++ [
              (if pkgs.stdenv.isDarwin then kcov-darwin else pkgs.kcov)
            ]
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
