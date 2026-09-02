{
  description = "Cross-distro Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ gitleaks ];
      };

      homeConfigurations.z = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
