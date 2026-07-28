"""FastAPI boundary for the Godot client.

The existing Node service remains the authoritative poker engine during the
migration.  This process owns the public API used by the new Godot client and
proxies both HTTP and WebSocket traffic without changing any game message.
That preserves fairness proofs, side-pot settlement and reconnect semantics.
"""

from __future__ import annotations

import asyncio
import os
from contextlib import suppress

import httpx
import websockets
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

LEGACY_HTTP_URL = os.getenv("LEGACY_HTTP_URL", "http://127.0.0.1:6565").rstrip("/")
LEGACY_WS_URL = os.getenv("LEGACY_WS_URL", LEGACY_HTTP_URL.replace("http://", "ws://", 1).replace("https://", "wss://", 1) + "/ws")
REQUEST_TIMEOUT_SECONDS = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "20"))

app = FastAPI(title="Hold'em FastAPI Gateway", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[item for item in os.getenv("CORS_ORIGINS", "*").split(",") if item],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def forwarded_headers(headers: dict[str, str]) -> dict[str, str]:
    """Remove hop-by-hop headers; keep token/cookie auth unchanged."""
    blocked = {"host", "content-length", "connection", "upgrade", "keep-alive"}
    return {key: value for key, value in headers.items() if key.lower() not in blocked}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "engine": LEGACY_HTTP_URL, "mode": "compatibility-gateway"}


@app.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
async def proxy_api(path: str, request: Request) -> Response:
    """Keep the legacy REST contract intact for Godot and future clients."""
    target = f"{LEGACY_HTTP_URL}/api/{path}"
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS, follow_redirects=False) as client:
            upstream = await client.request(
                request.method,
                target,
                params=request.query_params,
                content=await request.body(),
                headers=forwarded_headers(dict(request.headers)),
            )
    except httpx.HTTPError as error:
        return JSONResponse(status_code=502, content={"error": f"牌局引擎不可用：{error}"})
    content_type = upstream.headers.get("content-type", "application/json")
    return Response(content=upstream.content, status_code=upstream.status_code, media_type=content_type)


@app.websocket("/ws")
async def proxy_websocket(client: WebSocket) -> None:
    """Bidirectional transparent WebSocket relay for real-time game events."""
    await client.accept()
    query = f"?{client.url.query}" if client.url.query else ""
    try:
        # The token is deliberately kept in the query string.  Do not forward
        # the client's Sec-WebSocket-* handshake headers: the upstream client
        # creates its own values, and duplicate keys can leave a connection
        # open without relaying its first ``hello`` packet.
        async with websockets.connect(f"{LEGACY_WS_URL}{query}") as engine:
            async def client_to_engine() -> None:
                while True:
                    message = await client.receive()
                    if message["type"] == "websocket.disconnect":
                        return
                    if message.get("text") is not None:
                        await engine.send(message["text"])
                    elif message.get("bytes") is not None:
                        await engine.send(message["bytes"])

            async def engine_to_client() -> None:
                async for message in engine:
                    if isinstance(message, bytes):
                        await client.send_bytes(message)
                    else:
                        await client.send_text(message)

            first, pending = await asyncio.wait(
                [asyncio.create_task(client_to_engine()), asyncio.create_task(engine_to_client())],
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
            for task in first | pending:
                with suppress(asyncio.CancelledError, WebSocketDisconnect):
                    await task
    except (OSError, websockets.WebSocketException) as error:
        with suppress(Exception):
            await client.send_json({"type": "error", "message": f"牌局引擎连接失败：{error}"})
        with suppress(Exception):
            await client.close(code=1011)
