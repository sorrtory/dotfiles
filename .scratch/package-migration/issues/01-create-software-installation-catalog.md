# 01: Create the software installation catalog

**What to build:** Create one concise Markdown catalog that tells a reader what each evaluated program is for, how it is or will be installed, and where the repository defines that installation. The catalog is the human-readable source of truth for installation wayfinding; implementation files remain authoritative for exact mechanics and the Nix lock remains authoritative for pinned versions.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] The catalog covers the selected package baseline, explicit host and special-installation responsibilities, and evaluated legacy candidates relevant to the current Ubuntu migration.
- [x] Every entry states the program's purpose and installation method in plain language.
- [x] Every implemented installation links to its repository definition; entries without an implementation say so without linking to a planned file.
- [x] Host-owned software, Home Manager packages, project tools, explicit bootstrap/setup actions, deferred candidates, replacements, and removals are distinguishable without introducing a complex status taxonomy.
- [x] The catalog does not duplicate exact Nix versions or distro-specific implementation details owned elsewhere.
- [x] Existing project documentation links to the catalog where package-installation wayfinding is useful.

## Answer

The [software installation catalog](../../../docs/SOFTWARE.md) now records the
selected Ubuntu package baseline and explicit installation responsibilities.
Program-specific dependencies are added only when their configuration enters
the migration scope. The README and migration plan link to the catalog for
installation wayfinding.
