{ nixosHyprland, ... }:
{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  xdg.portal = lib.mkIf (!nixosHyprland) {
    enable = true;
    xdgOpenUsePortal = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
    ];

    config = {
      common.default = [ "gtk" ];
      hyprland.default = [
        "gtk"
        "hyprland"
      ];
    };
  };
}
