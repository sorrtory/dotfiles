# The plugin behind Yazi's `Ctrl+y` and `Alt+Shift+Y`, at the revision
# configs/yazi/package.toml records. Nixpkgs carries a few dozen Yazi plugins
# but not this one, and its upstream repository holds three unrelated plugins,
# so the install phase takes only the one directory.
#
# This is deliberately newer than the revision the legacy manager had restored:
# only from this revision does the plugin take a `plain` or `multi` argument,
# which is what lets one key copy contents bare and another copy them behind
# each file's path in a code fence.
{ lib, fetchFromGitHub, mkYaziPlugin }:

mkYaziPlugin {
  pname = "copy-file-contents.yazi";
  version = "0-unstable-2026-08-07";

  src = fetchFromGitHub {
    owner = "AnirudhG07";
    repo = "plugins-yazi";
    rev = "3f4f1a3ea58707ce87b6455ebc25e7954b261e43";
    hash = "sha256-hNw+1BRVHPR1LgUE6MYtnJEAO4fhSI3m+3M8wzw53UQ=";
  };

  installPhase = ''
    runHook preInstall

    cp -r copy-file-contents.yazi $out

    runHook postInstall
  '';

  meta = {
    description = "Copy the contents of the selected files to the clipboard";
    homepage = "https://github.com/AnirudhG07/plugins-yazi";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
