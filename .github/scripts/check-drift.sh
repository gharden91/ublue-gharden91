#!/usr/bin/env bash
# Checks the Maintenance Watchlist items that can drift silently underneath
# this image (see docs/README.md#maintenance-watchlist) and writes a markdown
# report of anything found. Driven by .github/workflows/drift-check.yml on a
# schedule; also safe to run by hand from the repo root.
#
# Detection is not failure: this script always exits 0. A network hiccup or a
# check it can't complete just skips that check (logged to stderr) rather than
# failing the job — the workflow decides what "no report" means.
#
# Usage: check-drift.sh [report-file]   (default: drift-report.md)

set -uo pipefail

REPORT="${1:-drift-report.md}"
: >"${REPORT}"

# The report becomes a GitHub issue body, which has no notion of "relative to
# this file" — so docs/ADR links in it need to be absolute.
REPO_URL="https://github.com/gharden91/ublue-gharden91/blob/main"

log() { echo "check-drift: $*" >&2; }

# Read a `KEY="${KEY:-default}"` pin out of build_files/build.sh.
pinned_version() {
    local key="$1"
    sed -n "s/^${key}=\"\\\${${key}:-\\([0-9.]*\\)}\"/\\1/p" build_files/build.sh | head -n1
}

# Latest GitHub release tag for owner/repo, with a leading "v" stripped.
latest_gh_release() {
    local repo="$1" auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl -fsSL -H "Accept: application/vnd.github+json" "${auth[@]}" \
        "https://api.github.com/repos/${repo}/releases/latest" |
        jq -r '.tag_name // empty' | sed 's/^v//'
}

# Compares a build.sh version pin against the upstream project's latest
# release. Appends a report section and returns 1 if they differ.
check_pinned_version() {
    local label="$1" build_key="$2" gh_repo="$3" doc="$4"
    local pinned latest
    pinned="$(pinned_version "${build_key}")"
    latest="$(latest_gh_release "${gh_repo}")"
    log "${label}: pinned=${pinned:-?} latest=${latest:-?}"

    if [[ -z "${pinned}" || -z "${latest}" ]]; then
        log "${label}: could not determine one of the versions, skipping"
        return 0
    fi
    if [[ "${pinned}" == "${latest}" ]]; then
        return 0
    fi

    {
        echo "### ${label} (\`${build_key}\`)"
        echo
        echo "Pinned \`${pinned}\`, upstream's latest release is \`${latest}\`:"
        echo "<https://github.com/${gh_repo}/releases/tag/v${latest}>."
        echo "See [${doc}](${REPO_URL}/${doc})."
        echo
    } >>"${REPORT}"
    return 1
}

# Whether the base image's Fedora-versioned tag (bazzite-dx:stable-<NN>) is
# still what the floating `stable` tag currently resolves to.
check_fedora_currency() {
    local pinned_major stable_version stable_major
    pinned_major="$(sed -n 's/.*bazzite-dx:stable-\([0-9]\+\).*/\1/p' Containerfile | head -n1)"
    stable_version="$(skopeo inspect docker://ghcr.io/ublue-os/bazzite-dx:stable 2>/dev/null |
        jq -r '.Labels."org.opencontainers.image.version" // empty')"
    stable_major="${stable_version%%.*}"
    log "Fedora currency: pinned=stable-${pinned_major:-?} current-stable=${stable_version:-?} (major ${stable_major:-?})"

    if [[ -z "${pinned_major}" || -z "${stable_major}" ]]; then
        log "Fedora currency: could not determine one of the versions, skipping"
        return 0
    fi
    if [[ "${pinned_major}" == "${stable_major}" ]]; then
        return 0
    fi

    {
        echo "### Base Fedora currency"
        echo
        echo "\`Containerfile\` pins \`bazzite-dx:stable-${pinned_major}\`, but the"
        echo "floating \`stable\` tag now resolves to Fedora \`${stable_major}\`"
        echo "(\`${stable_version}\`). See \"Bumping the Fedora version\" in"
        echo "[docs/README.md](${REPO_URL}/docs/README.md#maintenance-watchlist) and ADR-0003."
        echo
    } >>"${REPORT}"
    return 1
}

