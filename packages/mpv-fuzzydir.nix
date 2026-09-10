# fuzzydir is load-bearing rather than optional: configs/mpv/mpv.conf sets
# `sub-file-paths=**` and `audio-file-paths=**`, and the recursive `**` syntax
# is this script's, not mpv's. Without it both lines silently match nothing.
# Nixpkgs does not carry it.
{ lib, fetchFromGitHub, mpvScripts }:

mpvScripts.buildLua {
  pname = "mpv-fuzzydir";
  version = "0-unstable-2024-07-31";

  src = fetchFromGitHub {
    owner = "sibwaf";
    repo = "mpv-scripts";
    rev = "e4fb662207e024f26d7763c9551e429898267974";
    hash = "sha256-zD1C4+dor0hr2FnZi+8jJKm8EQ1zA/6WYopG+Bjs7/0=";
  };

  scriptPath = "fuzzydir.lua";

  meta = {
    description = "Recursive `**` wildcards for mpv's sub-file-paths and audio-file-paths";
    homepage = "https://github.com/sibwaf/mpv-scripts";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
