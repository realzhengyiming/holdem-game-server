extends Control

const FELT := Color("#176f76")
const FELT_DARK := Color("#0d353f")
const GOLD := Color("#f5c95c")
const INK := Color("#071520")
const SEAT_COLORS := [Color("#314452"), Color("#473842"), Color("#304956"), Color("#3d424b")]

var screen := "auth"
var user: Dictionary = {}
var rooms: Array = []
var snapshot: Dictionary = {}
var _font: Font
var _title: Label
var _status: Label
var _overlay: Control
var _action_bar: PanelContainer
var _seat_rects: Array[Rect2] = []
var _email: LineEdit
var _username: LineEdit
var _code: LineEdit
var _notice: Label
var _room_name: LineEdit
@onready var api: PokerApiClient = $ApiClient

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_adapt_layout)
	gui_input.connect(_on_table_input)
	api.event_received.connect(_on_api_event)
	api.request_failed.connect(_on_api_error)
	api.connection_changed.connect(_on_connection_changed)
	_build_header()
	_show_auth()
	_adapt_layout()

func _build_header() -> void:
	_title = Label.new()
	_title.text = "HOLD'EM  ROYALE"
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("#f7f2e4"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_status = Label.new()
	_status.text = "连接 FastAPI，进入纯粹的牌桌体验"
	_status.add_theme_font_override("font", _font)
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("#a6d7d6"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091b27f2")
	style.border_color = Color("#2b6770")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(text: String, color: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(94, 38)
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(action)
	return button

func _label(text: String, font_size: int = 14, color: Color = Color("#d8ece6")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _clear_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _show_auth() -> void:
	screen = "auth"
	snapshot.clear()
	_clear_overlay()
	var panel := _panel()
	panel.position = Vector2(size.x * 0.5 - 180, max(98.0, size.y * 0.5 - 170))
	panel.size = Vector2(360, 340)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("登录牌桌", 22, Color("#f7d477")))
	box.add_child(_label("邮箱验证码登录。未配置 SMTP 时，验证码会自动回填。", 12, Color("#a9c4bf")))
	_email = LineEdit.new()
	_email.placeholder_text = "邮箱，例如 name@example.com"
	_email.custom_minimum_size = Vector2(0, 36)
	box.add_child(_email)
	_username = LineEdit.new()
	_username.placeholder_text = "昵称（首次登录可填）"
	_username.custom_minimum_size = Vector2(0, 36)
	box.add_child(_username)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	_code = LineEdit.new()
	_code.placeholder_text = "六位验证码"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 36)
	code_row.add_child(_code)
	code_row.add_child(_button("获取验证码", "#195b6a", _request_code))
	box.add_child(code_row)
	box.add_child(_button("进入大厅", "#1d887c", _login))
	_notice = _label("", 12, Color("#f6cf68"))
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_notice)
	add_child(panel)
	_overlay = panel
	queue_redraw()

func _request_code() -> void:
	if _email.text.strip_edges().is_empty():
		_set_notice("请先填写邮箱。")
		return
	api.request_code(_email.text.strip_edges())
	_set_notice("正在获取验证码…")

func _login() -> void:
	if _email.text.strip_edges().is_empty() or _code.text.strip_edges().length() != 6:
		_set_notice("请输入邮箱和六位验证码。")
		return
	api.login_with_code(_email.text.strip_edges(), _code.text.strip_edges(), _username.text.strip_edges())
	_set_notice("正在登录并建立实时连接…")

func _show_lobby() -> void:
	screen = "lobby"
	_clear_overlay()
	var panel := _panel()
	panel.position = Vector2(max(14.0, size.x * 0.5 - 310), 84)
	panel.size = Vector2(min(620.0, size.x - 28), max(330.0, size.y - 170))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	box.add_child(_label("选择牌桌", 22, Color("#f7d477")))
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 7)
	_room_name = LineEdit.new()
	_room_name.placeholder_text = "新牌桌名称"
	_room_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name.custom_minimum_size = Vector2(0, 36)
	top_row.add_child(_room_name)
	top_row.add_child(_button("创建", "#c78e31", _create_room))
	top_row.add_child(_button("刷新", "#195b6a", func(): api.fetch_rooms()))
	box.add_child(top_row)
	var list := ScrollContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	list.add_child(list_box)
	if rooms.is_empty():
		list_box.add_child(_label("暂无在线牌桌，创建一个开始吧。", 14, Color("#a9c4bf")))
	else:
		for room in rooms:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var info := _label("%s  ·  %s/%s 人  ·  盲注 %s/%s" % [str(room.get("name", "牌桌")), str(room.get("seats", 0)), str(room.get("maxSeats", 8)), str(room.get("smallBlind", 5)), str(room.get("bigBlind", 10))], 14)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var room_id := str(room.get("id", ""))
			row.add_child(_button("进入", "#1d887c", func(): _join_room(room_id)))
			list_box.add_child(row)
	box.add_child(list)
	box.add_child(_button("退出登录", "#473842", _show_auth))
	add_child(panel)
	_overlay = panel
	queue_redraw()