# Whether the pinned PlasmaZones release still matches the base image's KWin.
# Mirrors the skew check build_files/build.sh runs at image build time, but
# against the base image directly instead of a built image.
check_kwin_skew() {
    local pinned fedora_release kwin_version tmpdir rpm_url plugin_so
    local kwin_mm kwin_re plugin_vers v matched

    pinned="$(pinned_version PLASMAZONES_VERSION)"
    if [[ -z "${pinned}" ]]; then
        log "KWin skew: could not read PLASMAZONES_VERSION, skipping"
        return 0
    fi

    kwin_version="$(podman run --rm ghcr.io/ublue-os/bazzite-dx:stable-44 \
        rpm -q --whatprovides --qf '%{VERSION}\n' kwin 2>/dev/null | head -n1)" || kwin_version=""
    fedora_release="$(podman run --rm ghcr.io/ublue-os/bazzite-dx:stable-44 rpm -E %fedora 2>/dev/null)" || fedora_release=""
    if [[ -z "${kwin_version}" || -z "${fedora_release}" ]]; then
        log "KWin skew: could not read the base image's KWin/Fedora version, skipping"
        return 0
    fi

    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064  # intentional early expansion of $tmpdir
    trap "rm -rf '${tmpdir}'" RETURN

    rpm_url="https://github.com/fuddlesworth/PlasmaZones/releases/download/v${pinned}/plasmazones-${pinned}-1.fc${fedora_release}.x86_64.rpm"
    if ! curl -fsSL -o "${tmpdir}/plasmazones.rpm" "${rpm_url}"; then
        log "KWin skew: no PlasmaZones ${pinned} RPM for Fedora ${fedora_release} (${rpm_url}), skipping"
        return 0
    fi
    (cd "${tmpdir}" && rpm2cpio plasmazones.rpm | cpio -idm --quiet)
    plugin_so="$(find "${tmpdir}" -path '*/kwin/*.so' -print -quit)"
    if [[ -z "${plugin_so}" ]]; then
        log "KWin skew: no kwin effect plugin found in the RPM, skipping"
        return 0
    fi

    # Same X.Y-series regex build_files/build.sh uses, so the diagnostic
    # ignores unrelated Qt/KF version strings embedded in the binary.
    kwin_mm="${kwin_version%.*}"
    kwin_re="${kwin_mm%.*}[.]${kwin_mm#*.}[.][0-9]+"
    plugin_vers="$(grep -aEo "${kwin_re}" "${plugin_so}" | sort -u | paste -sd' ' -)" || plugin_vers=""
    log "KWin skew: image KWin=${kwin_version}; plugin embeds ${kwin_mm}.x=[${plugin_vers:-none}]"

    matched=0
    read -ra plugin_vers_arr <<<"${plugin_vers}"
    for v in "${plugin_vers_arr[@]:-}"; do
        [[ "${v}" == "${kwin_version}" ]] && matched=1
    done
    [[ "${matched}" -eq 1 ]] && return 0

    {
        echo "### PlasmaZones / KWin version skew"
        echo
        echo "The base image's KWin is \`${kwin_version}\`, but the pinned PlasmaZones"
        echo "\`${pinned}\` effect plugin embeds \`${plugin_vers:-no matching version}\`."
        echo "The effect stays inert (zones won't snap) until a matching PlasmaZones"
        echo "release is pinned. See [docs/plasmazones.md](${REPO_URL}/docs/plasmazones.md)."
        echo
    } >>"${REPORT}"
    return 1
}

