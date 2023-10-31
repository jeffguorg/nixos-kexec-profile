{ substituteAll, lib, coreutils, jq, kexec-tools, runtimeShell, installShellFiles, ... }: substituteAll {
  name = "nixos-kexec-profile";
  src = ./nixos-kexec-profile.sh;
  dir = "bin";
  isExecutable = true;

  path = lib.makeBinPath [ coreutils jq kexec-tools ];
  inherit runtimeShell;

  nativeBuildInputs = [
    installShellFiles
  ];

  meta = {
    description = "kexec into a NixOS profile";
    homepage = "https://github.com/jeffguorg/nixos-kexec-profile";
    licenses = lib.license.gpl;
    mainProgram = "nixos-kexec-profile";
  };
}
