{
  description = "Cross-distro Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # The escape hatch for the individual packages the stable pin cannot serve,
    # reached through `unstablePkgs` rather than as a second base for the user
    # environment. Adding one is naming it at a single use site; everything
    # left unnamed stays on the release above. Each package taken from here
    # owes a line in docs/DECISIONS.md saying what stable could not do.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Coding agents release too quickly for stable Nixpkgs. These focused
    # flakes package the vendors' native binaries instead of compiling them.
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix publishes no release branches, only master, so this input
    # cannot be pinned alongside the nixos-26.05 / release-26.05 pins above.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spicetify patches Spotify's client at build time, which is how the ad
    # blocker gets in. Like sops-nix it has no release branches.
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, claude-code-nix, codex-cli-nix, home-manager, sops-nix, spicetify-nix, ... }:
    let
      system = "x86_64-linux";
      unstablePkgs = import nixpkgs-unstable { inherit system; };
      claudeCode = claude-code-nix.packages.${system}.default;
      codex = codex-cli-nix.packages.${system}.default;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = package:
          builtins.elem (nixpkgs.lib.getName package) [
            # mpv-cut ships a custom licence nixpkgs marks unfree; it is a
            # retained script from the legacy MPV setup, not a new choice.
            "mpv-cut"
            "obsidian"
            "spotify"
            "sublimetext4"
            "vscode"
          ];
      };
      # nixpkgs currently carries gitleaks 8.30.1, whose default rules do not
      # detect canonical tokens (upstream issue #2170). The issue is closed but
      # the fix is unreleased — 8.30.1 is still the newest tag — so this pin
      # goes when a later release lands, not when the issue closed. Keep the
      # regression fixture in tests/secret_scan_test.sh before updating it.
      gitleaks = pkgs.gitleaks.overrideAttrs (_: rec {
        version = "8.18.4";
        src = pkgs.fetchFromGitHub {
          owner = "gitleaks";
          repo = "gitleaks";
          tag = "v${version}";
          hash = "sha256-tAomF5Ym+D/VMYXrsPlUnh3M94Xdx6I8WoU1jMouZag=";
        };
        vendorHash = "sha256-DgCtWRo5KNuFCdhGJvzoH2v8n7mIxNk8eHyZFPUPo24=";
        ldflags = [
          "-s"
          "-w"
          "-X=github.com/zricethezav/gitleaks/v8/cmd.Version=${version}"
        ];
        # This release exposes `gitleaks version`, not the `--version` flag
        # expected by nixpkgs' versionCheckHook.
        doInstallCheck = false;
      });
      recoverAgeIdentity =
        pkgs.callPackage ./packages/recover-age-identity.nix { };
    in
    {
      apps.${system}.recover-age-identity = {
        type = "app";
        program = "${recoverAgeIdentity}/bin/recover-age-identity";
        meta.description = "Recover the dotfiles age identity from KeePassXC";
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        # sops is here for the staged secret gate, which asks it whether a file
        # under secrets/ is genuinely encrypted.
        packages = [ gitleaks pkgs.sops ];
      };

      packages.${system} = {
        recover-age-identity = recoverAgeIdentity;
        inherit claudeCode codex;
        inherit (unstablePkgs) gallery-dl sing-box;
      };

      homeConfigurations =
        let
          mkHome = extraModules: home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = {
              inherit claudeCode codex sops-nix spicetify-nix unstablePkgs;
            };
            modules = [
              ./home.nix
              { dotfiles.localProxy.package = unstablePkgs.sing-box; }
            ] ++ extraModules;
          };
        in
        {
          z = mkHome [ ];
          # The staging VM runs at the same time as the host, so it must not
          # share the host's VPN identity. Nothing else differs.
          staging = mkHome [
            { dotfiles.vpn.identity = nixpkgs.lib.mkForce "desktop-ubuntu"; }
          ];
        };
    };
}
