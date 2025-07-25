{
  description = "Ian's Nix Configuration";

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        # Parts of the flake that are used to construct the final flake.
        imports = [ ./parts ];

        # Systems for which the attributes of `perSystem` will be built
        # add more if they can be supported...
        #  - x86_64-linux: Desktops, laptops, servers
        #  - aarch64-linux: ARM-based devices, PoC server and builders
        #  - ...
        systems = import inputs.systems;

        # PerSystem attributes that are built for each system.
        perSystem =
          { system, ... }:
          let
            inherit (inputs.self) lib;
            inherit (lib.cust.files) importDirRec;

            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          {
            # Set each package with the correct dependencies
            packages = builtins.mapAttrs (folderName: pkg: pkgs.callPackage pkg { }) (importDirRec ./pkgs [ ]);
          };

        flake =
          let
            inherit (inputs.self) lib;
            inherit (lib.cust.builders) mkHost mkDarwin;
            inherit (lib.cust.files) importDirRec;

            hostConfigsDir = ./hosts;
            excludes = [ ];
            hostConfigs = importDirRec hostConfigsDir excludes;

            baseConfigParams = folderName: {
              inherit withSystem;
              inherit inputs;
              inherit (inputs) self determinate;
              inherit (inputs.self) lib tree;
              inherit folderName;
            };

            configParameterize =
              folderName: configDef:
              lib.pipe folderName [
                baseConfigParams
                (x: (configDef x) // x)
              ];

            isSystem =
              systemTypes: finalConfigParams:
              lib.pipe finalConfigParams [
                (builtins.getAttr "system")
                (lib.splitString "-")
                (x: lib.flip lib.elemAt ((builtins.length x) - 1) x)
                (lib.flip builtins.elem systemTypes)
              ];

            mkConfig =
              builder: systemTypes:
              lib.pipe hostConfigs [
                (lib.mapAttrs configParameterize)
                (lib.filterAttrs (_: isSystem systemTypes))
                (lib.mapAttrs (_: builder))
              ];
          in
          {
            # Entry-point for NixOS configurations.
            nixosConfigurations = mkConfig mkHost [ "linux" ];

            # Entry point for Darwin configurations.
            darwinConfigurations = mkConfig mkDarwin [ "darwin" ];

            # NixOS Modules
            nixOSModules = importDirRec ./_nixOSModules [ ];

            # Home Manager Modules
            homeManagerModules = importDirRec ./_homeModules [ ];
          };
      }
    );

  inputs = {
    # Systems
    systems.url = "github:nix-systems/default";

    # Latest Nixpkgs Unstable
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    # Determinate
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";

    # Flake Parts
    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/*";

    # Latest Home Manager
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix-Darwin
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
      };
    };

    # Nix Secrets (from personal private repo)
    nix-secrets = {
      url = "git+ssh://git@github.com/IanHollow/nix-secrets.git?shallow=1";
      flake = false;
    };

    # NUR
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/*";

    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/*";

    # A tree-wide formatter
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spicetify for theming spotify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

    # Nix Language Server
    nixd = {
      url = "https://flakehub.com/f/nix-community/nixd/*";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Nix Direnv
    nix-direnv = {
      url = "https://flakehub.com/f/nix-community/nix-direnv/*";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Stylix
    stylix = {
      url = "https://flakehub.com/f/danth/stylix/*";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "flake-parts";
        nur.follows = "nur";
      };
    };

    # VS Code
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Nix gaming
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs = {
        flake-parts.follows = "flake-parts";
        # Don't overwrite nixpkgs as this could cause cache miss
      };
    };

    # Firefox BetterFox
    # TODO: use a package instead of a flake
    firefox-betterfox = {
      url = "github:yokoffing/Betterfox";
      flake = false;
    };

    # Firefox Arkenfox
    # TODO: use a package instead of a flake
    firefox-arkenfox = {
      url = "github:arkenfox/user.js";
      flake = false;
    };

    # Firefox UI Fix
    # TODO: use a package instead of a flake
    firefox-ui-fix = {
      url = "github:black7375/Firefox-UI-Fix";
      flake = false;
    };

    # Nix Minecraft
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "flake-compat";
      };
    };

    # Provide NixGL for Geospatial Nix
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Geospatial Nix
    geospatial-nix = {
      url = "https://flakehub.com/f/imincik/geospatial-nix/*";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixgl.follows = "nixgl";

        # Don't overwrite nixpkgs as this could cause cache miss
      };
    };

    # Nixvim
    nixvim = {
      url = "https://flakehub.com/f/nix-community/nixvim/*";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    # Cosmic Desktop
    cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs = {
        flake-compat.follows = "flake-compat";
        # Don't overwrite nixpkgs as this could cause cache miss
      };
    };

    # Hyprland Flake
    aquamarine = {
      url = "github:hyprwm/aquamarine";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprutils.follows = "hyprutils";
      inputs.hyprwayland-scanner.follows = "hyprwayland-scanner";
    };

    hyprcursor = {
      url = "github:hyprwm/hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprlang.follows = "hyprlang";
    };

    hyprgraphics = {
      url = "github:hyprwm/hyprgraphics";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprutils.follows = "hyprutils";
    };

    hyprland-protocols = {
      url = "github:hyprwm/hyprland-protocols";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    hyprland-qt-support = {
      url = "github:hyprwm/hyprland-qt-support";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprlang.follows = "hyprlang";
    };

    hyprland-qtutils = {
      url = "github:hyprwm/hyprland-qtutils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprlang.follows = "hyprlang";
      inputs.hyprutils.follows = "hyprutils";
      inputs.hyprland-qt-support.follows = "hyprland-qt-support";
    };

    hyprlang = {
      url = "github:hyprwm/hyprlang";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprutils.follows = "hyprutils";
    };

    hyprutils = {
      url = "github:hyprwm/hyprutils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    hyprwayland-scanner = {
      url = "github:hyprwm/hyprwayland-scanner";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    xdph = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.hyprland-protocols.follows = "hyprland-protocols";
      inputs.hyprlang.follows = "hyprlang";
      inputs.hyprutils.follows = "hyprutils";
      inputs.hyprwayland-scanner.follows = "hyprwayland-scanner";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };

    hyprland = {
      url = "https://flakehub.com/f/hyprwm/Hyprland/*";
      # inputs = {
      #   nixpkgs.follows = "nixpkgs";
      #   systems.follows = "systems";

      #   aquamarine.follows = "aquamarine";
      #   hyprcursor.follows = "hyprcursor";
      #   hyprgraphics.follows = "hyprgraphics";
      #   hyprland-protocols.follows = "hyprland-protocols";
      #   hyprland-qtutils.follows = "hyprland-qtutils";
      #   hyprlang.follows = "hyprlang";
      #   hyprutils.follows = "hyprutils";
      #   hyprwayland-scanner.follows = "hyprwayland-scanner";
      #   xdph.follows = "xdph";
      #   pre-commit-hooks.follows = "pre-commit-hooks";
      # };
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";

        hyprutils.follows = "hyprutils";
        hyprlang.follows = "hyprlang";
        hyprwayland-scanner.follows = "hyprwayland-scanner";
        hyprgraphics.follows = "hyprgraphics";
      };
    };

    hyprlock = {
      url = "github:hyprwm/hyprlock";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";

        hyprutils.follows = "hyprutils";
        hyprlang.follows = "hyprlang";
        hyprwayland-scanner.follows = "hyprwayland-scanner";
        hyprgraphics.follows = "hyprgraphics";
      };
    };

    lib-aggregate = {
      url = "github:nix-community/lib-aggregate";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs-lib.follows = "nixpkgs";
      };
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs = {
        # Don't overwrite nixpkgs as this could cause cache miss

        lib-aggregate.follows = "lib-aggregate";
        flake-compat.follows = "flake-compat";
      };
    };

    # AMD microcode updates
    ucodenix.url = "github:e-tho/ucodenix";

    # Agenix
    # agenix = {
    #   url = "github:ryantm/agenix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Ags
    # ags = {
    #   url = "github:Aylur/ags";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.astal.follows = "astal";
    # };
    # astal = {
    #   url = "github:Aylur/astal";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    nix-index = {
      url = "github:nix-community/nix-index";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  # nixConfig = {
  #   extra-substituters = [
  #     "https://cache.nixos.org" # official nix cache
  #     "https://nix-community.cachix.org" # nix-community cache
  #     "https://nixpkgs-unfree.cachix.org" # unfree-package cache
  #     # "https://cache.garnix.io" # garnix binary cache
  #     "https://geonix.cachix.org" # geospatial nix
  #     "https://nix-gaming.cachix.org" # nix-gaming cache
  #     "https://cosmic.cachix.org" # cosmic desktop
  #     "https://hyprland.cachix.org" # hyprland cache
  #     "https://nixpkgs-wayland.cachix.org" # nixpkgs wayland cache
  #   ];

  #   extra-trusted-public-keys = [
  #     "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  #     "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  #     "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
  #     # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  #     "geonix.cachix.org-1:iyhIXkDLYLXbMhL3X3qOLBtRF8HEyAbhPXjjPeYsCl0="
  #     "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
  #     "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
  #     "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  #     "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
  #   ];
  # };
}
