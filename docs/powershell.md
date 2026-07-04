# PowerShell 7

## Intent

Ship PowerShell 7 (`pwsh`) baked into the image so it is present on every
machine that rebases to this image, without per-machine setup or runtime
package layering.

## What is installed

- PowerShell is extracted from Microsoft's official `linux-x64` release tarball
  into `/usr/lib/microsoft/powershell/7`.
- `/usr/bin/pwsh` is a symlink to that binary.
- Version is pinned via `PWSH_VERSION` in `build_files/build.sh`.

Verify a built image with:

```bash
podman run --rm -e HOME=/tmp <image>:<tag> pwsh -c '$PSVersionTable'
```

See [local-testing.md](./local-testing.md) for full build/test commands.

## Decisions

### Install into `/usr`, not `/opt`

Microsoft's RPM and most install docs place PowerShell in
`/opt/microsoft/powershell/7`. On this image that is the wrong location:

- On bootc/atomic images `/opt` is a symlink to the mutable, machine-persistent
  `/var/opt`. Files baked into `/var/opt` at build time are only seeded on first
  boot — **later image updates would not update them**, leaving `pwsh` stuck at
  whatever version first landed.
- The base image (`bazzite-dx`) bundles apps such as docker-desktop and VS Code
  that write to `/opt` at runtime, so we **cannot** make `/opt` immutable (the
  `RUN rm /opt && mkdir /opt` trick in the `Containerfile`) without risking those
  apps.

Installing into `/usr` sidesteps both problems: `/usr` is immutable and fully
re-provisioned on every deploy, so `pwsh` updates cleanly on each rebuild, and
`/opt` is left untouched for the base image's apps.

### Tarball, not the Microsoft RPM repo

We deliberately avoid adding Microsoft's dnf repo because:

- The RPM hardcodes the `/opt` install path (see above).
- We did not want Microsoft's repo config or GPG key left enabled on the final
  image.

The tradeoff is that the tarball does **not** auto-update — the version is
pinned and bumped manually.

### Layering vs. image

PowerShell is a permanent tool we want on every machine, so it belongs in the
image (declarative, versioned, built once, deployed everywhere) rather than
applied per-machine via `rpm-ostree install`. Reserve runtime layering for
throwaway experiments.

## Maintenance

- **Bump the version (recommended, no code change):** in GitHub go to
  *Settings > Secrets and variables > Actions > Variables* and set a repo
  variable named `PWSH_VERSION` (e.g. `7.5.2`) to a release tag from
  https://github.com/PowerShell/PowerShell/releases. The next CI build picks it
  up. Leaving it unset falls back to the default baked into `build_files/build.sh`.
- **Bump locally:** `PWSH_VERSION=7.5.2 just build`.
- **Change the default:** edit `PWSH_VERSION="${PWSH_VERSION:-7.5.2}"` in
  `build_files/build.sh`.

The version flows: repo variable `PWSH_VERSION` → `build.yml` env → `just build`
(`--build-arg`) → `Containerfile` (`ARG PWSH_VERSION`) → `build.sh`.
- **Architecture:** the download URL is hardcoded to `linux-x64`. If this image
  is ever built for ARM64, that string must be made conditional on the target
  arch.