func _create_room() -> void:
	var name := _room_name.text.strip_edges()
	api.create_room(name if not name.is_empty() else "%s 的牌桌" % str(user.get("username", "玩家")))
	_status.text = "正在创建牌桌…"

func _join_room(room_id: String) -> void:
	api.send_event({"type": "joinRoom", "roomId": room_id})
	_status.text = "正在进入牌桌…"

func _show_table() -> void:
	screen = "table"
	_clear_overlay()
	_build_action_bar()
	queue_redraw()

func _build_action_bar() -> void:
	if is_instance_valid(_action_bar):
		_action_bar.queue_free()
	_action_bar = _panel()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_action_bar.add_child(row)
	var mine := _my_seat()
	var game: Dictionary = snapshot.get("game", {})
	var status := str(game.get("status", "waiting"))
	row.add_child(_button("大厅", "#314452", func(): api.send_event({"type":"leaveRoom"}); _show_lobby()))
	if mine.is_empty():
		row.add_child(_button("点击空座入座", "#195b6a", func(): _set_status("点击牌桌周围的空座位入座")))
	else:
		if status == "waiting" or status == "showdown":
			row.add_child(_button("准备", "#1d887c", func(): api.send_event({"type":"ready"})))
			if bool(snapshot.get("room", {}).get("canStart", false)):
				row.add_child(_button("开始发牌", "#c78e31", func(): api.send_event({"type":"startHand"})))
		else:
			var call_amount: int = max(0, int(game.get("currentBet", 0)) - int(mine.get("bet", 0)))
			row.add_child(_button("弃牌", "#772f3a", func(): _action("fold")))
			row.add_child(_button("过牌" if call_amount == 0 else "跟注 %d" % call_amount, "#1d887c", func(): _action("check" if call_amount == 0 else "call")))
			row.add_child(_button("下注" if int(game.get("currentBet", 0)) == 0 else "加注", "#c78e31", func(): _action("bet" if int(game.get("currentBet", 0)) == 0 else "raise")))
	add_child(_action_bar)
	_adapt_layout()

func _action(action: String) -> void:
	var game: Dictionary = snapshot.get("game", {})
	var amount: int = 0
	if action == "bet":
		amount = max(int(game.get("bigBlind", 10)), int(game.get("minRaise", 10)))
	elif action == "raise":
		amount = int(game.get("minimumFullWagerTotal", int(game.get("currentBet", 0)) + int(game.get("minRaise", 10))))
	api.send_event({"type":"action", "action":action, "amount":amount})

func _my_seat() -> Dictionary:
	for seat in snapshot.get("seats", []):
		if seat is Dictionary and str(seat.get("userId", "")) == str(user.get("id", "")):
			return seat
	return {}

