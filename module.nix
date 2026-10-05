# programs.wayseer: installs Wayseer for every user, with the GPU drivers it draws through.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.wayseer;
in
{
  options.programs.wayseer = {
    enable = lib.mkEnableOption "Wayseer";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "desktop-nix.packages.\${system}.default";
      description = "The Wayseer package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    hardware.graphics.enable = lib.mkDefault true;
  };
}
