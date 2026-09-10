{
  age,
  coreutils,
  gh,
  git,
  keepassxc,
  writeShellApplication,
}:

writeShellApplication {
  name = "recover-age-identity";
  excludeShellChecks = [ "SC2034" ];

  runtimeInputs = [
    age
    coreutils
    gh
    git
    keepassxc
  ];

  # A packaged build has no repository beside it, so point the script at store
  # copies of the two files it would otherwise read from the working tree. Only
  # the public recipient travels into the store this way; the private identity
  # is never part of the build.
  # Copied by content, so only these two files enter the store rather than the
  # whole flake source a path reference would drag in.
  runtimeEnv = {
    SOPS_CONFIG_LIB = builtins.toFile "sops-config.sh" (
      builtins.readFile ../scripts/bootstrap/common/sops-config.sh
    );
    SOPS_CONFIG_FILE = builtins.toFile "sops.yaml" (
      builtins.readFile ../.sops.yaml
    );
  };

  text = builtins.readFile ../scripts/repo/recover-age-identity.sh;
}
