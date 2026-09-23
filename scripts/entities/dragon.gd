class_name Dragon
extends Node2D
## 2D판 entities/Dragon.js. 플레이어와 NPC 공용.
##
## 지금까지 옮긴 것: 걷기·달리기·대시, 마을 용의 어슬렁거림과 혼잣말, 그리기(이름표·말풍선·장신구).
## 브레스·스킬·허기 단계·상호작용·마을 용의 전투와 따라다니기는 그 시스템을 옮기는 단계에서 같은 자리에 붙인다.
##
## 좌표는 2D판처럼 x, y(발 위치)로 다룬다. 노드 위치가 곧 발 위치라 부모의 y 정렬이 앞뒤를 가른다.

const WALK_SPEED := 260.0
const SPRINT_MULT := 1.5
const DASH_TIME := 0.2
const DASH_COOLDOWN := 1.0
const DASH_MULT := 3.4
# 지금 보고 있는 축(가로/세로)을 조금 우대한다. 정확히 대각선으로 움직일 때
# |dx| 와 |dy| 가 엎치락뒤치락하면서 매 프레임 방향이 갈리던 것을 막는다
const FACE_BIAS := 1.2

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var is_player := false
var config: Dictionary
var species: String
var colors: Dictionary
var look := 0

var level := 1
var hp := 80.0
var max_hp := 80.0
var hunger := 100.0
var angle := 0.0          # 마지막 이동/조준 방향 (라디안)
var facing := "down"      # 스프라이트 방향
var moving := false
var hover_y := 0.0
var fly_lift := 0.0
var flying := false
var stage_index := 0
var dash_time := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var invuln := 0.0         # 대시 중 무적 시간
var dive_height := 0.0
var down_timer := 0.0
var hurt_flash := 0.0

# NPC 전용
var home_x := 0.0
var home_y := 0.0
var state := "WANDER"     # WANDER | PARTNER_FOLLOW
var wander_timer := 0.0
var wander_angle := 0.0
var resting := false
var going_home := false
var chat_timer := Util.rand_range(20, 60)
var current_chat = null
var chat_fade := 0.0
var relation := 0.0       # 0~100
var doing = null          # 일과에서 지금 하는 일 (systems/routine)
var job = null
var walk_to = null        # 일과대로 걸어가는 중이면 { x, y }
var home_map = null
var remove := false
var is_hidden := false

var sheet: SpriteSheet
var animator: SpriteSheet.Animator
var anim_phase := randf() * 5
var _outline = null


## config: { name, species, colors:{body,belly,wing}, look?, ... }
func setup(px: float, py: float, cfg: Dictionary, player := false) -> Dragon:
	x = px; y = py
	home_x = px; home_y = py
	config = cfg
	is_player = player
	species = cfg.get("species", "WESTERN")
	colors = cfg.get("colors", {}).duplicate()
	look = int(cfg.get("look", 0))
	if not player and cfg.get("maxHp"):
		hp = cfg.maxHp; max_hp = cfg.maxHp
	sheet = DragonSprites.get_sheet(species, colors, look)
	animator = SpriteSheet.Animator.new(sheet)
	name = "Dragon_" + str(cfg.get("name", ""))
	return self


var stage: Dictionary:
	get: return Data.get_module("elements").STAGES[stage_index]


func _draw_scale() -> float:
	return stage.scale if is_player else 0.92 * config.get("scale", 1.0)


func update(dt: float) -> void:
	if chat_fade > 0: chat_fade -= dt * 0.3
	hover_y = sin(GameState.game_time * 2 + anim_phase) * 6 if sheet.flying else 0.0
	# 날아오르는 중이면 몸이 천천히 떠오르고, 내려앉으면 내려온다 (그리기는 전부 hover_y 를 쓴다)
	if is_player:
		var want: float = -(38 + sin(GameState.game_time * 2.4) * 7) * stage.scale if flying else 0.0
		fly_lift += (want - fly_lift) * minf(1, dt * 5)
		hover_y += fly_lift

	moving = false
	if hurt_flash > 0: hurt_flash -= dt
	if is_player: _update_player(dt)
	else: _update_npc(dt)

	var b := Terrain.current_map_bounds()
	x = clampf(x, 40, b.x - 40)
	y = clampf(y, 40, b.y - 40)

	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	# 줄여 그리는 시트는 보간을 켜 둬야 획이 듬성듬성 빠지지 않고, 키워 그리는 픽셀아트는 꺼야 뭉개지지 않는다
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if sheet.scale * _draw_scale() < 1 else CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func say(text: String) -> void:
	current_chat = text
	chat_fade = 3.0


