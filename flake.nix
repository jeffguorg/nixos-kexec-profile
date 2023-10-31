{
  description = "kexec into nixos profile";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux = rec {
      nixos-kexec-profile = nixpkgs.legacyPackages.x86_64-linux.pkgs.callPackage ./default.nix {};
      default = nixos-kexec-profile;
    };
  };
}