func _adapt_layout() -> void:
	_title.position = Vector2(0, 12)
	_title.size = Vector2(size.x, 30)
	_status.position = Vector2(0, 43)
	_status.size = Vector2(size.x, 22)
	if is_instance_valid(_overlay):
		if screen == "auth":
			_overlay.position = Vector2(size.x * 0.5 - min(180.0, size.x * 0.46), max(98.0, size.y * 0.5 - 170))
			_overlay.size = Vector2(min(360.0, size.x - 24), 340)
		elif screen == "lobby":
			_overlay.position = Vector2(max(14.0, size.x * 0.5 - min(310.0, size.x * 0.46)), 84)
			_overlay.size = Vector2(min(620.0, size.x - 28), max(330.0, size.y - 170))
	if is_instance_valid(_action_bar):
		var height := 62.0
		_action_bar.position = Vector2(max(8.0, size.x * 0.10), size.y - height - 12)
		_action_bar.size = Vector2(min(size.x - 16, 680.0), height)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#061722"))
	for x in range(0, int(size.x) + 48, 48):
		for y in range(0, int(size.y) + 48, 48):
			draw_circle(Vector2(x + 20, y + 20), 2.0, Color("#1e3c4b"))
	if screen != "table":
		return
	var portrait := size.y > size.x
	var action_space := 98.0 if portrait else 84.0
	var table_center := Vector2(size.x * 0.5, (size.y + 84 - action_space) * 0.52)
	var table_size := Vector2(min(size.x * (0.90 if portrait else 0.76), 860.0), min(size.y * (0.40 if portrait else 0.54), 365.0))
	var table_rect := Rect2(table_center - table_size * 0.5, table_size)
	draw_style_box(_rounded_box(Color("#0b2833"), 42), table_rect.grow(16))
	draw_style_box(_rounded_box(FELT_DARK, 38), table_rect.grow(6))
	draw_style_box(_rounded_box(FELT, 34), table_rect)
	draw_arc(table_center, table_size.x * 0.30, 0, TAU, 80, Color("#75bdad66"), 1.5)
	_draw_center(table_center, portrait)
	_draw_seats(table_center, table_size, portrait)

func _rounded_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box

