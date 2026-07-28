class_name PokerApiClient
extends Node

signal event_received(event: Dictionary)
signal connection_changed(online: bool)
signal request_failed(message: String)

@export var gateway_url := "http://127.0.0.1:8000"
var token := ""
var socket := WebSocketPeer.new()
var _http: HTTPRequest
var _pending_events: Array[Dictionary] = []
var _socket_online := false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func request_code(email: String) -> void:
	_request_json("/api/email-code/request", HTTPClient.METHOD_POST, {"email": email})

func login_with_code(email: String, code: String, username: String = "") -> void:
	_request_json("/api/email-code/verify", HTTPClient.METHOD_POST, {"email": email, "code": code, "username": username})

func fetch_rooms() -> void:
	_request_json("/api/rooms", HTTPClient.METHOD_GET)

func create_room(name: String, small_blind: int = 5, big_blind: int = 10, starting_chips: int = 1000, max_seats: int = 8) -> void:
	_request_json("/api/rooms", HTTPClient.METHOD_POST, {
		"name": name,
		"smallBlind": small_blind,
		"bigBlind": big_blind,
		"startingChips": starting_chips,
		"maxSeats": max_seats
	})

func connect_realtime(session_token: String) -> void:
	token = session_token
	var ws_url := gateway_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws?token=" + token.uri_encode()
	socket = WebSocketPeer.new()
	var error := socket.connect_to_url(ws_url)
	if error != OK:
		request_failed.emit("无法连接牌局服务：%s" % error_string(error))

func send_event(payload: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(payload))
	else:
		_pending_events.append(payload)

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _socket_online:
			_socket_online = true
			connection_changed.emit(true)
		for pending in _pending_events:
			socket.send_text(JSON.stringify(pending))
		_pending_events.clear()
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet().get_string_from_utf8()
			var decoded = JSON.parse_string(packet)
			if decoded is Dictionary:
				event_received.emit(decoded)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _socket_online:
			_socket_online = false
			connection_changed.emit(false)

func _request_json(path: String, method: HTTPClient.Method, payload: Dictionary = {}) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var body := "" if payload.is_empty() else JSON.stringify(payload)
	var error := _http.request(gateway_url + path, headers, method, body)
	if error != OK:
		request_failed.emit("请求无法发出：%s" % error_string(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("网络请求失败")
		return
	var decoded = JSON.parse_string(body.get_string_from_utf8())
	if response_code >= 400:
		request_failed.emit(str(decoded.get("error", "请求失败")) if decoded is Dictionary else "请求失败")
		return
	if decoded is Dictionary:
		if decoded.has("token"):
			connect_realtime(str(decoded.token))
		event_received.emit(decoded)
