{
  pkgs,
  config,
  lib,
  tree,
  ...
}:
{
  # remove the default packages from the system closure
  # It is important the rest of the packages are not removed
  # as they are required to run the system at a base state.
  environment.defaultPackages = lib.mkForce [ ];

  # Packages which are appropriate for a typical Linux system.
  # There should be **no GUI programs** in this list.
  environment.systemPackages = [
    config.boot.kernelPackages.cpupower
    pkgs.nixos-rebuild-ng
  ];
}