func _draw_center(center: Vector2, portrait: bool) -> void:
	var board: Array = snapshot.get("game", {}).get("board", [])
	var card_width := 50.0 if portrait else 58.0
	var card_height := card_width * 1.35
	var start: float = center.x - (max(1, board.size()) * (card_width + 5) - 5) * 0.5
	for index in board.size():
		_draw_card(Vector2(start + index * (card_width + 5), center.y - card_height * 0.16), Vector2(card_width, card_height), _card_text(str(board[index])))
	var game: Dictionary = snapshot.get("game", {})
	draw_string(_font, Vector2(center.x - 44, center.y + card_height + 23), "底池  %s" % str(game.get("pot", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d9eee6"))
	draw_string(_font, Vector2(center.x - 75, center.y - card_height * 0.62), str(game.get("lastAction", "等待发牌")), HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Color("#d9eee6"))

func _draw_seats(center: Vector2, table_size: Vector2, portrait: bool) -> void:
	var seat_data: Array = snapshot.get("seats", [])
	var count: int = max(2, seat_data.size())
	var radius_x := table_size.x * 0.58
	var radius_y := table_size.y * (0.88 if portrait else 0.80)
	var seat_size := Vector2(112 if portrait else 138, 54 if portrait else 60)
	_seat_rects.clear()
	for i in count:
		var angle: float = -PI * 0.5 + TAU * float(i) / count
		var rect := Rect2(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y) - seat_size * 0.5, seat_size)
		_seat_rects.append(rect)
		var seat = seat_data[i] if i < seat_data.size() else null
		_draw_seat(rect, seat, i)

func _draw_seat(rect: Rect2, seat, index: int) -> void:
	if not (seat is Dictionary):
		draw_style_box(_rounded_box(Color("#10242d"), 9), rect)
		draw_string(_font, rect.position + Vector2(0, rect.size.y * 0.58), "+ 入座", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color("#8fc4bd"))
		return
	var is_me := str(seat.get("userId", "")) == str(user.get("id", ""))
	var color: Color = Color("#d49a38") if is_me else SEAT_COLORS[index % SEAT_COLORS.size()]
	draw_style_box(_rounded_box(Color("#0b1821e8"), 10), rect.grow(2))
	draw_style_box(_rounded_box(color.darkened(0.45), 8), rect)
	draw_circle(rect.position + Vector2(22, rect.size.y * 0.5), 16, color)
	var name := str(seat.get("username", "玩家"))
	draw_string(_font, rect.position + Vector2(16, rect.size.y * 0.5 + 5), name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(_font, rect.position + Vector2(43, 21), name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 47, 13, Color("#f2f6ef"))
	draw_string(_font, rect.position + Vector2(43, 42), "◉ %s" % str(seat.get("chips", 0)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 47, 11, Color("#f6cf68"))
	var hole: Array = seat.get("hole", [])
	for j in min(2, hole.size()):
		_draw_card(rect.position + Vector2(43 + j * 25, -32), Vector2(23, 32), _card_text(str(hole[j])))

func _draw_card(pos: Vector2, card_size: Vector2, value: String) -> void:
	draw_style_box(_rounded_box(Color("#f8f6ef"), 5), Rect2(pos, card_size))
	var red := value.contains("♥") or value.contains("♦")
	var color := Color("#bd2f37") if red else Color("#172130")
	draw_string(_font, pos + Vector2(5, card_size.y * 0.52), value, HORIZONTAL_ALIGNMENT_LEFT, card_size.x - 7, int(card_size.x * 0.35), color)

func _card_text(card: String) -> String:
	if card == "??": return "?"
	var suits := {"s":"♠", "h":"♥", "d":"♦", "c":"♣"}
	if card.length() < 2: return card
	var rank := card.left(card.length() - 1).replace("T", "10")
	return rank + str(suits.get(card.right(1), ""))

func _on_table_input(event: InputEvent) -> void:
	if screen != "table" or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _seat_rects.size():
		if _seat_rects[i].has_point(event.position):
			var seat_data: Array = snapshot.get("seats", [])
			if i < seat_data.size() and not (seat_data[i] is Dictionary):
				api.send_event({"type":"sit", "seat":i})
				_set_status("正在入座…")
			return

func _on_api_event(payload: Dictionary) -> void:
	if payload.has("devCode"):
		_code.text = str(payload.devCode)
		_set_notice("本机验证码已填入，点击“进入大厅”。")
		return
	if payload.has("token") and payload.has("user"):
		user = payload.user
		_show_lobby()
		api.fetch_rooms()
		_set_status("欢迎回来，%s。正在连接实时牌局…" % str(user.get("username", "玩家")))
		return
	if payload.has("room") and not payload.has("game"):
		_join_room(str(payload.room.get("id", "")))
		return
	if payload.has("rooms"):
		rooms = payload.rooms
		if screen == "lobby": _show_lobby()
		return
	if str(payload.get("type", "")) == "lobby":
		rooms = payload.get("rooms", [])
		if screen == "lobby": _show_lobby()
		return
	if str(payload.get("type", "")) == "roomState":
		snapshot = payload
		_show_table()
		_set_status("牌桌 #%s  ·  盲注 %s/%s" % [str(snapshot.get("room", {}).get("id", "")), str(snapshot.get("room", {}).get("smallBlind", 5)), str(snapshot.get("room", {}).get("bigBlind", 10))])
		return
	if str(payload.get("type", "")) == "error":
		_set_status(str(payload.get("error", "操作失败")))

func _on_api_error(message: String) -> void:
	_set_notice(message)
	_set_status("FastAPI 未连接：" + message)

func _on_connection_changed(online: bool) -> void:
	if online:
		_set_status("FastAPI 实时连接已建立")

func _set_notice(message: String) -> void:
	if is_instance_valid(_notice): _notice.text = message

func _set_status(message: String) -> void:
	if is_instance_valid(_status): _status.text = message
