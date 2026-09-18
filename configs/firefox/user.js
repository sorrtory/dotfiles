// Alt alone toggles focus to the menu bar, which fires on the way to every
// Alt+Tab and Alt-chorded window-manager shortcut. Turning this off leaves
// the menu bar reachable by mouse or F10.
user_pref("ui.key.menuAccessKeyFocuses", false);

// Alt+<letter> opens the matching menu (Alt+E is Edit, Alt+F is File, ...),
// which collides with Alt-chorded shortcuts bound outside Firefox. 0 means
// no key triggers menu access keys; the menu bar itself is unaffected.
user_pref("ui.key.menuAccessKey", 0);

// Rewaita generates chrome/rewaitaChrome.css beside the machine-local
// profile. Firefox ignores userChrome.css unless the legacy customization
// switch is on; rounded GTK corners keep the generated GNOME frame coherent.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);

// PROXY.PAC decides routing (a self-discipline blocklist with a weekday
// exception). It is sops ciphertext at secrets/proxy.pac, decrypted by
// sops-nix to its stable symlink path (docs/DECISIONS.md, "Secrets and
// authentication"). PAC mode reads the file fresh on every request, so a
// rotated secret needs no Firefox restart, only re-activation.
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "file:///home/z/.config/sops-nix/secrets/proxy.pac");
user_pref("network.proxy.socks_remote_dns", true);
