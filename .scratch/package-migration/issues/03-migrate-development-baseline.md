# 03: Migrate the global development baseline

**What to build:** Provide a pinned default development toolchain in every user session through Home Manager while leaving projects free to select different versions and dependency sets in their own development environments.

**Blocked by:** 02/Complete the standalone global CLI tools.

**Status:** resolved

- [x] Home Manager installs Go, Rust and Cargo, JDK 21, GCC with G++, Make, and `pkg-config` from the pinned Nixpkgs input.
- [x] The migration does not use downloaded Go archives, Rustup, `cargo install`, `go install`, or a separate JRE.
- [x] Node.js, pnpm, Python/pipx, and user-installed Cargo or Go tools remain outside this global baseline.
- [x] Java and C/C++ compilation, Go execution, Rust/Cargo execution, Make, and `pkg-config` receive representative staging smoke checks.
- [x] The slice does not add `JAVA_HOME` or modify shell PATH configuration; those decisions remain with the later Zsh migration.
- [x] The software installation catalog links each toolchain to its Home Manager installation definition.
- [x] Repository tests, flake evaluation, a non-activating local build, and staging activation pass before operator review.

## Answer

The global development baseline is declared alongside the standalone tools in
[`modules/packages.nix`](../../../modules/packages.nix). The Home Manager
profile was activated on staging, where representative Go, Rust/Cargo, Java,
C, C++, Make, and `pkg-config` checks passed.
