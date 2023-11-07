# Reboot your NixOS with kexec

```bash
sudo nix run github:jeffguorg/nixos-kexec-profile
# or boot it
sudo nix run github:jeffguorg/nixos-kexec-profile -- -b
# or specify a nixos-config and boot it, either with a configuration.nix or flake.nix
sudo nix run github:jeffguorg/nixos-kexec-profile -- -b /workspace/nixos
```
