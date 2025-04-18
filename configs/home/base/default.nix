{ config, pkgs, ... }:
{
  imports = [ ./misc.nix ];

  home.stateVersion = "25.05";

  ################
  ### PREAMBLE ###
  ################

  # fix for some display managers not using ~/.profile
  systemd.user.sessionVariables = config.home.sessionVariables;

  ####################################
  ### BASIC USER ENVIRONMENT SETUP ###
  ####################################
  xdg.enable = true;
  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;

  programs.home-manager.enable = true;

  # should already be enabled at system level
  # fontconfig required to make user-fonts by name
  # TODO: figure out how to make ~/.local/share/fonts
  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    BROWSER = "firefox";
    TERMINAL = "kitty";
    EDITOR = "nvim";
  };

  home.packages = [
    pkgs.kdePackages.qtwayland
  ];
}
