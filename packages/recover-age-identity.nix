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

  text = builtins.readFile ../scripts/repo/recover-age-identity.sh;
}
