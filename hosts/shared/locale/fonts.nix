{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    fontDir.decompressFonts = true;
    fontconfig.enable = true;

    packages = with pkgs; [
      # icon fonts
      material-design-icons
      font-awesome

      # Noto Fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      noto-fonts-extra

      # Adobe Fonts
      source-sans
      source-serif
      source-han-sans
      source-han-serif

      # Google Fonts
      google-fonts

      # Base fonts
      corefonts
      vistafonts
      liberation_ttf
      dejavu_fonts
      open-sans
      ubuntu_font_family

      # # Microsoft Fonts
      # (ttf-ms-win11.override { acceptEula = true; })

      # Nerdfonts
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "JetBrainsMono"
          "CascadiaCode"
          "Monaspace"
        ];
      })

      # Japanese fonts
      # Fonts from Arch Wiki: https://wiki.archlinux.org/title/Localization/Japanese
      ipafont
      ipaexfont
      hanazono
      mplus-outline-fonts.githubRelease
      kanji-stroke-order-font
    ];
  };
}
