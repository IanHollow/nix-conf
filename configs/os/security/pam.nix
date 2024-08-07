{
  security = {
    pam = {
      # fix "too many files open" errors while writing a lot of data at once
      # (e.g. when building a large package)
      # if this, somehow, doesn't meet your requirements you may just bump the numbers up
      loginLimits = [
        {
          domain = "@wheel";
          item = "nofile";
          type = "soft";
          value = "524288";
        }
        {
          domain = "@wheel";
          item = "nofile";
          type = "hard";
          value = "1048576";
        }
      ];

      # allow screen lockers to also unlock the screen
      # (e.g. swaylock, gtklock)
      # Also unlock GPG keyring on login
      services =
        let
          gnupg = {
            enable = true;
            noAutostart = true;
            storeOnly = true;
          };
        in
        {
          login = {
            enableGnomeKeyring = true;
            inherit gnupg;
          };

          greetd = {
            enableGnomeKeyring = true;
            inherit gnupg;
          };

          tuigreet = {
            enableGnomeKeyring = true;
            inherit gnupg;
          };

          swaylock.text = "auth include login";
          gtklock.text = "auth include login";
        };
    };
  };
}
