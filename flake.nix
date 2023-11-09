{
  # validate a flake with 'nix flake check .'
  # alias the use of flakes with: "alias nix='nix --extra-experimental-features nix-command --extra-experimental-features flakes'"

  # WARNING! this is linux/mac only!
  description = "A reliable testing environment";

  # https://status.nixos.org/ has the latest channels, it is recommended to use a commit hash
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html
  # to find: go to github/NixOS/nixpkgs repo

  # select a commit hash or "revision"
  #inputs.nixpkgs.url = "nixpkgs/92fe622fdfe477a85662bb77678e39fa70373f13";

  # select a tag
  #inputs.nixpkgs.url = "github:NixOS/nixpkgs/21.11";

  # select packages from another flake
  #inputs.nixpkgs.follows = "nixpkgs/0228346f7b58f1a284fdb1b72df6298b06677495";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      # 'legacy' is not bad, it looks for previously imported nixpkgs
      #  this allows idempotent loading of nixpkgs in dependent flakes
      # https://discourse.nixos.org/t/using-nixpkgs-legacypackages-system-vs-import/17462/8
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # get "leftovers" bin from release and add it to shell
        leftovers-urls = {
          "x86_64-linux" = "https://github.com/genevieve/leftovers/releases/download/v0.70.0/leftovers-v0.70.0-linux-amd64";
          "x86_64-darwin" = "https://github.com/genevieve/leftovers/releases/download/v0.70.0/leftovers-v0.70.0-darwin-amd64";
          "aarch64-darwin" = "https://github.com/genevieve/leftovers/releases/download/v0.70.0/leftovers-v0.70.0-darwin-arm64";
        };
        leftovers = pkgs.runCommand "leftovers-v0.70.0" {} ''
          cp ${pkgs.fetchurl {
            url = leftovers-urls."${system}";
            sha256 = "sha256-HV12kHqB14lGDm1rh9nD1n7Jvw0rCnxmjC9gusw7jfo=";
          }} $out
          chmod +x $out
        '';
        leftovers-wrapper = pkgs.writeShellScriptBin "leftovers" ''
          exec ${leftovers} "$@"
        '';

      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bashInteractive
            git
            tflint
            shellcheck
            tfswitch
          ];
          shellHook = ''
            tfswitch 1.5.7;
            export PATH="$PATH:${leftovers-wrapper}/bin";
          '';
        };
        packages.x86_64-linux.default = self.devShell;
      }
    );
}
