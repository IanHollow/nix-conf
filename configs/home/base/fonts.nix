{ self, pkgs, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # icon fonts
    material-design-icons
    font-awesome

    # Noto Fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    noto-fonts-color-emoji
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
    liberation_ttf
    dejavu_fonts
    open-sans
    freefont_ttf
    gyre-fonts
    unifont
    roboto
    b612
    material-icons
    material-design-icons
    work-sans
    source-sans
    inter
    lato
    lexend

    # Emoji fonts
    twemoji-color-font
    openmoji-color
    openmoji-black

    # Microsoft Fonts
    (self.packages.${pkgs.system}.ttf-ms-win11-auto.override { acceptEula = true; })

    # Apple Fonts
    # TODO: fix the package to have stable links in some way and only enable it on non-Apple systems
    # self.packages.${pkgs.system}.apple-fonts

    # Nerdfonts
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    nerd-fonts.monaspace

    # Japanese fonts
    # Fonts from Arch Wiki: https://wiki.archlinux.org/title/Localization/Japanese
    ipafont
    ipaexfont
    hanazono
    mplus-outline-fonts.githubRelease
    kanji-stroke-order-font
  ];
}
