#!/bin/bash
# Links chart skills to ~/.cursor/skills/
# Run from this directory, or re-run to refresh after pulling updates.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR=~/.cursor/skills

echo "Linking chart skills from: ${SCRIPT_DIR}"

# new-helm-chart
rm -rf "${SKILLS_DIR}/new-helm-chart"
mkdir -p "${SKILLS_DIR}/new-helm-chart"
ln -f "${SCRIPT_DIR}/docs/new-helm-chart/SKILL.md" "${SKILLS_DIR}/new-helm-chart/SKILL.md"
cp -r "${SCRIPT_DIR}/docs/references" "${SKILLS_DIR}/new-helm-chart/"

# migrate-helm-chart
rm -rf "${SKILLS_DIR}/migrate-helm-chart"
mkdir -p "${SKILLS_DIR}/migrate-helm-chart"
ln -f "${SCRIPT_DIR}/docs/migrate-helm-chart/SKILL.md" "${SKILLS_DIR}/migrate-helm-chart/SKILL.md"
cp -r "${SCRIPT_DIR}/docs/references" "${SKILLS_DIR}/migrate-helm-chart/"

# modify-chart
rm -rf "${SKILLS_DIR}/modify-chart"
mkdir -p "${SKILLS_DIR}/modify-chart"
ln -f "${SCRIPT_DIR}/docs/modify-chart/SKILL.md" "${SKILLS_DIR}/modify-chart/SKILL.md"
cp -r "${SCRIPT_DIR}/docs/references" "${SKILLS_DIR}/modify-chart/"

echo "✓ Linked: new-helm-chart, migrate-helm-chart, modify-chart"
