# Package migration

The package migration is split into small, ordered slices. The software catalog
is the human-readable installation index; each later slice updates it when
ownership moves into an implementation.

## Tickets

- [01: Create the software installation catalog](issues/01-create-software-installation-catalog.md) — resolved; produced [`docs/SOFTWARE.md`](../../docs/SOFTWARE.md).
- [02: Complete the standalone global CLI tools](issues/02-complete-standalone-cli-tools.md) — resolved; delivered the initial Home Manager package module.
- [03: Migrate the development baseline](issues/03-migrate-development-baseline.md) — ready-for-agent; blocked by 02.
- [04: Migrate FFmpeg and yt-dlp](issues/04-migrate-ffmpeg-and-yt-dlp.md) — ready-for-agent; blocked by 02.
- [05: Verify the package migration](issues/05-verify-package-migration.md) — ready-for-agent; blocked by 03 and 04.

## Context

- Ticket 01 established the [software installation catalog](../../docs/SOFTWARE.md) and linked it from the README and migration plan.
- Ticket 02 added the [standalone global CLI package module](../../modules/packages.nix), imported it from the Home Manager profile, and verified it on staging.
