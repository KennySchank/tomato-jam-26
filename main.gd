extends Node2D

const PLAYER_SPEED := 120.0
const MAP_SIZE := Vector2(1152, 648)

var destination := Vector2(250, 470)
var click_marker := Vector2.ZERO
var marker_visible := false

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	player.position = destination
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		destination = event.position.clamp(Vector2(36, 104), MAP_SIZE - Vector2(36, 36))
		click_marker = destination
		marker_visible = true
		queue_redraw()

func _physics_process(_delta: float) -> void:
	var offset := destination - player.position
	if offset.length() > 4.0:
		player.velocity = offset.normalized() * PLAYER_SPEED
		player.move_and_slide()
	else:
		player.velocity = Vector2.ZERO

func _draw() -> void:
	# Background and header.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#101827"))
	draw_rect(Rect2(0, 0, MAP_SIZE.x, 78), Color("#182438"))
	draw_line(Vector2(0, 78), Vector2(MAP_SIZE.x, 78), Color("#30435b"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(34, 37), "FRONTIER WATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e9f1ff"))
	draw_string(ThemeDB.fallback_font, Vector2(34, 62), "Click anywhere to move", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#91a5c0"))

	# Playfield.
	draw_rect(Rect2(24, 96, 1104, 528), Color("#172b2a"), true)
	draw_rect(Rect2(24, 96, 1104, 528), Color("#375452"), false, 2.0)
	for x in range(56, 1128, 32):
		draw_line(Vector2(x, 96), Vector2(x, 624), Color(0.2, 0.35, 0.34, 0.18), 1.0)
	for y in range(128, 624, 32):
		draw_line(Vector2(24, y), Vector2(1128, y), Color(0.2, 0.35, 0.34, 0.18), 1.0)

	# A broad winding route with a bright center guide.
	var route := PackedVector2Array([Vector2(70, 160), Vector2(310, 160), Vector2(310, 300), Vector2(570, 300), Vector2(570, 500), Vector2(865, 500), Vector2(865, 230), Vector2(1060, 230)])
	draw_polyline(route, Color("#927750"), 58.0, true)
	draw_polyline(route, Color("#c5a36a"), 3.0, true)
	# Tower build pads.
	for pad in [Vector2(170, 270), Vector2(445, 165), Vector2(450, 430), Vector2(735, 350), Vector2(990, 420)]:
		draw_rect(Rect2(pad - Vector2(24, 24), Vector2(48, 48)), Color("#253e43"), true)
		draw_rect(Rect2(pad - Vector2(24, 24), Vector2(48, 48)), Color("#75a391"), false, 2.0)
		draw_line(pad - Vector2(9, 0), pad + Vector2(9, 0), Color("#75a391"), 2.0)
		draw_line(pad - Vector2(0, 9), pad + Vector2(0, 9), Color("#75a391"), 2.0)

	if marker_visible:
		draw_circle(click_marker, 12.0, Color(0.98, 0.82, 0.38, 0.18))
		draw_arc(click_marker, 12.0, 0.0, TAU, 32, Color("#f2c66d"), 2.0)
		draw_line(click_marker - Vector2(18, 0), click_marker + Vector2(18, 0), Color("#f2c66d"), 1.0)
		draw_line(click_marker - Vector2(0, 18), click_marker + Vector2(0, 18), Color("#f2c66d"), 1.0)
