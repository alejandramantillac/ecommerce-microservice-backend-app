#!/usr/bin/env bash
# Script to generate categorized release notes and publish a GitHub Release

set -euo pipefail

RELEASE_VERSION="${1:-}"
GITHUB_TOKEN="${2:-}"
REPO_URL="${3:-https://github.com/alejandramantillac/ecommerce-microservice-backend-app.git}"

if [[ -z "$RELEASE_VERSION" || -z "$GITHUB_TOKEN" ]]; then
    echo "Usage: $0 <release-version> <github-token> [repo-url]" >&2
    exit 1
fi

REPO_SLUG="${REPO_URL#https://github.com/}"
REPO_SLUG="${REPO_SLUG%.git}"
RELEASE_TAG="v${RELEASE_VERSION}"

echo "========================================="
echo "Generating Release Notes for ${RELEASE_TAG}"
echo "Repository: ${REPO_SLUG}"
echo "========================================="

git config --global user.name "Jenkins CI"
git config --global user.email "jenkins@example.com"

PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
LOG_RANGE=""
if [[ -n "$PREV_TAG" ]]; then
    LOG_RANGE="${PREV_TAG}..HEAD"
    echo "Previous tag detected: ${PREV_TAG}"
else
    echo "No previous tag found; using entire history."
fi

python3 - "$LOG_RANGE" "$RELEASE_VERSION" "$RELEASE_TAG" <<'PY'
import os, re, subprocess, sys, textwrap, json, datetime

log_range, rel_version, rel_tag = sys.argv[1], sys.argv[2], sys.argv[3]
cmd = ['git', 'log', '--pretty=format:%H%x1f%s%x1f%b%x1e']
if log_range:
    cmd.insert(2, log_range)
raw = subprocess.check_output(cmd).decode('utf-8').strip('\n\x1e')

entries = []
if raw:
    for chunk in raw.split('\x1e'):
        if not chunk.strip():
            continue
        commit_hash, subject, body = chunk.split('\x1f')
        entries.append({'hash': commit_hash[:7], 'subject': subject.strip(), 'body': body.strip()})

categories = {
    'feat': 'Features',
    'fix': 'Bug Fixes',
    'perf': 'Performance Improvements',
    'refactor': 'Refactors',
    'docs': 'Documentation',
    'test': 'Tests',
    'build': 'Build System',
    'ci': 'CI/CD',
    'chore': 'Chores',
}
ordered_sections = ['feat', 'fix', 'perf', 'refactor', 'docs', 'test', 'build', 'ci', 'chore']
grouped = {key: [] for key in ordered_sections}
breaking = []
others = []

commit_re = re.compile(r'^(?P<type>\w+)(?:\([\w\-.]+\))?(?P<brk>!)?: (?P<desc>.+)$')

for entry in entries:
    match = commit_re.match(entry['subject'])
    is_breaking = False
    commit_type = None
    description = entry['subject']
    if match:
        commit_type = match.group('type')
        description = match.group('desc')
        if match.group('brk'):
            is_breaking = True
    if 'BREAKING CHANGE' in entry['body']:
        is_breaking = True

    if is_breaking:
        breaking.append(f"- {description} ({entry['hash']})")
        continue

    key = commit_type if commit_type in grouped else None
    line = f"- {description} ({entry['hash']})"
    if key:
        grouped[key].append(line)
    else:
        others.append(line)

lines = [f"# Release {rel_version}", "", f"**Date:** {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC", ""]
if entries:
    if breaking:
        lines.append("## Breaking Changes")
        lines.extend(breaking)
        lines.append("")
    for key in ordered_sections:
        section_entries = grouped[key]
        if section_entries:
            lines.append(f"## {categories[key]}")
            lines.extend(section_entries)
            lines.append("")
    if others:
        lines.append("## Other Changes")
        lines.extend(others)
        lines.append("")
else:
    lines.append("_No code changes since previous release._")
    lines.append("")

lines.append("## Deployment Details")
lines.append(f"- Image Tag: {os.environ.get('IMAGE_TAG', 'latest')}")
lines.append(f"- Namespace: {os.environ.get('K8S_NAMESPACE_PROD', 'prod')}")
lines.append(f"- Registry: {os.environ.get('REGISTRY', 'docker.io/alejandramantillac')}")
lines.append("")
lines.append("---")
lines.append("Generated automatically by Jenkins CI.")

release_notes = "\n".join(lines).strip() + "\n"
with open("release_notes.md", "w", encoding="utf-8") as fh:
    fh.write(release_notes)
with open("CHANGELOG.md", "w", encoding="utf-8") as fh:
    fh.write(release_notes)

print(release_notes)
PY

git add CHANGELOG.md release_notes.md

echo "Creating release tag ${RELEASE_TAG}..."
if git rev-parse "${RELEASE_TAG}" >/dev/null 2>&1; then
    git tag -d "${RELEASE_TAG}" >/dev/null 2>&1 || true
fi
git tag -a "${RELEASE_TAG}" -m "Release ${RELEASE_VERSION}"

git remote set-url origin "https://${GITHUB_TOKEN}@${REPO_URL#https://}"
git push origin "${RELEASE_TAG}"

RELEASE_BODY_JSON=$(python3 - <<'PY'
import json
print(json.dumps(open("release_notes.md", "r", encoding="utf-8").read()))
PY
)

cat > release_payload.json <<EOF
{
  "tag_name": "${RELEASE_TAG}",
  "name": "Release ${RELEASE_VERSION}",
  "body": ${RELEASE_BODY_JSON},
  "draft": false,
  "prerelease": false
}
EOF

echo "Publishing GitHub Release..."
API_STATUS=$(curl -s -o release_response.json -w "%{http_code}" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST "https://api.github.com/repos/${REPO_SLUG}/releases" \
  -d @release_payload.json || true)

if [[ "$API_STATUS" != "201" ]]; then
    echo "⚠️  Failed to create GitHub Release (HTTP ${API_STATUS}). Response:"
    cat release_response.json
else
    echo "✓ GitHub Release created."
fi

echo ""
echo "Release notes available in release_notes.md and published to GitHub Releases."
