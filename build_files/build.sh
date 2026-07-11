#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

### Install PlasmaZones (KWin snapping zones) from a pinned GitHub release
# Installed from the release RPM rather than the maintainer's COPR so the
# version is pinned and only bumps deliberately (same pattern as PowerShell
# below). The KWin effect plugin is compiled against a specific KWin version
# and stays inert under any other, so pinning also controls *when* we take a
# build that may not match the base image's KWin. See docs/plasmazones.md.
# Version can be overridden at build time via the PLASMAZONES_VERSION build
# arg (see Containerfile + .github/workflows/build.yml). Defaults if unset.
PLASMAZONES_VERSION="${PLASMAZONES_VERSION:-3.1.3}"
FEDORA_RELEASE="$(rpm -E %fedora)"
curl -fL -o /tmp/plasmazones.rpm \
    "https://github.com/fuddlesworth/PlasmaZones/releases/download/v${PLASMAZONES_VERSION}/plasmazones-${PLASMAZONES_VERSION}-1.fc${FEDORA_RELEASE}.x86_64.rpm"
dnf5 -y install /tmp/plasmazones.rpm
rm -f /tmp/plasmazones.rpm

# Surface (but don't fail on) KWin version skew: the PlasmaZones effect only
# loads under the exact KWin it was built against, so flag a mismatch in the
# build log instead of finding out from a desktop notification later.
PLASMAZONES_PLUGIN="$(rpm -ql plasmazones | grep -E '/kwin/.*\.so$' | head -n1)" || PLASMAZONES_PLUGIN=""
KWIN_VERSION="$(rpm -q --whatprovides --qf '%{VERSION}\n' kwin | head -n1)" || KWIN_VERSION=""
if [[ -n "${PLASMAZONES_PLUGIN}" && "${KWIN_VERSION}" =~ ^[0-9] ]]; then
    if grep -aq "${KWIN_VERSION}" "${PLASMAZONES_PLUGIN}"; then
        echo "PlasmaZones effect plugin matches image KWin ${KWIN_VERSION}"
    else
        echo "WARNING: PlasmaZones ${PLASMAZONES_VERSION} does not appear to be built against this image's KWin ${KWIN_VERSION}." >&2
        echo "WARNING: The effect will stay inert (zones won't work) until the versions align — see docs/plasmazones.md." >&2
    fi
else
    echo "WARNING: could not determine PlasmaZones/KWin versions for the skew check (plugin='${PLASMAZONES_PLUGIN}', kwin='${KWIN_VERSION}')" >&2
fi
### Install PowerShell 7 from Microsoft's tarball into /usr
# bazzite-dx bundles apps (docker-desktop, code, etc.) that write to /opt at
# runtime, so we can't make /opt immutable. Instead install into /usr, which is
# immutable and re-provisioned on every bootc deploy, keeping pwsh updatable.
# Version can be overridden at build time via the PWSH_VERSION build arg
# (see Containerfile + .github/workflows/build.yml). Defaults if unset.
PWSH_VERSION="${PWSH_VERSION:-7.5.2}"
curl -fL -o /tmp/powershell.tar.gz \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz"
mkdir -p /usr/lib/microsoft/powershell/7
tar -xzf /tmp/powershell.tar.gz -C /usr/lib/microsoft/powershell/7
chmod +x /usr/lib/microsoft/powershell/7/pwsh
ln -sf /usr/lib/microsoft/powershell/7/pwsh /usr/bin/pwsh
rm -f /tmp/powershell.tar.gz

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