## 방향 벡터로 이동하고 facing/angle 갱신. 물·나무·집은 통과하지 못하고 미끄러진다
func move_by(dx: float, dy: float, speed: float, dt: float) -> void:
	var len := Vector2(dx, dy).length()
	if not len: return
	dx /= len; dy /= len
	if flying:
		x += dx * speed * dt; y += dy * speed * dt   # 하늘에는 벽이 없다
	else:
		Collision.slide_move(self, x + dx * speed * dt, y + dy * speed * dt, 20)
	angle = atan2(dy, dx)
	facing = facing_from_vector(dx, dy, facing)
	moving = true


## 이동 벡터 → 4방향. fallback 은 지금 보고 있는 방향
static func facing_from_vector(dx: float, dy: float, fallback := "down") -> String:
	if not dx and not dy: return fallback
	var ax := absf(dx)
	var ay := absf(dy)
	var was_horiz := fallback == "left" or fallback == "right"
	var horiz := ax * FACE_BIAS >= ay if was_horiz else ax >= ay * FACE_BIAS
	if horiz: return "right" if dx > 0 else "left"
	return "down" if dy > 0 else "up"


func _update_player(dt: float) -> void:
	if GameState.prologue:
		moving = false   # 떨어지던 밤엔 아직 내 몸이 아니다
		return
	var ax := GameInput.axis()
	dash_cd -= dt; invuln -= dt
	# 성장 트리·유물·허기 단계의 배율은 그 시스템을 옮길 때 여기에 곱한다
	var base_speed: float = WALK_SPEED * stage.speed * (1 + 0.04 * GameState.upgrades.get("spd", 0))
	# Shift 를 탁 누르면 대시(잠깐 무적), 계속 누르고 있으면 달리기
	if GameInput.pressed("sprint") and ax != Vector2.ZERO and dash_cd <= 0:
		dash_dir = ax.normalized()
		dash_time = DASH_TIME; dash_cd = DASH_COOLDOWN; invuln = DASH_TIME + 0.12
	if dash_time > 0:
		dash_time -= dt
		move_by(dash_dir.x, dash_dir.y, base_speed * DASH_MULT, dt)
	elif ax != Vector2.ZERO:
		move_by(ax.x, ax.y, base_speed * (SPRINT_MULT if GameInput.down("sprint") else 1.0) * (1.45 if flying else 1.0), dt)
		hunger -= 0.35 * dt * (3 if flying else 1)   # 나는 건 배가 빨리 꺼진다
	else:
		hunger -= 0.08 * dt * (3 if flying else 1)
	hunger = maxf(0, hunger)


# ---------- NPC ----------
func _update_npc(dt: float) -> void:
	chat_timer -= dt
	if chat_timer <= 0:
		# 마을에 아홉 용이 서 있으면 2~3초마다 누군가 떠들었다. 내 곁에 있는 용만, 한 번에 둘까지, 뜸하게
		var talking := 0
		for o in GameState.entities.npcs:
			if o.chat_fade > 0 and o.current_chat: talking += 1
		if Util.dist(self, GameState.player) < 640 and talking < 2 and not GameState.isDialogueOpen: say(idle_line())
		chat_timer = Util.rand_range(45, 100)

	if down_timer > 0:               # 쓰러져 쉬는 중
		down_timer -= dt
		if down_timer <= 0:
			hp = max_hp; say("다시 싸울 수 있어!")
		return
	if hp < max_hp: hp = minf(max_hp, hp + 4 * dt)

	if walk_to:   # 일과대로 걸어가는 중 (systems/routine 이 옮긴다)
		facing = facing_from_vector(walk_to.x - x, walk_to.y - y, facing)
		return
	# 마을 용의 전투와 짝·동료의 따라다니기는 전투·관계를 옮길 때 붙인다
	if state == "WANDER": _update_wander(dt)


