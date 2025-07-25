{ pkgs, lib, ... }:
let
  linux = lib.mkIf (pkgs.stdenv.isLinux) {
    services.podman = {
      enable = true;
      enableTypeChecks = true;

      autoUpdate.enable = true;
      autoUpdate.onCalendar = "Mon *-*-* 02:30";
    };
  };

  darwin = lib.mkIf (pkgs.stdenv.isDarwin) {
    home.packages = [
      pkgs.podman
      pkgs.podman-compose
    ];
  };
in
lib.mkMerge [
  darwin
  linux
]
