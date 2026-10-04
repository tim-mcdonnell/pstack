#!/usr/bin/env bash
# Keep this mirror in sync with cursor/plugins/pstack.
#
#   sync/sync.sh check    exit 0 = up to date, exit 10 = upstream moved (prints old/new rev)
#   sync/sync.sh pull     refresh the `upstream` branch, merge it into `main`, print the
#                         Cursor-ism report for the upstream delta. Leaves conflicts in place.
#   sync/sync.sh report   print Cursor-specific lines added upstream since the last sync
#   sync/sync.sh push     push main + upstream to origin
#
# Mechanics are deterministic; judgment (conflict resolution, rewriting new
# Cursor-only instructions) is the sync agent's job. See MIRROR.md.
set -euo pipefail

UPSTREAM_URL=https://github.com/cursor/plugins.git
UPSTREAM_DIR=pstack
REPO=$(git rev-parse --show-toplevel)
WORK=${PSTACK_SYNC_WORK:-/tmp/pstack-sync}
CLONE=$WORK/cursor-plugins
UPWT=$WORK/upstream-wt
REV_FILE=$REPO/.upstream-rev
CURSORISMS='\.cursor/|\.cursor-plugin|\.mdc\b|agent-transcripts|cursor-team-kit|create-skill|\bAskQuestion\b|\bTask\b tool|subagent_type: *"?generalPurpose|environment: *"cloud"|cloud_base_branch|[Cc]ursor cloud|[Bb]ugbot|cursor\.com|cursor agent'

cd "$REPO"

fetch_upstream() {
  mkdir -p "$WORK"
  if [ -d "$CLONE/.git" ]; then
    git -C "$CLONE" fetch -q --depth 1 origin main && git -C "$CLONE" reset -q --hard origin/main
  else
    rm -rf "$CLONE"
    git clone -q --depth 1 --filter=blob:none --sparse "$UPSTREAM_URL" "$CLONE"
    git -C "$CLONE" sparse-checkout set "$UPSTREAM_DIR"
  fi
  NEW_REV=$(git -C "$CLONE" rev-parse --short HEAD)
  NEW_VER=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CLONE/$UPSTREAM_DIR/.cursor-plugin/plugin.json")
  OLD_REV=$(cat "$REV_FILE" 2>/dev/null || echo none)
}

upstream_delta_files() {
  # Only the pstack/ subtree matters. Compare the upstream branch before/after.
  git diff --name-only "upstream@{1}" upstream 2>/dev/null || git diff --name-only "$1" upstream
}

cmd_check() {
  fetch_upstream
  if [ "$NEW_REV" = "$OLD_REV" ]; then
    echo "up to date: cursor/plugins/pstack @ $OLD_REV (v$NEW_VER)"; exit 0
  fi
  echo "upstream moved: $OLD_REV -> $NEW_REV (v$NEW_VER)"
  # Did pstack/ itself change? cursor/plugins holds other plugins too.
  if [ "$OLD_REV" != none ] && git -C "$CLONE" fetch -q --depth 1 origin "$OLD_REV" 2>/dev/null; then
    if git -C "$CLONE" diff --quiet "$OLD_REV" HEAD -- "$UPSTREAM_DIR"; then
      echo "no changes under $UPSTREAM_DIR/; recording new rev only"
      printf '%s\n' "$NEW_REV" > "$REV_FILE"; exit 0
    fi
  fi
  exit 10
}

cmd_pull() {
  fetch_upstream
  [ -z "$(git status --porcelain)" ] || { echo "working tree not clean; commit or stash first" >&2; exit 2; }
  git switch -q main
  PREV_UP=$(git rev-parse upstream)
  rm -rf "$UPWT"; git worktree prune
  git worktree add -q "$UPWT" upstream
  rsync -a --delete --exclude .git "$CLONE/$UPSTREAM_DIR/" "$UPWT/"
  if [ -n "$(git -C "$UPWT" status --porcelain)" ]; then
    git -C "$UPWT" add -A
    git -C "$UPWT" commit -q -m "upstream: cursor/plugins/pstack @ $NEW_REV ($NEW_VER)"
  fi
  git worktree remove --force "$UPWT"
  printf '%s\n' "$NEW_REV" > "$REV_FILE"
  if git merge --no-edit -m "Sync upstream cursor/plugins/pstack @ $NEW_REV ($NEW_VER)" upstream; then
    cp agents/comment-sicko.md skills/no-comments/references/comment-sicko.md
    git add -A
    git commit -q --amend --no-edit
    echo "MERGED cleanly. Now review the report below and rewrite any new Cursor-only instructions."
  else
    cp agents/comment-sicko.md skills/no-comments/references/comment-sicko.md || true
    git add .upstream-rev skills/no-comments/references/comment-sicko.md
    echo "CONFLICTS. Resolve them (keep upstream's new meaning, reapply the harness-neutral wording), then: git add -A && git commit"
  fi
  echo; echo "== Upstream delta (files) =="; git diff --stat "$PREV_UP" upstream | tail -n 40
  echo; cmd_report "$PREV_UP"
}

cmd_report() {
  local base=${1:-upstream@{1}}
  echo "== New Cursor-specific lines added upstream since $base =="
  git diff "$base" upstream -- skills agents docs README.md automations \
    | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nE "$CURSORISMS" || echo "(none)"
  echo
  echo "== Files added upstream (new skills need a full read) =="
  git diff --diff-filter=A --name-only "$base" upstream || true
}

cmd_push() {
  git push origin main upstream
}

case "${1:-}" in
  check) cmd_check ;;
  pull) cmd_pull ;;
  report) cmd_report "${2:-upstream@{1}}" ;;
  push) cmd_push ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