## 혼잣말 한 줄. 때(밤·비)와 성격을 섞어 고른다
func idle_line() -> String:
	var night := GameState.dayTime < 0.22 or GameState.dayTime > 0.82
	var wet: bool = GameState.weather.type == "RAIN" or GameState.weather.type == "SNOW"
	var d: Dictionary = Data.get_module("dialogues")
	var r := randf()
	if wet and r < 0.5: return d.RAIN_LINES.pick_random()
	if night and r < 0.55: return d.NIGHT_LINES.pick_random()
	var lines = d.IDLE_LINES.get(config.get("personality"))
	return lines.pick_random() if lines else "…"


func _update_wander(dt: float) -> void:
	wander_timer -= dt
	if wander_timer <= 0:
		wander_timer = Util.rand_range(3, 8)
		wander_angle = Util.rand_range(0, TAU)
		resting = randf() < 0.35   # 가끔 멈춰 서 있기
	# 습격 중엔 마을 용들이 광장으로 모여 함께 막는다 (스승은 수련장을 지킨다)
	if GameState.raid.active and config.get("fixed") and config.get("role") != "MASTER" \
			and Util.dist(self, Vector2(home_x, home_y)) > 320:
		move_by(home_x - x, home_y - y, 210, dt)
		return
	if resting: return
	# 집에서 너무 멀어지면 돌아온다. 한 번 돌아서면 넉넉히 가까워질 때까지 계속 간다
	# (경계 위에서 매 프레임 방향이 뒤집혀 스프라이트가 좌우로 떨리던 것)
	var away := Util.dist(self, Vector2(home_x, home_y))
	if away > 500: going_home = true
	elif away < 380: going_home = false
	var a := atan2(home_y - y, home_x - x) if going_home else wander_angle
	move_by(cos(a), sin(a), 60, dt)


## 발 기준점에서 그림 꼭대기까지의 높이(px). 이름표와 체력바를 머리 바로 위에 붙이는 데 쓴다.
## box(칸 안에서 그림이 실제로 차지하는 자리)가 있으면 그 값을 쓴다 — 체구가 작은 용은 칸 위쪽이 통째로 비어 있다
static func head_top(s: SpriteSheet, scl := 1.0) -> float:
	if s == null: return 90
	return (s.fh * s.anchor.y - (s.box.y if s.box else 0.0)) * s.scale * scl


## 어떤 색의 '진한 형제' 색. 색조는 그대로 두고 채도를 올리고 밝기를 낮춘다 (테두리용)
static func _deepen(rgb: Array, l: float, s: float, alpha: float) -> Color:
	var hsl := Util.rgb_to_hsl(rgb[0], rgb[1], rgb[2])
	var c := Util.hsl_to_rgb(hsl[0], maxf(s, hsl[1] * 0.8), l)
	return Color8(roundi(c[0]), roundi(c[1]), roundi(c[2]), roundi(alpha * 255))


## 그 용이 실제로 띠는 색에서 뽑은 테두리. 색조는 그 용의 것을 따르되 밝기는 충분히 낮춘다 —
## 초록 용이 초록 풀밭 위에서 테두리까지 풀색이면 윤곽이 사라진다
static func outline_for(f: Dictionary, player: bool) -> Dictionary:
	var rgb := SpriteSheet.average_color(f.img, int(f.sx), int(f.sy), int(f.sw), int(f.sh))
	if player: return { color = _deepen(rgb, 0.14, 0.7, 0.95), width = 2.2 }
	return { color = _deepen(rgb, 0.10, 0.45, 0.92), width = 2.0 }


