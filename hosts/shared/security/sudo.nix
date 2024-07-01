{ pkgs, lib, ... }:
{
  security = {
    sudo = {
      enable = true;

      # WARNING: wheelNeedsPassword = false means wheel group can execute commands without a password
      # this is especially useful if you are using --target-host option in nixos-rebuild switch
      # however it's also a massive security flaw - which is why it should be replaced with the
      # extraRules you will see below
      wheelNeedsPassword = lib.mkDefault true;

      # only allow members of the wheel group to execute sudo
      # by setting the executable’s permissions accordingly
      execWheelOnly = lib.mkForce true;

      # additional sudo configuration
      extraConfig = ''
        Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
        Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
        Defaults env_keep += "EDITOR PATH DISPLAY" # variables that will be passed to the root account
        Defaults timestamp_timeout = 300 # makes sudo ask for password less often
      '';

      # additional sudo rules
      # this is a better approach for making certain commands sudo-less instead of
      # allowing the wheel users to run *anything* without password

      extraRules =
        let
          sudoRules = with pkgs; [
            {
              package = coreutils;
              command = "sync";
            }
            {
              package = hdparm;
              command = "hdparm";
            }
            {
              package = nixos-rebuild;
              command = "nixos-rebuild";
            }
            {
              package = nvme-cli;
              command = "nvme";
            }
            {
              package = systemd;
              command = "poweroff";
            }
            {
              package = systemd;
              command = "reboot";
            }
            {
              package = systemd;
              command = "shutdown";
            }
            {
              package = systemd;
              command = "systemctl";
            }
            {
              package = util-linux;
              command = "dmesg";
            }
          ];

          mkSudoRule = rule: {
            command = "${rule.package}/bin/${rule.command}";
            options = [ "NOPASSWD" ];
          };

          sudoCommands = map mkSudoRule sudoRules;
        in
        [
          {
            # allow wheel group to run nixos-rebuild without password
            # this is a less vulnerable alternative to having wheelNeedsPassword = false
            # whitelist switch-to-configuration, allows --target-host option
            # to deploy to remote servers without reading password from STDIN
            groups = [ "wheel" ];
            commands = sudoCommands;
          }
        ];
    };
  };
}
