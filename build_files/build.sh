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

### Install VLC from the negativo17 fedora-multimedia repo
# bazzite does NOT ship RPM Fusion (so vlc-plugins-freeworld doesn't exist
# here); its multimedia stack (full ffmpeg etc.) comes from negativo17's
# fedora-multimedia repo, whose .repo file is baked into the image but left
# disabled. Enable it for this one transaction only — same pattern bazzite's
# own Containerfile uses. negativo17's vlc is built full-featured against
# that same stack, so no -freeworld codec split is needed. See docs/vlc.md.
dnf5 install -y --enable-repo="*fedora-multimedia*" vlc

### Install Discord from the official "latest" RPM
# Deliberately NOT pinned, unlike PowerShell/PlasmaZones: Discord hard-gates
# outdated clients with a mandatory "update required" screen, so a pinned
# version would stop launching between bumps. Fetching latest on every image
# rebuild keeps the client current as long as the image rebuilds regularly.
# See docs/discord.md.
curl -fL -o /tmp/discord.rpm \
    "https://discord.com/api/download?platform=linux&format=rpm"
dnf5 install -y /tmp/discord.rpm
rm -f /tmp/discord.rpm
echo "Installed Discord version: $(rpm -q discord)"

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
# build log instead of finding out from a desktop notification later. The
# built-against version is embedded as a string in the effect plugin (and, in
# practice, appears exactly once), so we read it back and compare.
PLASMAZONES_PLUGIN="$(rpm -ql plasmazones | grep -E '/kwin/.*\.so$' | head -n1)" || PLASMAZONES_PLUGIN=""
KWIN_VERSION="$(rpm -q --whatprovides --qf '%{VERSION}\n' kwin | head -n1)" || KWIN_VERSION=""
if [[ -n "${PLASMAZONES_PLUGIN}" && "${KWIN_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    # Build a "6[.]7[.][0-9]+" regex from the running KWin's X.Y series so the
    # diagnostic ignores unrelated Qt/KF version strings in the binary, and log
    # every same-series version the plugin embeds (not just a yes/no match).
    KWIN_MM="${KWIN_VERSION%.*}"           # 6.7.1 -> 6.7
    KWIN_RE="${KWIN_MM%.*}[.]${KWIN_MM#*.}[.][0-9]+"   # -> 6[.]7[.][0-9]+
    PLUGIN_KWIN_VERS="$(grep -aEo "${KWIN_RE}" "${PLASMAZONES_PLUGIN}" | sort -u | paste -sd' ' -)" || PLUGIN_KWIN_VERS=""
    echo "PlasmaZones skew check: image KWin=${KWIN_VERSION}; plugin embeds KWin ${KWIN_MM}.x=[${PLUGIN_KWIN_VERS:-none}]"
    if printf '%s\n' ${PLUGIN_KWIN_VERS} | grep -qxF "${KWIN_VERSION}"; then
        echo "PlasmaZones effect plugin matches image KWin ${KWIN_VERSION} — zones will load."
    else
        echo "WARNING: PlasmaZones ${PLASMAZONES_VERSION} is not built against this image's KWin ${KWIN_VERSION} (embeds [${PLUGIN_KWIN_VERS:-none}])." >&2
        echo "WARNING: The effect will stay inert (zones won't work) until the versions align — pin a matching release or see docs/plasmazones.md." >&2
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

### Install Microsoft Edge (stable) from Microsoft's RPM repo
# Edge is installed as a native RPM rather than a Flatpak so features like
# native messaging (password managers, SSO/PIV) and system integration work.
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat >/etc/yum.repos.d/microsoft-edge.repo <<'EOF'
[microsoft-edge]
name=microsoft-edge
baseurl=https://packages.microsoft.com/yumrepos/edge
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf5 install -y microsoft-edge-stable
# The Edge package ships (and re-enables) its own microsoft-edge.repo for its
# self-update mechanism. Force it disabled so the final image doesn't pull
# third-party updates; updates come from rebuilding the image instead.
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/microsoft-edge.repo

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
