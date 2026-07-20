# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base Image
# Pinned to stable-44 (rather than the floating "stable" tag) to keep the
# Fedora version in lockstep with the fuddlesworth/PlasmaZones COPR, which
# only ships builds for specific Fedora releases. See docs/README.md's
# Maintenance Watchlist before bumping this to stable-45.
FROM ghcr.io/ublue-os/bazzite-dx:stable-44
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# Make /opt a real (immutable) directory instead of a symlink to /var/opt.
# Required for RPMs that install into /opt (e.g. microsoft-edge-stable), whose
# cpio unpack fails against the /opt -> /var/opt symlink. See docs/edge.md.
RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

# PowerShell version, overridable at build time (--build-arg PWSH_VERSION=...)
ARG PWSH_VERSION=7.5.2
# PlasmaZones version, overridable at build time (--build-arg PLASMAZONES_VERSION=...)
ARG PLASMAZONES_VERSION=3.1.3

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    PWSH_VERSION="${PWSH_VERSION}" PLASMAZONES_VERSION="${PLASMAZONES_VERSION}" /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
