#!/usr/bin/env bash
# Files or updates the shared drift-watch issue from a check-drift.sh report.
# Shared between .github/workflows/drift-check.yml and ad-hoc local runs, so
# a locally-found drift (e.g. template drift, before the weekly schedule gets
# to it) can be handed to a reviewer/agent as an issue link right away:
#
#   GITHUB_TOKEN=$(gh auth token) bash .github/scripts/check-drift.sh /tmp/drift-report.md
#   bash .github/scripts/file-drift-issue.sh /tmp/drift-report.md
#   # -> prints the issue URL on stdout; e.g. to open it:
#   gh issue view "$(bash .github/scripts/file-drift-issue.sh /tmp/drift-report.md)" --web
#
# Requires an authenticated `gh` with issue read/write on the repo. A no-op
# (not an error) if the report is empty — nothing to file.
#
# Usage: file-drift-issue.sh <report-file>

set -euo pipefail

REPORT="${1:?usage: file-drift-issue.sh <report-file>}"
REPO="${REPO:-gharden91/ublue-gharden91}"

if [[ ! -s "${REPORT}" ]]; then
    echo "file-drift-issue: ${REPORT} is empty, nothing to file" >&2
    exit 0
fi

gh label create drift-watch --repo "${REPO}" --force \
    --color "d93f0b" \
    --description "Filed by drift-check.yml: upstream moved, review against the Maintenance Watchlist" \
    >/dev/null

BODY_FILE="$(mktemp)"
trap 'rm -f "${BODY_FILE}"' EXIT
{
    echo "Automated drift check found upstream changes worth reviewing"
    echo "against this image's Maintenance Watchlist"
    echo "(docs/README.md#maintenance-watchlist)."
    echo
    cat "${REPORT}"
    echo "---"
    echo "_Filed by [drift-check.yml](https://github.com/${REPO}/actions/workflows/drift-check.yml) or a local \`check-drift.sh\` run._"
} >"${BODY_FILE}"

existing="$(gh issue list --repo "${REPO}" --label drift-watch --state open \
    --json number --jq '.[0].number // empty')"
if [[ -n "${existing}" ]]; then
    echo "Updating existing drift issue #${existing}" >&2
    gh issue edit "${existing}" --repo "${REPO}" --body-file "${BODY_FILE}" >/dev/null
    gh issue comment "${existing}" --repo "${REPO}" \
        --body "Re-checked $(date -u +%Y-%m-%d) — drift still present, report body updated above." >/dev/null
    echo "https://github.com/${REPO}/issues/${existing}"
else
    echo "Filing a new drift issue" >&2
    gh issue create --repo "${REPO}" --title "Upstream drift detected" \
        --label drift-watch --body-file "${BODY_FILE}"
fi
