class_name Minimap
extends Control
## 2D판 HUD 의 미니맵. 지금 밟고 있는 지도 한 장만 보여 준다.
## 구운 바닥 그림을 칸에 맞춰 줄이고, 포탈·석비·굴·보스·상자·마을 용을 점으로 찍는다.

const BG := Color("#0b0d16")


func _process(_dt: float) -> void:
	if is_visible_in_tree(): queue_redraw()


## 미니맵 안에서 월드 좌표가 놓일 자리 { k, ox, oy }
func _place(m: GameMap) -> Dictionary:
	var s := size.x
	var tex := m.texture
	if tex == null: return { k = s / m.w, ox = 0.0, oy = 0.0 }
	var k := minf(s / tex.get_width(), s / tex.get_height()) / GameMap.TILE_SCALE
	return { k = k, ox = (s - tex.get_width() * k * GameMap.TILE_SCALE) / 2, oy = (s - tex.get_height() * k * GameMap.TILE_SCALE) / 2 }


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var m := Terrain.active
	if m == null or GameState.player == null:
		_frame()
		return
	var pl := _place(m)
	var k: float = pl.k
	var ox: float = pl.ox
	var oy: float = pl.oy
	if m.texture:
		var sc: float = k * GameMap.TILE_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect(m.texture, Rect2(ox, oy, m.texture.get_width() * sc, m.texture.get_height() * sc), false)
	var at := func(x: float, y: float) -> Vector2: return Vector2(ox + x * k, oy + y * k)
	var dot := func(x: float, y: float, r: float, c: Color) -> void: draw_circle(at.call(x, y), r, c)
	# 점마다 검은 테를 둘러 바탕과 떨어져 보이게 한다 (초록 바탕 위의 초록 점은 안 보였다)
	var ring := func(x: float, y: float, r: float, c: Color) -> void:
		draw_circle(at.call(x, y), r + 1.2, Color(0, 0, 0, 0.85))
		draw_circle(at.call(x, y), r, c)
	var diamond := func(x: float, y: float, r: float, c: Color) -> void:
		var p: Vector2 = at.call(x, y)
		var R := r + 1.2
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -R), p + Vector2(R, 0), p + Vector2(0, R), p + Vector2(-R, 0)]), Color(0, 0, 0, 0.85))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), c)
	var E: Dictionary = GameState.entities
	for pr in E.props:
		if pr.portal: diamond.call(pr.x, pr.y, 4, Color("#9fe3ff"))
		elif pr.type == "WAYSTONE": ring.call(pr.x, pr.y, 3, Color("#7fd4ff") if Travel.is_awake(pr.stone_id) else Color(127 / 255.0, 212 / 255.0, 1, 0.45))
		elif pr.type == "CAVE": ring.call(pr.x, pr.y, 3.5, Color("#c58aff"))
		elif pr.type == "DEN_MOUTH": ring.call(pr.x, pr.y, 3.5, Color("#ffd84a") if pr.den_id == "DEN_MINE" else Color("#d8a86a"))
		elif pr.type == "TOWER": ring.call(pr.x, pr.y, 3.5, Color("#e8d7a8"))
		elif pr.type == "STAIRS_DOWN": ring.call(pr.x, pr.y, 3, Color("#ff8a4a"))
		elif pr.type == "STAIRS_UP": ring.call(pr.x, pr.y, 3, Color("#ffe9b0"))
		elif pr.type == "CHEST" and not pr.opened: ring.call(pr.x, pr.y, 2.5, Color("#ffd84a"))
	for n in E.nests: ring.call(n.x, n.y, 3, Color("#ffd84a"))
	for e in E.enemies:
		if e.type != "PREY": dot.call(e.x, e.y, 2.5 if e.elite else 1.5, Color("#ffd84a") if e.elite else Color(1, 110 / 255.0, 110 / 255.0, 0.7))
	for h in E.humans: ring.call(h.x, h.y, 2, Color("#ff9a9a"))
	for b in E.bosses: ring.call(b.x, b.y, 4.5, Color("#ff4d4d"))
	# 마을 용은 초록 점. 부탁이 있거나 찾아가야 할 용은 점 대신 ! ? 글자
	var font := Fonts.bold()
	for npc in E.npcs:
		if not npc.config.get("fixed") or npc.remove or npc.is_hidden: continue
		var mark := Quests.marker(npc)
		if mark != "":
			var p: Vector2 = at.call(npc.x, npc.y)
			var w := Fonts.text_width(font, mark, 12)
			draw_string_outline(font, p + Vector2(-w / 2, 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.9))
			draw_string(font, p + Vector2(-w / 2, 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7dd36a") if mark == "?" else Color("#ffd84a"))
		else: ring.call(npc.x, npc.y, 2.5, Color("#7dd36a"))
	if GameState.partner: ring.call(GameState.partner.x, GameState.partner.y, 2.5, Color("#ff7aa8"))
	if GameState.companion: ring.call(GameState.companion.x, GameState.companion.y, 2.5, Color("#7dd3ff"))
	# 길잡이 목표: 천천히 뛰는 금빛 테
	var t = Guide.target()
	if t:
		var beat := (sin(GameState.game_time * 5) + 1) / 2
		draw_arc(at.call(t.x, t.y), 6 + beat * 3, 0, TAU, 24, Color(1, 216 / 255.0, 74 / 255.0, 0.6 + beat * 0.4), 2)
	# 나: 흰 화살촉이 보는 쪽을 가리킨다
	var p = GameState.player
	var ang: float = { "right": 0.0, "left": PI, "down": PI / 2, "up": -PI / 2 }.get(p.facing, 0.0)
	draw_set_transform(at.call(p.x, p.y), ang)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(-6, -6.5), Vector2(-3, 0), Vector2(-6, 6.5)]), Color.BLACK)
	draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(-4, -4.5), Vector2(-2, 0), Vector2(-4, 4.5)]), Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	_frame()


## 금테 (2D판 border: 2px solid gold)
func _frame() -> void:
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("#d8b25a"), false, 2)
