{
  description = "Cross-distro Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Only sing-box needs the namespace support absent from the stable pin.
    # Keep the rest of the user environment on its existing release.
    nixpkgs-networking.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Coding agents release much faster than the stable Nixpkgs branch. Keep
    # this input's own tested nixpkgs pin so its binary cache remains usable.
    llm-agents.url = "github:numtide/llm-agents.nix";

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
  };

  outputs = { nixpkgs, nixpkgs-networking, llm-agents, home-manager, sops-nix, ... }:
    let
      system = "x86_64-linux";
      llmAgentPkgs = llm-agents.packages.${system};
      networkingPkgs = import nixpkgs-networking { inherit system; };
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
        config.permittedInsecurePackages = [ "openssl-1.1.1w" ];
      };
      # nixpkgs currently carries gitleaks 8.30.1, whose default rules do not
      # detect canonical tokens (upstream issue #2170). Keep the regression
      # fixture in tests/secret_scan_test.sh before updating this pin.
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
        sing-box = networkingPkgs.sing-box;
      };

      homeConfigurations =
        let
          mkHome = extraModules: home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = { inherit llmAgentPkgs sops-nix; };
            modules = [
              ./home.nix
              { dotfiles.localProxy.package = networkingPkgs.sing-box; }
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
