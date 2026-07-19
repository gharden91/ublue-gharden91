# Documentation

Most commits are made with Claude Code's assistance. This image's own customizations, decisions, and workflows are documented in [`docs/`](./docs/):

- [Local build & testing](./docs/local-testing.md) — how to build and test the image locally.
- [PlasmaZones](./docs/plasmazones.md) — install approach, decisions, and maintenance.
- [PowerShell 7](./docs/powershell.md) — install approach, decisions, and how to bump the version.
- [Microsoft Edge](./docs/edge.md) — native RPM in `/opt`; the `/opt` blocker and how it was resolved.

# Based on

Forked from [ublue-os/image-template](https://github.com/ublue-os/image-template)

## image-template

This repository is meant to be a template for building your own custom [bootc](https://github.com/bootc-dev/bootc) image. This template is the recommended way to make customizations to any image published by the Universal Blue Project.

## Community

If you have questions about this template after following the instructions, try the following spaces:
- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussion forums](https://github.com/bootc-dev/bootc/discussions) - This is not an Universal Blue managed space, but is an excellent resource if you run into issues with building bootc images.
