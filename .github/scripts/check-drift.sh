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
GH_REPO="gharden91/ublue-gharden91"
REPO_URL="https://github.com/${GH_REPO}/blob/main"

log() { echo "check-drift: $*" >&2; }

# The GitHub repo variables page's value for a given name (Settings > Actions
# > Variables), i.e. the same override build.yml reads as ${{ vars.<name> }}.
# Needs GITHUB_TOKEN with repo access (a scheduled workflow's own token
# already has it; locally, `gh auth token` from an authenticated `gh` works).
repo_variable() {
    local name="$1" auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    curl -fsSL -H "Accept: application/vnd.github+json" "${auth[@]}" \
        "https://api.github.com/repos/${GH_REPO}/actions/variables/${name}" 2>/dev/null |
        jq -r '.value // empty' 2>/dev/null
}

# The effective pinned version for PWSH_VERSION / PLASMAZONES_VERSION,
# resolved the same way the real build does: build.yml passes the repo
# variable (Settings > Actions > Variables) through as an env var of the
# same name, Justfile forwards it as a --build-arg only if it's non-empty,
# and Containerfile/build.sh's own hardcoded defaults are the fallback for
# when no repo variable is set. Reading only build.sh's literal default (the
# old behavior here) reports drift against a pin nothing actually builds
# with once a repo variable is in play.
#
# Checks, in order: the same-named env var (what CI sets from ${{ vars.* }}),
# then the repo variable directly via the API (so a local run without that
# env var exported still sees the real pin, not just build.sh's fallback),
# then build.sh's own default.
pinned_version() {
    local key="$1" env_val repo_val
    env_val="${!key:-}"
    if [[ -n "${env_val}" ]]; then
        printf '%s\n' "${env_val}"
        return
    fi
    repo_val="$(repo_variable "${key}")"
    if [[ -n "${repo_val}" ]]; then
        printf '%s\n' "${repo_val}"
        return
    fi
    sed -n "s/^${key}=\"\\\${${key}:-\\([0-9.]*\\)}\"/\\1/p" build_files/build.sh | head -n1
}