# Whether ublue-os/image-template has touched, since our recorded baseline,
# any of the files this repo forked from it and now maintains by hand (per
# ADR-202608042137: no auto-merge, substantive changes get ported by a human
# who reads the diff). This only tells us *that* the template moved in a
# watched path — not whether the change is substantive versus a dependency
# bump Renovate already covers; that judgment call is exactly what
# ADR-202608042137's file-by-file table (and the #19 comment it points at) is
# for, and stays with whoever reads the report.
check_template_drift() {
    local baseline_file=".github/template-drift-baseline"
    local template_url="https://github.com/ublue-os/image-template.git"
    local watched_paths=(
        ".github/workflows/build.yml"
        ".github/workflows/build-disk.yml"
        "Justfile"
        "Containerfile"
        "build_files/build.sh"
        "disk_config"
    )
    local baseline head_sha tmpdir changed f

    if [[ ! -f "${baseline_file}" ]]; then
        log "Template drift: no ${baseline_file}, skipping"
        return 0
    fi
    baseline="$(tr -d '[:space:]' <"${baseline_file}")"
    if [[ -z "${baseline}" ]]; then
        log "Template drift: ${baseline_file} is empty, skipping"
        return 0
    fi

    head_sha="$(git ls-remote "${template_url}" HEAD 2>/dev/null | cut -f1)"
    if [[ -z "${head_sha}" ]]; then
        log "Template drift: could not reach ${template_url}, skipping"
        return 0
    fi
    log "Template drift: baseline=${baseline:0:12} template-head=${head_sha:0:12}"
    if [[ "${head_sha}" == "${baseline}" ]]; then
        return 0
    fi

    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064  # intentional early expansion of $tmpdir
    trap "rm -rf '${tmpdir}'" RETURN
    if ! git clone --quiet --no-checkout "${template_url}" "${tmpdir}" 2>/dev/null; then
        log "Template drift: clone failed, skipping"
        return 0
    fi
    if ! git -C "${tmpdir}" fetch --quiet origin "${baseline}" 2>/dev/null; then
        log "Template drift: baseline ${baseline:0:12} not found upstream (force-pushed?), skipping"
        return 0
    fi

    changed="$(git -C "${tmpdir}" diff --name-only "${baseline}" "${head_sha}" -- "${watched_paths[@]}")" || changed=""
    if [[ -z "${changed}" ]]; then
        log "Template drift: template moved but touched none of the watched paths"
        return 0
    fi
    log "Template drift: watched paths changed: $(tr '\n' ' ' <<<"${changed}")"

    {
        echo "### Template drift (\`ublue-os/image-template\`)"
        echo
        echo "The template has moved from \`${baseline:0:12}\` to \`${head_sha:0:12}\` and"
        echo "touched files this repo forked from it and now diverges from deliberately"
        echo "(see [ADR-202608042137](${REPO_URL}/docs/decisions/202608042137-no-automated-template-sync.md)):"
        echo
        while IFS= read -r f; do
            echo "- [\`${f}\`](https://github.com/ublue-os/image-template/commits/${head_sha}/${f})"
        done <<<"${changed}"
        echo
        echo "Compare: <https://github.com/ublue-os/image-template/compare/${baseline}...${head_sha}>"
        echo
        echo "Read each hunk for *behavioral* changes (signing, rechunk, build steps) and"
        echo "port those by hand as their own issue/PR; dependency and action-digest bumps"
        echo "are already covered by Renovate here and can be ignored — see the"
        echo "file-by-file table on [#19](https://github.com/gharden91/ublue-gharden91/issues/19)."
        echo "Once reviewed (ported, or deliberately skipped), update \`${baseline_file}\`"
        echo "to \`${head_sha}\` so this stops re-reporting the same range."
        echo
    } >>"${REPORT}"
    return 1
}

drifted=0
check_pinned_version "PlasmaZones" "PLASMAZONES_VERSION" "fuddlesworth/PlasmaZones" "docs/plasmazones.md" || drifted=1
check_pinned_version "PowerShell" "PWSH_VERSION" "PowerShell/PowerShell" "docs/powershell.md" || drifted=1
check_fedora_currency || drifted=1
check_kwin_skew || drifted=1
check_template_drift || drifted=1

if [[ "${drifted}" -eq 1 ]]; then
    log "drift found, report written to ${REPORT}"
else
    log "no drift found"
fi
exit 0
