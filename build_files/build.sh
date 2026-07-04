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

# PlasmaZones (KWin snapping zones) from the maintainer's COPR
dnf5 -y copr enable fuddlesworth/PlasmaZones
dnf5 -y install plasmazones
# Disable the COPR so it isn't left enabled on the final image
dnf5 -y copr disable fuddlesworth/PlasmaZones
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
