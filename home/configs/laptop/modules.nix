{ tree, lib, ... }:
with tree.home.configs.shared;
[
  theming.basic.default

  desktop-envs.hyprland.default
  programs.rofi
  programs.waybar.default
  ./hyprland

  { home.sessionVariables = lib.cust.env.wayland.all; }

  profile
]
