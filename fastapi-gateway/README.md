# FastAPI 网关（Godot 新前端）

这个目录是新的前后端边界。Godot 只访问它；它再透明转发给现有 Node 牌局引擎，因此不会丢失已经验证的边池、断线恢复、公平哈希、邮箱验证码、聊天、荷官、头像与结算逻辑。

## 本地启动

先启动旧引擎：

```powershell
npm start
```

再启动网关：

```powershell
cd fastapi-gateway
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:LEGACY_HTTP_URL = "http://127.0.0.1:3000"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Godot 默认连接 `http://127.0.0.1:8000` 和 `ws://127.0.0.1:8000/ws`。部署时将两个进程放到同一台机器，并让 Nginx 对外只暴露 FastAPI。

## 迁移策略

这不是“半套重写”。当前 FastAPI 是兼容网关：新 Godot 客户端从第一天起就能使用已有完整规则。待稳定后可将规则按模块迁入 FastAPI（认证/账户、房间、牌局状态机、结算），每次迁移仍维持同一 REST 与 WebSocket 合约。
