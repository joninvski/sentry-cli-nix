{
  description = "The new Sentry CLI (sentry), packaged from npm";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
        };
      # Explicitly requesting this flake's package opts into Sentry's FSL license.
      # Overlay consumers retain control of their own nixpkgs license policy.
      sentryFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "sentry";
            };
          };
        in
        pkgs.callPackage ./package.nix { };
    in
    {
      overlays.default = final: _prev: {
        sentry = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (system: rec {
        sentry = sentryFor system;
        default = sentry;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.sentry}/bin/sentry";
          meta.description = "Run the new Sentry CLI";
        };
      });

      formatter = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.writeShellScriptBin "format" ''
          if [ "$#" -eq 0 ]; then
            set -- flake.nix package.nix
          fi
          exec ${pkgs.lib.getExe pkgs.nixfmt} "$@"
        ''
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          sentry = self.packages.${system}.sentry;
        in
        {
          package = sentry;
          smoke = pkgs.runCommand "sentry-smoke-${sentry.version}" { } ''
            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export SENTRY_TELEMETRY_DISABLED=1
            mkdir -p "$HOME"
            test "$(${sentry}/bin/sentry --version)" = "${sentry.version}"
            ${sentry}/bin/sentry --help > "$TMPDIR/help"
            grep -q '^USAGE' "$TMPDIR/help"
            touch "$out"
          '';
        }
      );
    };
}
