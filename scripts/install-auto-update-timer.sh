#!/usr/bin/env bash
# Install a systemd timer that runs update-and-restart.sh once per minute.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="holdem-auto-update"
UPDATE_BRANCH="${UPDATE_BRANCH:-main}"
RUN_AS_USER="${SUDO_USER:-$USER}"
RUN_AS_GROUP="$(id -gn "$RUN_AS_USER")"
SYSTEMD_DIR="/etc/systemd/system"

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 sudo 运行：sudo UPDATE_BRANCH=$UPDATE_BRANCH bash scripts/install-auto-update-timer.sh"
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "当前系统未使用 systemd，不能安装 systemd timer。"
  exit 1
fi

cat > "$SYSTEMD_DIR/$SERVICE_NAME.service" <<EOF
[Unit]
Description=Update Hold'em server from Git and restart when changed
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$RUN_AS_USER
Group=$RUN_AS_GROUP
WorkingDirectory=$ROOT_DIR
Environment=HOME=$ROOT_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=UPDATE_BRANCH=$UPDATE_BRANCH
ExecStart=/usr/bin/env bash $ROOT_DIR/scripts/update-and-restart.sh
EOF

cat > "$SYSTEMD_DIR/$SERVICE_NAME.timer" <<EOF
[Unit]
Description=Check for Hold'em server updates every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
Persistent=true
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF

chmod +x "$ROOT_DIR/scripts/update-and-restart.sh"
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME.timer"
systemctl start "$SERVICE_NAME.service"

echo "已安装 $SERVICE_NAME.timer（分支：$UPDATE_BRANCH）。"
echo "查看状态：systemctl status $SERVICE_NAME.timer"
echo "查看日志：journalctl -u $SERVICE_NAME.service -n 100 --no-pager"
