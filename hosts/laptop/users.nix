{
  lib,
  tree,
  ...
}: {
  imports =
    # Set the mainUser
    [{users.mainUser = "ianmh";}]
    # Add Users
    ++ (
      with lib.cust.nixos; let
        homeConfigs = tree.home.configs;
      in [
        (addUser {
          username = "ianmh";
          description = "Ian Holloway";
          extraGroups = [
            "wheel"
            "audio"
            "video"
          ];
          initialPassword = "password";
          homeModules = homeConfigs.laptop.modules {inherit tree lib;};
        })

        # (addUser {
        #   username = "guest";
        #   description = "Guest User";
        #   extraGroups = [
        #     "audio"
        #     "video"
        #   ];
        #   initialPassword = "password";
        #   homeModules = homeConfigs.desktop.modules { inherit tree; };
        # })
      ]
    );
}