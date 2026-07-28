# Hold'em Royale（Godot 4 前端）

独立的新前端项目，原有 `public/` 网页版本完全保留。Godot 可导出 Windows、Android、iOS 和 Web；Web 导出后仍通过 FastAPI 网关访问牌局。

## 打开与运行

1. 安装 Godot 4.3 或更高版本。
2. 用 Godot 导入本目录的 `project.godot`。
3. 打开 `Main.tscn` 并运行；横屏、竖屏和浏览器尺寸变化会重新排布牌桌与操作栏。

牌桌画面采用纯 Godot Canvas 绘制，没有使用参考图中的人物或品牌素材。它强调大牌面、居中的公共牌、环绕座位和底部一行操作，已移除观众与反馈入口。

## 连接后端

`scripts/api_client.gd` 的默认网关为 `http://127.0.0.1:8000`。登录、房间列表和 WebSocket 消息保持与旧引擎一致：Godot 通过 FastAPI，不直接依赖 Node 地址。

## Web 导出

在 Godot 中安装 Web Export Template 后，选择 **Project → Export → Web**。部署 Web 构建时，请将网关地址改为你的 HTTPS 域名；HTTPS 页面必须连接 `wss://`。
