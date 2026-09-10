# The `osc` branch of thumbfast: mpv's own OSC with thumbnail support added.
# It is what draws `mpvScripts.thumbfast`'s output — without it thumbfast loads,
# runs, and shows nothing. Nixpkgs packages thumbfast but not this fork.
#
# No `osc=no` is needed in mpv.conf: the script's first statement sets that
# property itself and reloads under the `osc` script name once the builtin has
# unloaded. That reclaim matches on a path ending in `osc.lua`, which is the
# name buildLua installs it under.
{ lib, fetchFromGitHub, mpvScripts }:

mpvScripts.buildLua {
  pname = "mpv-thumbfast-osc";
  version = "0-unstable-2025-02-04";

  src = fetchFromGitHub {
    owner = "po5";
    repo = "thumbfast";
    rev = "9d78edc167553ccea6290832982d0bc15838b4ac";
    hash = "sha256-AG3w5B8lBcSXV4cbvX3nQ9hri/895xDbTsdaqF+RL64=";
  };

  scriptPath = "player/lua/osc.lua";

  meta = {
    description = "mpv's vanilla OSC with thumbfast thumbnail previews";
    homepage = "https://github.com/po5/thumbfast/tree/osc";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.all;
  };
}
