# What `nix flake check` runs: the scripts' lint and tests, the package built from an invented
# tarball, and the NixOS module. None of it needs the network.
{ pkgs, self, nixpkgs }:

let
  fakeApp = pkgs.runCommandCC "wayseer-fake-app" { } "cc -O2 -o $out ${./tests/fake-app.c}";
  invented = pkgs.runCommand "wayseer-1.0.0-linux-x86_64.tar.gz" { } ''
    bash ${./tests/invent-tarball.sh} ${fakeApp} $out
  '';
  package = pkgs.callPackage ./package.nix { version = "1.0.0"; src = invented; };
  inventedOld = pkgs.runCommand "wayseer-0.27.1-linux-x86_64.tar.gz" { } ''
    bash ${./tests/invent-tarball.sh} ${fakeApp} $out --old
  '';
  refused = pkgs.testers.testBuildFailure
    (pkgs.callPackage ./package.nix { version = "0.27.1"; src = inventedOld; });
  nixos = nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.default
      { nixpkgs.hostPlatform = "x86_64-linux"; programs.wayseer.enable = true; }
    ];
  };
  installed = nixos.config.environment.systemPackages;
in
{
  scripts = pkgs.runCommand "wayseer-scripts-check" { nativeBuildInputs = [ pkgs.shellcheck pkgs.openssl ]; } ''
    cd ${self}
    shellcheck -x scripts/*.sh tests/*.sh wrapper.sh
    bash tests/bump_test.sh
    touch $out
  '';

  package = pkgs.runCommand "wayseer-package-check" { } ''
    bash ${./tests/package_test.sh} ${package} ${invented}
    touch $out
  '';

  # 0.27.1 has no launcher layout, and its app takes the loader for itself.
  old-release = pkgs.runCommand "wayseer-old-release-check" { } ''
    grep -q "Wayseer 0.27.1 predates the layout this package runs" ${refused}/testBuildFailure.log
    touch $out
  '';

  module =
    assert pkgs.lib.assertMsg (builtins.elem self.packages.x86_64-linux.default installed)
      "programs.wayseer.enable installs the package";
    assert pkgs.lib.assertMsg nixos.config.hardware.graphics.enable
      "programs.wayseer.enable turns on the GPU drivers";
    pkgs.runCommand "wayseer-module-check" { } "touch $out";
}
