class_name TreeNode
extends VBoxContainer
## 나무의 마디 하나: 마름모 보석 + 이름 (2D판 .tnode).
##   on    딴 마디 — 갈래 색 테두리와 은은한 빛
##   full  끝까지 딴 마디 — 보석이 갈래 색으로 찬다
##   can   지금 포인트를 쓸 수 있다 — 금빛 고리가 숨 쉰다
##   sel   고른 마디 — 밝은 테두리

signal picked

const INK := Color("#0e0d16")
const IDLE := Color("#3a4152")

var color := Color.WHITE
var on := false
var full := false
var can := false
var locked := false
var sel := false
var _hover := false


func _ready() -> void:
	$Gem.draw.connect(_draw_gem)
	$Gem.mouse_entered.connect(func(): _hover = true; $Gem.queue_redraw())
	$Gem.mouse_exited.connect(func(): _hover = false; $Gem.queue_redraw())
	$Gem.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: picked.emit())


func setup(d: Dictionary) -> void:
	color = d.color
	on = d.get("on", false)
	full = d.get("full", false)
	can = d.get("can", false)
	locked = d.get("locked", false)
	sel = d.get("sel", false)
	$Gem/Rank.text = d.rank
	$Gem/Rank.add_theme_color_override("font_color", Color("#11131f") if full else Color("#ece3cf") if on else Color("#a39a87"))
	$Gem/Slot.visible = d.get("slot", "") != ""
	$Gem/Slot.text = d.get("slot", "")
	$Name.text = d.name
	$Name.add_theme_color_override("font_color", Color("#ece3cf") if on or sel else Color("#ffd84a") if can else Color("#a39a87") if locked else Color("#cdc4af"))
	$Gem.queue_redraw()


## 아래쪽 가운데 · 위쪽 가운데 (줄기를 이을 자리, 전역 좌표)
func bottom_point() -> Vector2: return global_position + Vector2(size.x / 2, size.y)   # 이름 아래 (선이 이름 글자를 가로지르지 않게)
func top_point() -> Vector2: return $Gem.global_position + Vector2($Gem.size.x / 2, 0)


func _process(_dt: float) -> void:
	if can: $Gem.queue_redraw()   # 숨 쉬는 금빛 고리


func _draw_gem() -> void:
	var g: Control = $Gem
	var R := g.size.x / 2          # 보석의 반지름 (2D판 46px 네모를 45도 돌린 것)
	var c := Vector2(R, R)
	var dia := func(r: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	# 쓸 수 있는 마디의 금빛 고리 (2D판 gem-pulse 1.5초)
	if can:
		var t := (sin(Time.get_ticks_msec() / 1000.0 * PI / 1.5) + 1) / 2
		g.draw_colored_polygon(dia.call(R + 2 + t * 3), Color(1, 216 / 255.0, 74 / 255.0, 0.35 + t * 0.4))
	# 딴 마디와 고른 마디는 빛이 번진다
	if on or sel:
		g.draw_colored_polygon(dia.call(R + 5), Color(color, 0.18))
	var border := Color("#ece3cf") if sel else Color("#d8b25a") if _hover else color if on else Color("#8d7a44") if can and locked else IDLE
	g.draw_colored_polygon(dia.call(R), border)
	var fill := color if full else Color("#1d2033") if on else INK
	g.draw_colored_polygon(dia.call(R - 4), fill)
	g.draw_polyline(dia.call(R - 6) + PackedVector2Array([c + Vector2(0, -(R - 6))]), Color(0, 0, 0, 0.5), 2)
