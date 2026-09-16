#!/usr/bin/env bash
# Deploy AI Genie Factory to Databricks Genie Code.
#
# Deploys:
#   AGENTS.md          → .assistant_instructions.md  (always-on constraints)
#   skills/*/SKILL.md  → .assistant/skills/<name>/    (on-demand skills)
#   brand/*            → .assistant/brand/            (logo assets)
#   apps/*/APP.md      → .assistant/apps/<name>/      (app spec references)
#
# Workspace-wide (workspace admin):
#   ./deploy.sh --workspace --profile DEFAULT
#
# Personal (resolved from CLI identity):
#   ./deploy.sh --profile DEFAULT
#   ./deploy.sh --profile DEFAULT --user user@example.com

set -euo pipefail

PROFILE="DEFAULT"
SCOPE="personal"
USERNAME=""
DRY_RUN="false"

usage() {
  echo "Usage: $0 [--workspace] [--profile NAME] [--user EMAIL] [--dry-run]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      SCOPE="workspace"
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --user)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      USERNAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

DBX=(databricks --profile "$PROFILE")

if [[ "$SCOPE" == "workspace" ]]; then
  BASE="/Workspace/.assistant"
  INSTRUCTIONS_TARGET="/Workspace/.assistant_workspace_instructions.md"
else
  if [[ -z "$USERNAME" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      USERNAME="<authenticated-user>"
    else
      USERNAME="$("${DBX[@]}" current-user me -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["userName"])')"
    fi
  fi
  BASE="/Users/${USERNAME}/.assistant"
  INSTRUCTIONS_TARGET="/Users/${USERNAME}/.assistant_instructions.md"
fi

SKILLS_TARGET="${BASE}/skills"

if [[ ! -f AGENTS.md ]]; then
  echo "AGENTS.md not found. Run this script from the repository root." >&2
  exit 1
fi

instruction_chars="$(wc -m < AGENTS.md | tr -d ' ')"
if (( instruction_chars > 20000 )); then
  echo "AGENTS.md has ${instruction_chars} characters; Genie Code only reads the first 20,000." >&2
  exit 1
fi

skill_count=0
for skill_file in skills/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue
  skill_count=$((skill_count + 1))
done

if (( skill_count == 0 )); then
  echo "No valid skills found. Expected skills/<name>/SKILL.md." >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

upload_raw() {
  local source="$1"
  local target="$2"
  run "${DBX[@]}" workspace import "$target" \
    --file "$source" \
    --format RAW \
    --overwrite
}

BRAND_TARGET="${BASE}/brand"
APPS_TARGET="${BASE}/apps"

echo "AI Genie Factory — Databricks deployment"
echo "Profile: ${PROFILE}"
echo "Scope: ${SCOPE}"
echo "Instructions: ${INSTRUCTIONS_TARGET}"
echo "Skills: ${SKILLS_TARGET}/<name>/SKILL.md"
echo "Brand: ${BRAND_TARGET}/"
echo "Apps: ${APPS_TARGET}/<name>/APP.md"
echo ""

# --- Instructions ---
run "${DBX[@]}" workspace mkdirs "$BASE"
upload_raw "AGENTS.md" "$INSTRUCTIONS_TARGET"
echo "  Uploaded AGENTS.md"

# --- Skills ---
run "${DBX[@]}" workspace mkdirs "$SKILLS_TARGET"
for skill_file in skills/*/SKILL.md; do
  [[ -f "$skill_file" ]] || continue
  skill_name="$(basename "$(dirname "$skill_file")")"
  remote_dir="${SKILLS_TARGET}/${skill_name}"
  run "${DBX[@]}" workspace mkdirs "$remote_dir"
  upload_raw "$skill_file" "${remote_dir}/SKILL.md"
  echo "  Uploaded skill: ${skill_name}"
done

# --- Brand assets (logos, etc.) ---
if [[ -d brand ]]; then
  run "${DBX[@]}" workspace mkdirs "$BRAND_TARGET"
  brand_count=0
  for brand_file in brand/*; do
    [[ -f "$brand_file" ]] || continue
    filename="$(basename "$brand_file")"
    upload_raw "$brand_file" "${BRAND_TARGET}/${filename}"
    brand_count=$((brand_count + 1))
  done
  echo "  Uploaded ${brand_count} brand asset(s)"
else
  echo "  Skipped brand/ (not found)"
fi

# --- App specs (APP.md per app) ---
if [[ -d apps ]]; then
  run "${DBX[@]}" workspace mkdirs "$APPS_TARGET"
  app_count=0
  for app_dir in apps/*/; do
    [[ -d "$app_dir" ]] || continue
    app_name="$(basename "$app_dir")"
    remote_app_dir="${APPS_TARGET}/${app_name}"
    run "${DBX[@]}" workspace mkdirs "$remote_app_dir"
    for app_file in "${app_dir}"*.md; do
      [[ -f "$app_file" ]] || continue
      filename="$(basename "$app_file")"
      upload_raw "$app_file" "${remote_app_dir}/${filename}"
    done
    app_count=$((app_count + 1))
  done
  echo "  Uploaded ${app_count} app spec(s)"
else
  echo "  Skipped apps/ (not found)"
fi

echo ""
echo "Deployment complete. Start a new Genie Code chat to load changed skills."
if [[ "$SCOPE" == "workspace" ]]; then
  echo "Admin follow-up: restrict write access on /Workspace/.assistant and the workspace instructions file."
fi
