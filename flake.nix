{
  description = "Wayseer Desktop for Nix: nix run github:wayseer-net/desktop-nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      release = import ./release.nix; # written by scripts/bump.sh
      # This flake's own package set accepts Wayseer's terms, and no other unfree package's.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = p: nixpkgs.lib.getName p == "wayseer";
      };
      wayseerFrom = p: p.callPackage ./package.nix {
        inherit (release) version;
        src = p.fetchurl { inherit (release) url hash; };
      };
    in
    {
      packages.${system}.default = wayseerFrom pkgs;
      overlays.default = final: _prev: { wayseer = wayseerFrom final; };
      nixosModules.default = import ./module.nix self;
      checks.${system} = import ./checks.nix { inherit pkgs self nixpkgs; };
    };
}