## 2D판 draw(). 노드 원점이 발 위치라 월드 좌표에서 (x, y) 를 뺀 자리에 그린다
func _draw() -> void:
	if is_hidden: return   # 프롤로그에서 떨어지는 동안: 용이 아니라 빛으로만 보인다
	var sc := _draw_scale()
	# 고룡의 기운: 발밑의 넓은 빛과, 둘레를 도는 불티 셋 (마을의 고룡들도 같다)
	if stage_index >= 3 or config.get("elder"):
		var ssc: float = stage.scale
		var t := GameState.game_time
		Pixel.draw_glow(self, 0, -30 * ssc, 120 * ssc, Color("#ffe6a8") if is_player else Color("#d8b25a"), 0.12 + sin(t * 2.2) * 0.04)
		_sparks(ssc, t)
	# 내 용은 발밑에 은은한 빛을 깔아, 용이 여럿 뒤엉켜 있어도 어느 쪽이 나인지 바로 보이게 한다
	if is_player: Pixel.draw_glow(self, 0, -6, 86 * stage.scale, Color("#ffe6a8"), 0.17)
	# 마을 용은 발밑에 은은한 테를 늘 둔다 — 나무·풀 사이에서 사람이 어디 있는지 보이게
	if not is_player and config.get("fixed") and GameState.talkTarget != self:
		_ellipse_outline(40 * sc, 15 * sc, Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.45), 2)
	if GameState.talkTarget == self:
		_ellipse_outline(46 * sc, 18 * sc, Color(1, 216 / 255.0, 74 / 255.0, 0.6 + sin(GameState.game_time * 6) * 0.3), 3)
	var r := (26.0 if not sheet.flying else 34.0) * sc * (0.7 if flying else 1.0)
	_draw_shadow(r, 0.4 * (0.45 if flying else 1.0))

	var f := animator.frame(facing)
	if _outline == null: _outline = outline_for(f, is_player)
	var body_y := 18.0 if down_timer > 0 else hover_y
	var motion := {
		t = GameState.game_time + anim_phase, moving = moving,
		attacking = animator.name == "attack" and not animator.done,
		hurt = maxf(0, 1 - animator.t * 4) if animator.name == "hit" and not animator.done else 0.0,
		shape = stage.get("shape") if is_player else null,   # 자라면서 몸 비율이 바뀌는 건 내 용뿐이다 (마을 용은 다 성체)
	}
	SpriteSheet.draw_frame(self, sheet, f, 0, body_y - dive_height, sc, motion, _outline)
	_draw_accessory(sc, hover_y - dive_height)
	if not is_player: _draw_hp_bar(hp / max_hp, -12, 60)


func _draw_shadow(r: float, alpha: float) -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, alpha))
	draw_set_transform(Vector2.ZERO)


func _ellipse_outline(rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, width, true)


## 둘레를 도는 불티 셋. 2D판은 이 셋만 'lighter'(더하기)로 그리는데, 한 노드 안에서는 섞기를 바꿀 수 없어
## 밝은 색 그대로 얹는다 (밤 조명을 옮길 때 더하기 층으로 뺀다)
func _sparks(ssc: float, t: float) -> void:
	for i in 3:
		var a := t * 1.4 + i * 2.094
		var r := 62 * ssc
		var px := cos(a) * r
		var py := -40 * ssc + sin(a) * r * 0.45 - sin(t * 3 + i) * 8
		draw_circle(Vector2(px, py), 7, Color(1, 200 / 255.0, 90 / 255.0, 0.25))
		draw_circle(Vector2(px, py), 2.6, Color(1, 230 / 255.0, 160 / 255.0, 0.85))


## 머리 위 장신구. accessory: data/icons.json 의 아이콘 이름
func _draw_accessory(sc: float, body_y: float) -> void:
	var acc = config.get("accessory")
	if not acc or not sheet.head: return
	if sheet.procedural and (facing == "up" or facing == "down"): return   # 좌우 그림만 있는 외형은 어느 쪽을 보는지 여기선 알 수 없다
	var s := sheet.scale * sc
	var hd: Array = sheet.head[facing]
	var b = sheet.box if sheet.box else { x = 0, y = 0, w = sheet.fw, h = sheet.fh }   # head 비율은 칸이 아니라 용 몸을 기준으로 읽는다
	var left := -sheet.fw * s * sheet.anchor.x
	var top := body_y - sheet.fh * s * sheet.anchor.y
	Pixel.draw_icon(self, acc, left + (b.x + b.w * hd[0]) * s, top + (b.y + b.h * hd[1]) * s, maxf(2, roundf(3 * sc)))


