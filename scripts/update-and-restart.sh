#!/usr/bin/env bash
# Fetch a tracked branch and restart only after a successful fast-forward update.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UPDATE_REMOTE="${UPDATE_REMOTE:-origin}"
UPDATE_BRANCH="${UPDATE_BRANCH:-main}"
LOCK_FILE="${UPDATE_LOCK_FILE:-$ROOT_DIR/.auto-update.lock}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

if ! command -v git >/dev/null 2>&1; then
  log "git 未安装，跳过更新。"
  exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
  log "缺少 flock 命令，无法安全避免重复更新。"
  exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "已有更新任务在运行，跳过本次检查。"
  exit 0
fi

# Never let an unattended job overwrite manual edits made on the server.
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "检测到未提交的本地改动；为保护改动，跳过自动更新。"
  exit 1
fi

log "检查 $UPDATE_REMOTE/$UPDATE_BRANCH 是否有新提交。"
git fetch --quiet "$UPDATE_REMOTE" "$UPDATE_BRANCH"

LOCAL_COMMIT="$(git rev-parse HEAD)"
REMOTE_COMMIT="$(git rev-parse "$UPDATE_REMOTE/$UPDATE_BRANCH")"

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
  log "已是最新版本。"
  exit 0
fi

if git merge-base --is-ancestor "$LOCAL_COMMIT" "$REMOTE_COMMIT"; then
  log "发现更新 ${LOCAL_COMMIT:0:7} -> ${REMOTE_COMMIT:0:7}，开始快进拉取。"
  git pull --ff-only "$UPDATE_REMOTE" "$UPDATE_BRANCH"
  log "拉取成功，重启服务。"
  bash "$ROOT_DIR/scripts/restart.sh"
  log "更新并重启完成。"
  exit 0
fi

if git merge-base --is-ancestor "$REMOTE_COMMIT" "$LOCAL_COMMIT"; then
  log "本地分支领先远程；跳过自动更新和重启。"
  exit 0
fi

log "本地与远程分支已分叉；需要人工处理，跳过自动更新。"
exit 1
