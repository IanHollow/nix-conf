{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  cfg = config.hardware.intelgpu;
in
{
  options.hardware.intelgpu = {
    enable = lib.mkEnableOption "Enable intelgpu support";

    # Enable GuC Submission
    guc = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable GuC Submission.
        Supported by Alder Lake-P (Mobile) and newer (Gen12+).
        Despite Intel's documentation Tiger Lake & Rocket Lake (Gen11) support GuC Submission.
        Read https://wiki.archlinux.org/title/intel_graphics#Enable_GuC_/_HuC_firmware_loading before enabling.
      '';
    };

    # Enable HuC Firmware Loading
    huc = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable HuC Firmware Loading. Supported by Gen9 Intel and above.
        Read https://wiki.archlinux.org/title/intel_graphics#Enable_GuC_/_HuC_firmware_loading before enabling.
      '';
    };
  };

  config =
    let
      driver =
        if (lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.8") then "xe" else "i915";
    in
    lib.mkIf cfg.enable {

      boot.initrd.kernelModules = [ driver ];

      environment.variables = {
        VDPAU_DRIVER = lib.mkIf config.hardware.graphics.enable (lib.mkDefault "va_gl");
      };

      hardware.graphics = {
        enable = true;

        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
          vpl-gpu-rt
        ];

        extraPackages32 = with pkgs.pkgsi686Linux; [ intel-media-driver ];
      };

      # Guc and HuC
      # DOCS: https://wiki.archlinux.org/title/intel_graphics#Enable_GuC_/_HuC_firmware_loading
      # NOTE: GuC and HuC are enabled by default on Alder Lake-P (Mobile) and newer (Gen12+).
      # Despite Intel's documentation Tiger Lake & Rocket Lake (Gen11) should support GuC and HuC
      #       but it is not enabled by default and instead only has GuC Submission enabled by default.
      # WARNING: Manually enabling GuC / HuC firmware loading taints the kernel even when the feature is not supported.
      #          Moreover, enabling GuC/HuC firmware loading can cause issues on some systems;
      #          disable it if you experience freezing (for example, after resuming from hibernation).
      boot.kernelParams =
        let
          # Value based on documentation from https://wiki.archlinux.org/title/intel_graphics#Enable_GuC_/_HuC_firmware_loading
          value =
            # 3 = GuC and HuC
            if (cfg.guc && cfg.huc) then
              "3"
            # 1 = GuC only
            else if (cfg.guc && !cfg.huc) then
              "1"
            # 2 = HuC only
            else if (cfg.huc && !cfg.guc) then
              "2"
            # this option will never happen as this module is only enabled if either GuC or HuC is enabled
            else
              "0";
        in
        lib.mkIf ((cfg.guc || cfg.huc) && driver == "i915") [ "i915.enable_guc=${value}" ];
    };
}
