{ pkgs }:
{
  claude-desktop = pkgs.callPackage ./claude-desktop { };
  anthropic-skills = pkgs.callPackage ./anthropic-skills { };
  openai-codex-desktop = pkgs.callPackage ./openai-codex-desktop { };
  openai-skills = pkgs.callPackage ./openai-skills { };
  microsoft-teams = pkgs.callPackage ./microsoft-teams { };
  remindctl = pkgs.callPackage ./remindctl { };
  spicetify-cli-fixed = pkgs.callPackage ./spicetify-cli-fixed { };
  steam = pkgs.callPackage ./steam { };
  ttf-ms-win11-auto = pkgs.callPackage ./ttf-ms-win11-auto { };
  libreoffice = pkgs.callPackage ./libreoffice { };
}
// pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
  spotify-spotx = pkgs.callPackage ./spotify-spotx { };
}
