# Package migration

The package migration is split into small, ordered slices. The software catalog
is the human-readable installation index; each later slice updates it when
ownership moves into an implementation.

## Tickets

- [01: Create the software installation catalog](issues/01-create-software-installation-catalog.md) — resolved; produced [`docs/SOFTWARE.md`](../../docs/SOFTWARE.md).
- [02: Complete the standalone global CLI tools](issues/02-complete-standalone-cli-tools.md) — resolved; delivered the initial Home Manager package module.
- [03: Migrate the development baseline](issues/03-migrate-development-baseline.md) — resolved; delivered and verified the global compiler baseline.
- [04: Migrate FFmpeg and yt-dlp](issues/04-migrate-ffmpeg-and-yt-dlp.md) — resolved; delivered global FFmpeg and the verified release-binary phase.
- [05: Install Docker as explicit host setup](issues/05-install-docker-host-setup.md) — resolved; delivered and lifecycle-tested the privileged Docker phase.
- [06: Add the basic desktop applications](issues/06-add-basic-desktop-applications.md) — resolved; delivered and staging-verified the selected desktop application baseline.
- [07: Migrate VS Code native configuration](issues/07-migrate-vscode-native-configuration.md) — resolved; delivered reviewed live-editable settings, keybindings, and an extension inventory.
- [08: Migrate Sublime Text installation, configuration, and plugins](issues/08-migrate-sublime-configuration-and-plugins.md) — ready-for-agent; blocked by 06.
- [09: Verify the package migration](issues/09-verify-package-migration.md) — ready-for-agent; blocked by 06, 07, and 08.

## Context

- Ticket 01 established the [software installation catalog](../../docs/SOFTWARE.md) and linked it from the README and migration plan.
- Ticket 02 added the [standalone global CLI package module](../../modules/packages.nix), imported it from the Home Manager profile, and verified it on staging.
- Ticket 03 extended the [global package module](../../modules/packages.nix) with the pinned development baseline and verified representative builds on staging.
- Ticket 04 added FFmpeg to that module and introduced the reversible [yt-dlp bootstrap phase](../../scripts/bootstrap/05-yt-dlp.sh).
- Ticket 05 introduced the privileged [Docker bootstrap phase](../../scripts/bootstrap/06-docker.sh), including explicit group membership and full-reset uninstall behavior.
