# Partially based off of this guide <https://ayats.org/blog/channels-to-flakes/>
# In this modudle each flake is piped from the inputs to the flake registry
# This allows for channels to use flake inputs instead of channels
# and for the flake Nix commands to use the flake registry defined here
# This website <https://teu5us.github.io/nix-lib.html> is good for understanding
# how the different lib functions work
{ lib, inputs, ... }:
lib.pipe inputs [
  (lib.filterAttrs (name: value: value ? _type && value._type == "flake"))
  (lib.mapAttrsToList (
    name: input: {
      environment.etc."nix/inputs/${name}".source = input.outPath;
      nix.nixPath = [ "${name}=/etc/nix/inputs/${name}" ];
      nix.registry.${name}.flake = input;
    }
  ))
  lib.mkMerge
]