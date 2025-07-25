profileName:
{
  pkgs,
  ...
}:
{
  programs.firefox.profiles.${profileName}.search = {
    force = true;

    default = "ddg";
    privateDefault = "ddg";

    engines = {
      nix-packages = {
        name = "Nix Packages";
        urls = [
          {
            template = "https://search.nixos.org/packages";
            params = [
              {
                name = "type";
                value = "packages";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        definedAliases = [
          "@nixpkgs"
          "@np"
        ];
      };

      nixos-wiki = {
        name = "NixOS Wiki";
        urls = [
          {
            template = "https://wiki.nixos.org/w/index.php";
            params = [
              {
                name = "search";
                value = "{searchTerms}";
              }
            ];
          }
        ];
        icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        definedAliases = [
          "@nixos-wiki"
          "@nw"
        ];
      };

      bing.metaData.hidden = true;
      ebay.metaData.hidden = true;
    };
  };
}