# Read a `ARG KEY=default` value out of Containerfile — how BAZZITE_VERSION
# is pinned (unlike PWSH_VERSION/PLASMAZONES_VERSION, deliberately with no
# env-var override in CI; see ADR-202608222345), so this doesn't check the
# environment first the way pinned_version() does.
containerfile_arg() {
    local key="$1"
    sed -n "s/^ARG ${key}=\\([0-9.]*\\)\$/\\1/p" Containerfile | head -n1
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
# still what the floating `stable` tag currently resolves to. The FROM line
# itself just says stable-${BAZZITE_VERSION} (ADR-202608222345); the actual
# pinned number is the ARG default, same as Justfile's build recipe reads it.
check_fedora_currency() {
    local pinned_major stable_version stable_major
    pinned_major="$(containerfile_arg BAZZITE_VERSION)"
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

# Whether the pinned PlasmaZones release still matches the base image's
# KWin. build_files/build.sh already computes and logs this exact verdict at
# image build time ("PlasmaZones skew check: ..." plus either a "matches"
# line or a "WARNING: ... is not built against ..." line) — so read that
# instead of re-deriving it here. Re-deriving would mean pulling the
# multi-GB base image ourselves and re-running the same rpm/RPM-extraction
# build.sh already did, which is both slower and only as fresh as this
# runner's local podman cache (a prior version of this check had exactly
# that bug: podman run's default "pull only if missing" policy meant it
# could silently check a stale cached base image forever). Reading the
# actual last build's own log is both cheaper and a truer signal — it's the
# base image a real build resolved, not "whatever stable-<NN> resolves to
# right now". Requires the `gh` CLI, authenticated with read access to this
# repo's Actions runs (already true for the workflow's own token; locally,
# `gh auth token` from an authenticated `gh` works the same way the other
# checks use it).
check_kwin_skew() {
    local run_id log_lines kwin_version pinned plugin_vers

    if ! command -v gh >/dev/null 2>&1; then
        log "KWin skew: gh CLI not found, skipping"
        return 0
    fi

    run_id="$(gh run list --repo "${GH_REPO}" --workflow build.yml --branch main \
        --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null)"
    if [[ -z "${run_id}" ]]; then
        log "KWin skew: no recent successful build.yml run found, skipping"
        return 0
    fi

    log_lines="$(gh run view "${run_id}" --repo "${GH_REPO}" --log 2>/dev/null | grep -F 'PlasmaZones')" || log_lines=""
    if [[ -z "${log_lines}" ]]; then
        log "KWin skew: couldn't find the skew-check lines in run ${run_id}'s log, skipping"
        return 0
    fi

    if grep -qE 'PlasmaZones effect plugin matches image KWin [0-9.]+ — zones will load\.' <<<"${log_lines}"; then
        kwin_version="$(grep -oP 'matches image KWin \K[0-9.]+' <<<"${log_lines}" | head -n1)"
        log "KWin skew (build.yml run ${run_id}): image KWin=${kwin_version:-?} matches, zones load"
        return 0
    fi

    if grep -qE 'WARNING: PlasmaZones [0-9.]+ is not built against' <<<"${log_lines}"; then
        pinned="$(grep -oP 'WARNING: PlasmaZones \K[0-9.]+' <<<"${log_lines}" | head -n1)"
        kwin_version="$(grep -oP "this image's KWin \K[0-9.]+" <<<"${log_lines}" | head -n1)"
        plugin_vers="$(grep -oP 'embeds \[\K[^]]*' <<<"${log_lines}" | head -n1)"
        log "KWin skew (build.yml run ${run_id}): image KWin=${kwin_version:-?}; PlasmaZones ${pinned:-?} embeds=[${plugin_vers:-?}]"

        {
            echo "### PlasmaZones / KWin version skew"
            echo
            echo "The most recent successful build"
            echo "([run #${run_id}](https://github.com/${GH_REPO}/actions/runs/${run_id})) logged a"
            echo "mismatch: base image KWin \`${kwin_version:-unknown}\`, pinned PlasmaZones"
            echo "\`${pinned:-unknown}\` effect plugin embeds \`${plugin_vers:-no matching version}\`."
            echo "The effect stays inert (zones won't snap) until a matching PlasmaZones"
            echo "release is pinned. See [docs/plasmazones.md](${REPO_URL}/docs/plasmazones.md)."
            echo
        } >>"${REPORT}"
        return 1
    fi

    log "KWin skew: found PlasmaZones log lines but neither known pattern matched, skipping"
    return 0
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
    local baseline head_sha tmpdir changed commits f sha subject

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

    # The individual commits in the range that touched a watched path, oldest
    # first — this is the unit a review actually reasons about (see the "Doing
    # the review" section below), not the file list above. A squashed
    # baseline->head diff hides that several commits are one continuous
    # rewrite (fix, then a follow-up fixing the fix) versus independent
    # changes worth judging separately.
    commits="$(git -C "${tmpdir}" log --reverse --format='%H %s' "${baseline}..${head_sha}" -- "${watched_paths[@]}")" || commits=""

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
        if [[ -n "${commits}" ]]; then
            echo "Commits touching those paths in this range, oldest first:"
            echo
            while IFS=' ' read -r sha subject; do
                echo "- [\`${sha:0:8}\`](https://github.com/ublue-os/image-template/commit/${sha}) ${subject}"
            done <<<"${commits}"
            echo
        fi
        echo "#### Doing the review"
        echo
        echo "Review this range **commit by commit**, not as one squashed diff — a"
        echo "multi-commit rewrite (a fix, then a follow-up correcting that fix) needs"
        echo "judging by its final shape, but an issue per intermediate commit asks a"
        echo "reviewer to evaluate a state upstream itself abandoned days later. Group"
        echo "commits into their real units of change first, then per unit:"
        echo
        echo "1. Read the commit(s) and message for what changed and why (\`git show <sha>\`"
        echo "   against a local clone, or the commit URLs above)."
        echo "2. Decide: **port** (behavioral, applies to us — file its own issue per"
        echo "   [ADR-0016](${REPO_URL}/docs/decisions/0016-one-idea-per-issue-one-issue-per-pr.md),"
        echo "   referencing the source commit hash(es)), or **skip** (dependency/action-digest"
        echo "   bump already covered by Renovate, or a file/section we've diverged from"
        echo "   entirely) — with the reason either way."
        echo "3. Write up the per-commit decisions as an "
        echo "   [ADR](${REPO_URL}/docs/decisions/TEMPLATE.md) — one record for the whole"
        echo "   range, a table of commit hash / what it did / port-or-skip / why /"
        echo "   issue-or-PR reference. See"
        echo "   [ADR-202608230207](${REPO_URL}/docs/decisions/202608230207-review-template-range-aug2026.md)"
        echo "   for a worked example of this exact process on a prior range."
        echo "4. Once every commit in the range has a decision (ported, or deliberately"
        echo "   skipped), update \`${baseline_file}\` to \`${head_sha}\` so this stops"
        echo "   re-reporting the same range."
        echo
        echo "The file-by-file table on [#19](https://github.com/gharden91/ublue-gharden91/issues/19)"
        echo "has more background on what tends to be safe to skip."
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