## 머리 위 작은 체력바. 다친 용만 보여준다. up: 발에서 위로 몇 px
func _draw_hp_bar(ratio: float, up: float, width := 34.0) -> void:
	if ratio >= 1 or ratio <= 0: return
	var bx := roundf(x - width / 2) - x
	var by := roundf(y - up) - y
	draw_rect(Rect2(bx - 1, by - 1, width + 2, 6), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(bx, by, width * ratio, 4), Color("#7ddc5a") if ratio > 0.5 else Color("#ffc93c") if ratio > 0.25 else Color("#ff5a4d"))


# ---------- 이름표 · 말풍선 (Overlay 가 화면 픽셀로 그린다) ----------
func crisp_anchor() -> Vector2:
	return Vector2(roundf(x), roundf(y - head_top(sheet) - 14 + hover_y))


## 월드 좌표계가 아니라 화면 픽셀 단위로 그린다. 그래야 멀리 당겨 봐도 글씨가 같은 크기로 또렷하게 남는다
func draw_crisp(ci: CanvasItem, _zoom: float) -> void:
	if is_player or is_hidden: return
	var nm := Names.npc(config.get("name", ""))
	var bold := Fonts.bold()
	var nw := ceilf(Fonts.text_width(bold, nm, 12)) + 16
	ci.draw_rect(Rect2(-nw / 2, -16, nw, 21), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.78))
	ci.draw_rect(Rect2(-nw / 2, 4, nw, 1), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.55))
	Fonts.draw_centered(ci, bold, nm, 0, 0, 12, Color("#ece3cf"))
	# 퀘스트 표시(! ?)는 퀘스트를 옮길 때 붙인다. 그때 말풍선이 그만큼 위로 올라간다
	var mark := ""
	# 말풍선. 길면 줄을 나눈다
	if chat_fade > 0 and current_chat:
		var alpha := minf(1, chat_fade)
		var font := Fonts.regular()
		var lines := _wrap_text(font, current_chat, 230)
		var lh := 19
		var pad_x := 12
		var pad_y := 9
		var w := 0.0
		for l in lines: w = maxf(w, Fonts.text_width(font, l, 12))
		w += pad_x * 2
		var h := lines.size() * lh + pad_y * 2 - 4
		var bottom := -28 - (30 if mark else 0)
		var top := bottom - h
		_bubble(ci, -w / 2, top, w, h, bottom, alpha)
		for i in lines.size():
			Fonts.draw_centered(ci, font, lines[i], 0, top + pad_y + lh * i + 11, 12, Color(32 / 255.0, 32 / 255.0, 42 / 255.0, alpha))


## 흰 바탕 기본 말풍선. 몸통(x,y,w,h)과 아래를 가리키는 꼬리
static func _bubble(ci: CanvasItem, bx: float, by: float, w: float, h: float, tail_y: float, alpha: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, alpha)
	box.set_corner_radius_all(9)
	box.shadow_color = Color(0, 0, 0, 0.45 * alpha)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	box.draw(ci.get_canvas_item(), Rect2(bx, by, w, h))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, tail_y - 1), Vector2(7, tail_y - 1), Vector2(0, tail_y + 8)]), Color(1, 1, 1, alpha))


## 글상자 너비에 맞춰 줄을 나눈다 (한국어라 글자 단위로 끊는다). 세 줄까지
static func _wrap_text(font: Font, text: String, max_width: float) -> Array:
	if Fonts.text_width(font, text, 12) <= max_width: return [text]
	var lines := []
	var line := ""
	for ch in text:
		if Fonts.text_width(font, line + ch, 12) > max_width and line != "":
			lines.append(line)
			line = ""
		line += ch
	if line != "": lines.append(line)
	return lines.slice(0, 3)
