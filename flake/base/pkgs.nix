{ inputs, ... }: {
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      _module.args.pkgs = pkgs;
      packages = inputs.nixpkgs-personal.packages.${system};
    };
}
