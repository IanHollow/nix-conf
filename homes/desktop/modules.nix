{
  tree,
  pkgs,
  inputs,
  ...
}:
let
  homeDir = tree.configs.home;
  sharedDir = tree.configs.shared;
  install = pkg: { home.packages = [ pkg ]; };
in
with (homeDir // homeDir.programs // homeDir.programs.editors);
[
  ## Base
  base
  ./hardware
  ./secrets.nix
  (base.mime { })

  ## Theming
  theming.basic
  theming.gtk
  {
    # Firefox
    # TODO: rethink if this is the best place to add this option as it becomes a manual process
    stylix.targets.firefox.profileNames = [ "default" ];
  }

  ## Desktop Environment
  desktop-envs.hyprland
  ./hyprland
  { stylix.targets.hyprland.enable = false; }

  ## Desktop Applications
  programs.rofi
  programs.waybar
  # programs.ags
  (install pkgs.nautilus)
  (install pkgs.apostrophe)
  (install pkgs.motrix)
  (install pkgs.pinta)

  ## Utility
  programs.gparted

  ## Web Browsers
  programs.firefox
  { programs.chromium.enable = true; }

  ## Shell Environments
  shells.zsh

  ## Terminal Emulators
  programs.kitty

  ## Development Tools
  programs.git
  programs.ssh
  dev.docs
  dev.direnv
  dev.github-cli
  dev.nix-formatter

  ## Development Languages
  dev.languages.c
  dev.languages.python

  ## Code Editors
  # neovim

  vscode.settings
  vscode.languages.cpp
  vscode.languages.esp-idf
  vscode.languages.nix
  vscode.languages.web
  vscode.languages.python
  vscode.languages.bash
  vscode.languages.verilog
  vscode.languages.javascript
  vscode.languages.typescript
  vscode.languages.docker
  vscode.languages.spice

  ## Communication
  programs.discord
  (install pkgs.slack)

  ## Media Consumption
  programs.spotify
  (install pkgs.rhythmbox)

  ## Office Software
  programs.libreoffice
  (install pkgs.obsidian)
  (install pkgs.kdePackages.okular)
  (install inputs.geospatial-nix.packages.${pkgs.system}.qgis)

  ## Video Games
  gaming
  (install pkgs.prismlauncher)
  (install pkgs.lutris)

  ## Misc
  # { home.sessionVariables = sharedDir.env.wayland.default; }
  # wayland.electron-flags
]
