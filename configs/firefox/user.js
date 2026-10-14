// Alt alone toggles focus to the menu bar, which fires on the way to every
// Alt+Tab and Alt-chorded window-manager shortcut. Turning this off leaves
// the menu bar reachable by mouse or F10.
user_pref("ui.key.menuAccessKeyFocuses", false);

// Alt+<letter> opens the matching menu (Alt+E is Edit, Alt+F is File, ...),
// which collides with Alt-chorded shortcuts bound outside Firefox. 0 means
// no key triggers menu access keys; the menu bar itself is unaffected.
user_pref("ui.key.menuAccessKey", 0);

// Ctrl+T and the new-tab button insert immediately after the active tab.
user_pref("browser.tabs.insertAfterCurrent", true);

// Show tabs vertically in Firefox's revamped sidebar.
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);

// Rewaita generates chrome/rewaitaChrome.css beside the machine-local
// profile. Firefox ignores userChrome.css unless the legacy customization
// switch is on; rounded GTK corners keep the generated GNOME frame coherent.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);

// PROXY.PAC decides routing and the local-time peek schedule. It is sops
// ciphertext at secrets/proxy.pac, decrypted by sops-nix to its stable symlink
// path (docs/DECISIONS.md, "Secrets and authentication"). Firefox keeps the PAC
// JavaScript context between routing decisions. After activation updates the
// file, use Reload in Firefox's Network Settings, or restart Firefox, to load
// it. Reloading or restarting also resets the in-memory peek allowance.
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "file:///home/z/.config/sops-nix/secrets/proxy.pac");
user_pref("network.proxy.socks_remote_dns", true);
