<div align="center">
  <img src="assets/Engineer_Tux.png" alt="blueprint logo" width="200"/>

  # blueprint

  Custom bootc-based OS images.
</div>

## Overview

`blueprint` builds a set of custom, container-native (bootc) OS images. Every
flavor builds from a single parameterized root `Containerfile` (selected via
`VARIANT`/`BASE_IMAGE` build args). All flavors share common build scripts
and system files.

## Flavors

To use one of the listed variants below just do a `FROM ghcr.io/huntedraven7/<INSERT FLAVOR>:stable` there is also testing for those that want that.

| Flavor | Containerfile | Notes |
|:---|:---|:---|
| arch-bootc | `Containerfile` (`VARIANT=arch`) | Arch-based |
| debian-bootc | `Containerfile` (`VARIANT=debian`) | Debian-based |
| gentoo-bootc | `Containerfile` (`VARIANT=gentoo`) | Gentoo-based (local build only — see `docs/GENTOO.md`) |
| nixos-bootc | `Containerfile` (`VARIANT=nixos`) | NixOS-based bootc image |
| opensuse-bootc | `Containerfile` (`VARIANT=opensuse`) | OpenSUSE Tumbleweed-based |
| ubuntu-bootc | `Containerfile` (`VARIANT=ubuntu`) | Ubuntu 26.04-based |

## Repository layout

```
blueprint/
├── .github/                     # CI: dependabot, renovate, build workflows
├── Justfile                     # build/dev commands
├── artifacthub-repo.yml         # ArtifactHub metadata
├── cosign.pub                   # image signing public key
├── assets/                      # logos
├── build_files/                 # build-*.sh scripts run inside the root Containerfile
├── disk_config/                 # disk/ISO layout configs (disk.toml, iso-*.toml)
├── system_files/                # files copied into the image (global + per-flavor)
```

## Building

```sh
just <recipe>
```

See `Justfile` for available build recipes.

## Signing

Images are signed with cosign. Public key: `cosign.pub`.
