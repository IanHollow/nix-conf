{ config, lib, ... }:
{
  username,
  homeDirectory ? "/home/${username}",
  description ? "",
  extraGroups ? [ ],
  initialPassword ? "password",
  isNormalUser ? true,
  homeManagerModules ? ({ ... }: [ ]),
}:
lib.mkMerge [
  {
    users.users.${username} = {
      inherit
        description
        extraGroups
        initialPassword
        isNormalUser
        ;
      home = lib.mkForce homeDirectory;
    };
  }

  (lib.mkIf (config.users ? normalUsers) {
    # Add user to custom normalUsers list
    users.normalUsers = [
      {
        inherit username;
        home = homeDirectory;
      }
    ];
  })

  (lib.mkIf (config ? home-manager) {
    home-manager.users.${username} =
      {
        tree,
        lib,
        pkgs,
        inputs,
        self,
        ...
      }:
      {
        # import home-manager modules and resolve function
        # NOTE: withTreeModules shouldn't cause issues if tree modules aren't used
        imports = lib.cust.withTreeModules (homeManagerModules {
          inherit
            tree
            lib
            pkgs
            inputs
            self
            ;
        });

        # Use the same nix package as nixos
        nix.package = lib.mkForce config.nix.package;

        # Allow HM to manage itself when in standalone mode.
        # This makes the home-manager command available to users.
        programs.home-manager.enable = true;

        # Disable home-manager man-pages to save space
        manual = {
          manpages.enable = false;
          html.enable = false;
          json.enable = false;
        };

        # Set default settings based on the nixos settings
        home = {
          username = lib.mkForce username;
          homeDirectory = lib.mkForce homeDirectory;
        };
      };
  })
]
