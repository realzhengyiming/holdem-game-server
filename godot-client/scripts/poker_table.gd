extends Control

const FELT := Color("#176f76")
const FELT_DARK := Color("#0d353f")
const GOLD := Color("#f5c95c")
const INK := Color("#071520")
const SEAT_COLORS := [Color("#314452"), Color("#473842"), Color("#304956"), Color("#3d424b")]

var board_cards := ["A♠", "K♥", "10♦", "10♣", "7♠"]
var seats := [
	{"name":"你", "chips":"2,480", "cards":["Q♠", "10♠"], "active":true},
	{"name":"Nora", "chips":"1,760", "cards":[], "active":false},
	{"name":"Kai", "chips":"2,120", "cards":[], "active":false},
	{"name":"Mika", "chips":"960", "cards":[], "active":false},
	{"name":"Luna", "chips":"1,340", "cards":[], "active":false},
	{"name":"Ash", "chips":"2,020", "cards":[], "active":false},
	{"name":"Rin", "chips":"780", "cards":[], "active":false},
	{"name":"Bo", "chips":"1,580", "cards":[], "active":false}
]
var amount := 80
var _font: Font
var _title: Label
var _status: Label
var _action_bar: PanelContainer
@onready var api: PokerApiClient = $ApiClient

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_adapt_layout)
	api.event_received.connect(_on_api_event)
	api.request_failed.connect(_on_api_error)
	_build_hud()
	_adapt_layout()
	api.fetch_rooms()

func _build_hud() -> void:
	_title = Label.new()
	_title.text = "HOLD'EM  ROYALE"
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("#f7f2e4"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_status = Label.new()
	_status.text = "牌桌 #C2A8F6  ·  盲注 5 / 10"
	_status.add_theme_font_override("font", _font)
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("#a6d7d6"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)

	_action_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081824e8")
	style.border_color = Color("#27616b")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_action_bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_action_bar.add_child(row)
	for spec in [["弃牌", "#772f3a"], ["过牌", "#184f5a"], ["跟注 40", "#1b7b72"], ["加注", "#c78e31"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(92, 38)
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(spec[1])
		button_style.corner_radius_top_left = 8
		button_style.corner_radius_top_right = 8
		button_style.corner_radius_bottom_left = 8
		button_style.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_font_size_override("font_size", 14)
		row.add_child(button)
	add_child(_action_bar)

func _adapt_layout() -> void:
	var portrait := size.y > size.x
	_title.position = Vector2(0, 12)
	_title.size = Vector2(size.x, 30)
	_status.position = Vector2(0, 43)
	_status.size = Vector2(size.x, 22)
	var bar_height := 62.0 if portrait else 58.0
	_action_bar.position = Vector2(max(8.0, size.x * 0.12), size.y - bar_height - 12)
	_action_bar.size = Vector2(min(size.x - 16, 600.0 if not portrait else size.x - 16), bar_height)
	queue_redraw()

func _draw() -> void:
	var portrait := size.y > size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color("#061722"))
	for x in range(0, int(size.x) + 48, 48):
		for y in range(0, int(size.y) + 48, 48):
			draw_circle(Vector2(x + 20, y + 20), 2.0, Color("#1e3c4b"))
	var action_space := 98.0 if portrait else 84.0
	var table_center := Vector2(size.x * 0.5, (size.y + 68 - action_space) * 0.5)
	var table_size := Vector2(min(size.x * 0.76, 860.0), min(size.y * (0.46 if portrait else 0.56), 365.0))
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
	var card_width := 50.0 if portrait else 58.0
	var card_height := card_width * 1.35
	var start := center.x - (board_cards.size() * (card_width + 5) - 5) * 0.5
	for index in board_cards.size():
		_draw_card(Vector2(start + index * (card_width + 5), center.y - card_height * 0.16), Vector2(card_width, card_height), board_cards[index])
	draw_string(_font, Vector2(center.x - 31, center.y + card_height + 23), "底池  540", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d9eee6"))
	draw_circle(Vector2(center.x + 86, center.y + card_height + 17), 12, GOLD)
	draw_string(_font, Vector2(center.x + 81, center.y + card_height + 22), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)

func _draw_seats(center: Vector2, table_size: Vector2, portrait: bool) -> void:
	var radius_x := table_size.x * 0.58
	var radius_y := table_size.y * (0.80 if portrait else 0.76)
	var seat_size := Vector2(120 if portrait else 140, 56 if portrait else 64)
	for i in seats.size():
		var angle := -PI * 0.5 + TAU * float(i) / seats.size()
		var pos := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y) - seat_size * 0.5
		_draw_seat(Rect2(pos, seat_size), seats[i], i)

func _draw_seat(rect: Rect2, seat: Dictionary, index: int) -> void:
	var color: Color = Color("#d49a38") if seat.active else SEAT_COLORS[index % SEAT_COLORS.size()]
	draw_style_box(_rounded_box(Color("#0b1821e8"), 10), rect.grow(2))
	draw_style_box(_rounded_box(color.darkened(0.45), 8), rect)
	draw_circle(rect.position + Vector2(24, rect.size.y * 0.5), 17, color)
	draw_string(_font, rect.position + Vector2(18, rect.size.y * 0.5 + 6), seat.name.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(_font, rect.position + Vector2(47, 23), seat.name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 53, 14, Color("#f2f6ef"))
	draw_string(_font, rect.position + Vector2(47, 43), "◉ " + seat.chips, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 53, 12, Color("#f6cf68"))
	if not seat.cards.is_empty():
		for j in seat.cards.size():
			_draw_card(rect.position + Vector2(47 + j * 26, -35), Vector2(24, 34), seat.cards[j])

func _draw_card(pos: Vector2, card_size: Vector2, value: String) -> void:
	draw_style_box(_rounded_box(Color("#f8f6ef"), 5), Rect2(pos, card_size))
	var red := value.contains("♥") or value.contains("♦")
	var color := Color("#bd2f37") if red else Color("#172130")
	draw_string(_font, pos + Vector2(6, card_size.y * 0.48), value, HORIZONTAL_ALIGNMENT_LEFT, card_size.x - 8, int(card_size.x * 0.35), color)

func _on_api_event(payload: Dictionary) -> void:
	if payload.has("rooms"):
		_status.text = "FastAPI 已连接  ·  可加入 %d 张牌桌  ·  盲注 5 / 10" % payload.rooms.size()

func _on_api_error(message: String) -> void:
	_status.text = "FastAPI 未连接：" + message
