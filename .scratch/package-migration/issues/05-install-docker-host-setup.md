# 05: Install Docker as explicit host setup

**What to build:** Provide Docker Engine, Compose, and Buildx through an explicit privileged bootstrap phase, including Docker group membership for the invoking user, without placing host integration in Home Manager.

**Blocked by:** 04/Migrate FFmpeg and the stable yt-dlp exception.

**Status:** resolved

- [x] Status is read-only and network-free and checks the Docker CLI, Compose, Buildx, and target-user Docker group membership.
- [x] Installation downloads the official Docker convenience installer over HTTPS, shows its dry-run package plan, and then invokes it explicitly with `sudo`.
- [x] Installation runs `sudo usermod -aG docker "$USER"` in effect, using a resolved target-user name rather than trusting an inherited environment value.
- [x] The phase is idempotent and repairs missing group membership without reinstalling Docker.
- [x] Explicit uninstall removes group membership, known Docker packages, repository configuration, `/var/lib/docker`, and `/var/lib/containerd` regardless of how Docker was installed.
- [x] Unit tests cover absent, partial, already-satisfied, complete-install, destructive uninstall, and repeated-uninstall states.
- [x] Docker Engine, Compose, Buildx, group membership, and a disposable container smoke test pass on staging.
- [x] The destructive uninstall, clean reinstall, and post-reinstall container smoke test pass in a direct staging terminal with normal sudo prompting.
- [x] The software catalog and bootstrap documentation link Docker to its installation definition and note that a new login is required.
- [x] No host activation or legacy installer removal occurs before operator review.

## Answer

`06-docker` skips a complete existing installation, repairs missing target-user group membership separately, and otherwise downloads one official installer copy, previews that copy with `--dry-run`, runs it with `sudo`, and applies `sudo usermod -aG docker <resolved-user>`. Its explicitly destructive uninstall removes group membership, known packages, repository configuration, and all local Docker and containerd data. Unit tests exercise the full absent-state mutation and reset paths. The official installer dry-run succeeded on staging, and Docker Engine 29.8.0, Compose 5.5.1, Buildx 0.37.0, group membership, daemon access, and `hello-world` all passed. The operator subsequently verified the destructive uninstall and clean reinstall lifecycle directly on staging.
