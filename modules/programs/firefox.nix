{ config, lib, pkgs, ... }:

let
  # Everything in the file is live-editable except the one preference the
  # theme owns: page transparency follows dotfiles.theme.transparency, since
  # clearing page backgrounds only makes sense behind a translucent window.
  userJs = pkgs.writeText "user.js" (builtins.readFile ../../configs/firefox/user.js + ''

    // Managed by modules/theme: lets page content show the translucent window
    // behind it instead of an opaque canvas. chrome/userContent.css
    // (configs/firefox/userContent.css) then clears the page backgrounds.
    user_pref("browser.tabs.allow_transparent_browser", ${lib.boolToString config.dotfiles.theme.transparency});
  '');
  userContentCss = ../../configs/firefox/userContent.css;
in
{
  # proxy.pac carries no credentials, but it is a personal blocklist and this
  # repository is public, so it is sops ciphertext like the WireGuard configs
  # rather than a plaintext file. Declared here, next to the one thing that
  # reads it, rather than in modules/secrets.nix, matching how sing-box
  # declares its own WireGuard identity locally.
  sops.secrets."proxy.pac" = {
    sopsFile = ../../secrets/proxy.pac;
    format = "binary";
  };

  # The profile directory's name is random, so it cannot be a static
  # xdg.configFile target the way configs/nvim is. This globs for it instead
  # and symlinks the same live-editable file in, mirroring what the neovim
  # module does for a stable path: Nix owns nothing about the prefs' content,
  # only that the link exists.
  home.activation.firefoxUserJs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    shopt -s nullglob
    profiles=("$HOME"/.config/mozilla/firefox/*.default*/)
    if [[ ''${#profiles[@]} -eq 0 ]]; then
      warnEcho "No Firefox profile found yet; run Home Manager activation again after Firefox has launched once to link user.js."
    fi
    for profile in "''${profiles[@]}"; do
      target="''${profile}user.js"
      if [[ -e $target && ! -L $target ]]; then
        run mv $VERBOSE_ARG "$target" "$target.pre-home-manager"
      fi
      run ln -sf $VERBOSE_ARG ${userJs} "$target"

      # Rewaita owns userChrome.css; page styling is ours alone.
      run mkdir -p $VERBOSE_ARG "''${profile}chrome"
      run ln -sf $VERBOSE_ARG ${userContentCss} "''${profile}chrome/userContent.css"
    done
  '';
}
