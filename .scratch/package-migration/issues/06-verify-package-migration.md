# 06: Verify the current package migration

**What to build:** Demonstrate that the combined global CLI, development, media, `yt-dlp`, and explicit Docker package baseline works through its documented installation mechanisms on the disposable staging VM and is ready for normal-use operator review.

**Blocked by:** 04/Migrate FFmpeg and the stable yt-dlp exception; 05/Install Docker as explicit host setup.

**Status:** ready-for-agent

- [ ] A fresh staging flow establishes all package-related state in the documented order without unexpected privilege during Home Manager activation.
- [ ] Every catalog entry marked as implemented by this effort resolves through the documented Home Manager or bootstrap mechanism.
- [ ] Representative CLI, compiler, media, self-managed binary, and container smoke checks pass on staging.
- [ ] The working changes pass repository tests, flake checks, non-activating builds, deliberate high-risk-file inspection, and the staged secret scan.
- [ ] Any observed deviation from the selected behavior baseline is either corrected or documented for operator review.
- [ ] The result is presented for operator review before host activation, commit, or retirement of legacy package machinery.
