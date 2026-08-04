# Microsoft Edge — not shipped

> **Status: removed from the image (2026-08-04, #17).** Edge was briefly shipped
> as a native RPM (#10); it is no longer installed, and `/opt` has reverted to
> the base's `/opt -> /var/opt` symlink. See [ADR-0013](decisions/0013-drop-edge-and-revert-immutable-opt.md),
> which supersedes [ADR-0007](decisions/0007-make-opt-a-real-immutable-directory.md).

## Why it isn't here

Edge was shipped as a native RPM to get full system integration (native
messaging for password managers, SSO/PIV/smartcard) that the Flatpak sandbox
degrades. Getting the RPM to unpack required making `/opt` a real immutable
directory, because the Edge RPM hardcodes `/opt/microsoft/msedge` and its cpio
unpack fails against the base's `/opt -> /var/opt` symlink
(`mkdir failed - File exists`). That `/opt` change was the riskiest single
customization in the image — `bazzite-dx` itself uses `/var/opt` for container
runtime state.

Two things together made Edge not worth that risk:

- **No gain over distrobox.** The native install exhibits the *same* Chromium
  color-emoji tofu as the distrobox build. The root cause is COLRv1, which is
  Chromium-wide, not Edge-specific — see [fonts.md](fonts.md). So the native
  package didn't escape the problem it was partly meant to sidestep.
- **Edge was the *only* reason `/opt` had to be immutable.** No other packaged
  app installs into `/opt` (PowerShell → `/usr`; VLC/Discord/tmux → `/usr`).
  With Edge gone, the real immutable `/opt` had nothing left to justify it, so
  reverting it removes the `/var/opt`/containerd risk for free.

Edge is still available via distrobox for anyone who wants it — exactly the
state before it was baked in.

## If you want Edge back

Re-adding native Edge means re-adding immutable `/opt`, so revisit
[ADR-0007](decisions/0007-make-opt-a-real-immutable-directory.md)'s containerd
findings first. The mechanics that worked in #10:

- `build_files/build.sh`: import `https://packages.microsoft.com/keys/microsoft.asc`,
  write Microsoft's `edge` `.repo`, `dnf5 install microsoft-edge-stable`, then
  force the repo `enabled=0` (the package re-enables its own repo for
  self-update, which we don't want on the final image).
- `Containerfile`: uncomment `RUN rm /opt && mkdir /opt`.

The cleaner long-term alternative — basing off plain `bazzite` (empty `/var/opt`)
and adding back only the dev tools actually used, which makes immutable `/opt`
harmless again — is captured as a deferred idea, not an Edge emergency. The
Flatpak fallback (ADR-0006) also remains, at the cost of the sandbox
integration Edge was wanted for.

## Historical record

The native-RPM install, the `/opt` blocker, the VM validation (2026-07-19), and
the existing-machine containerd caveat are preserved in
[ADR-0007](decisions/0007-make-opt-a-real-immutable-directory.md) and its
git history (#10). ADR-0013 records the removal.
