#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-6565}"
NODE_ENV="${NODE_ENV:-production}"
PID_FILE="${PID_FILE:-server.pid}"
LOG_FILE="${LOG_FILE:-server.log}"

if ! command -v node >/dev/null 2>&1; then
  echo "node 未安装或不在 PATH 中。请先安装 Node.js 22.5 或更高版本。"
  exit 1
fi

stop_pid() {
  local pid="$1"
  local label="${2:-旧服务}"
  if [ -z "$pid" ] || ! kill -0 "$pid" >/dev/null 2>&1; then
    return 0
  fi
  echo "停止${label} pid=$pid"
  kill "$pid" >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "强制停止${label} pid=$pid"
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
}

port_pids() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :$PORT" 2>/dev/null \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
      | sort -u
  elif command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | sort -u
  elif command -v fuser >/dev/null 2>&1; then
    fuser "$PORT"/tcp 2>/dev/null | tr ' ' '\n' | sed '/^$/d' | sort -u
  fi
}

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  stop_pid "$OLD_PID" "pid 文件中的旧服务"
fi

for PORT_PID in $(port_pids); do
  if [ "$PORT_PID" != "$$" ]; then
    stop_pid "$PORT_PID" "占用端口 $PORT 的进程"
  fi
done

echo "启动服务 HOST=$HOST PORT=$PORT"
HOST="$HOST" PORT="$PORT" NODE_ENV="$NODE_ENV" nohup node --experimental-sqlite server.js > "$LOG_FILE" 2>&1 &
NEW_PID="$!"
echo "$NEW_PID" > "$PID_FILE"
sleep 0.8

if kill -0 "$NEW_PID" >/dev/null 2>&1; then
  echo "已启动 pid=$NEW_PID"
  echo "访问地址：http://$HOST:$PORT"
  echo "日志：$ROOT_DIR/$LOG_FILE"
else
  echo "启动失败，请查看日志：$ROOT_DIR/$LOG_FILE"
  tail -n 80 "$LOG_FILE" || true
  exit 1
fi
