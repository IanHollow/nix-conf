{ lib, config, ... }@args:
let
  paths =
    [ config.home.profileDirectory ]
    ++ lib.optionals (args ? darwinConfig) args.darwinConfig.environment.profiles
    ++ lib.optionals (args ? nixosConfig) args.nixosConfig.environment.profiles;

  binPaths = lib.pipe paths [
    (builtins.map (p: "${p}/bin"))
    (builtins.map (
      builtins.replaceStrings
        [ "$USER" "$HOME" "\${XDG_STATE_HOME}" ]
        [ config.home.username config.home.homeDirectory config.xdg.stateHome ]
    ))
  ];
in
{
  programs.nushell.extraConfig = lib.mkAfter (
    # Emulate the nix PATH as best as possible
    ''
      $env.PATH = $env.PATH | split row (char esep) | prepend [
        ${lib.concatStringsSep "\n" (
          (lib.optionals (args ? nixosConfig) [ "/run/wrappers/bin" ]) ++ config.home.sessionPath ++ binPaths
        )}
      ]
    ''
    # The `path add` function from the Standard Library also provides
    # a convenience method for prepending to the path:
    + ''
      use std/util "path add"
      path add "~/.local/bin"
    ''
    # You can remove duplicate directories from the path using:
    + ''
      $env.PATH = ($env.PATH | uniq)
    ''
  );
}
