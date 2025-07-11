# Nix Configuration

This repository contains my personal Nix flake used to manage both NixOS and macOS systems. It also defines collections of Home‑Manager modules and a few custom packages.

The flake makes heavy use of **flake-parts** to break the configuration into smaller pieces. Hosts and homes are constructed using helper functions under `parts/lib`.

## Directory layout

- `hosts/` – Host specific NixOS or Darwin configurations
- `homes/` – Home‑Manager setups for each user and host
- `configs/` – Reusable modules shared by hosts and homes
- `_nixOSModules/` – Standalone NixOS modules exported by the flake
- `_homeModules/` – Standalone Home Manager modules exported by the flake
- `pkgs/` – Custom package definitions
- `parts/` – flake-parts modules and helper libraries

## Requirements

- Nix with flakes enabled
- Optional: [agenix](https://github.com/ryantm/agenix) for secrets

## Building a host

```bash
# NixOS
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# macOS (nix-darwin)
nix build .#darwinConfigurations.<host>.system
```

Replace `<host>` with one of the directories under `hosts/`.

The resulting build can be switched to with `sudo nixos-rebuild switch --flake .#<host>` on Linux or `darwin-rebuild switch --flake .#<host>` on macOS.

## Home Manager only

Home Manager configurations are located under `homes/`. Each host imports one of these collections. To use a home setup standalone you can build:

```bash
nix build .#homeManagerModules.<module>
```

## Secrets

Some configurations expect encrypted secrets from my private [nix-secrets](https://github.com/IanHollow/nix-secrets) repository managed with agenix. If you do not have access to that repo, you can remove the `secrets.nix` imports from the corresponding host/home.

## Custom packages

A few small packages are provided under `pkgs/`. They can be built via `nix build .#<package>`.

---

This flake is a work in progress and may change frequently. Feel free to explore the modules and reuse anything that looks helpful!
