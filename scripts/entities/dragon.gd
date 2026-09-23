class_name Dragon
extends Node2D
## 2D판 entities/Dragon.js. 플레이어와 NPC 공용.
##
## 1단계에서는 걷기·달리기·대시와 그리기만 옮겼다. 브레스·스킬·허기 단계·상호작용·NPC 행동은
## 그 시스템을 옮기는 단계에서 같은 자리에 붙인다.
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

var sheet: SpriteSheet
var animator: SpriteSheet.Animator
var anim_phase := randf() * 5
var _outline = null


## config: { name, species, colors:{body,belly,wing}, look?, ... }
func setup(px: float, py: float, cfg: Dictionary, player := false) -> Dragon:
	x = px; y = py
	config = cfg
	is_player = player
	species = cfg.get("species", "WESTERN")
	colors = cfg.get("colors", {}).duplicate()
	look = int(cfg.get("look", 0))
	sheet = DragonSprites.get_sheet(species, colors, look)
	animator = SpriteSheet.Animator.new(sheet)
	# 줄여 그리는 시트는 보간을 켜 둬야 획이 듬성듬성 빠지지 않고, 키워 그리는 픽셀아트는 꺼야 뭉개지지 않는다
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if sheet.scale * _draw_scale() < 1 else CanvasItem.TEXTURE_FILTER_NEAREST
	return self


var stage: Dictionary:
	get: return Data.get_module("elements").STAGES[stage_index]


func _draw_scale() -> float:
	return stage.scale if is_player else 0.92 * config.get("scale", 1.0)


func update(dt: float) -> void:
	hover_y = sin(GameState.game_time * 2 + anim_phase) * 6 if sheet.flying else 0.0
	# 날아오르는 중이면 몸이 천천히 떠오르고, 내려앉으면 내려온다 (그리기는 전부 hover_y 를 쓴다)
	if is_player:
		var want: float = -(38 + sin(GameState.game_time * 2.4) * 7) * stage.scale if flying else 0.0
		fly_lift += (want - fly_lift) * minf(1, dt * 5)
		hover_y += fly_lift

	moving = false
	if hurt_flash > 0: hurt_flash -= dt
	if is_player: _update_player(dt)

	var b := Terrain.current_map_bounds()
	x = clampf(x, 40, b.x - 40)
	y = clampf(y, 40, b.y - 40)

	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	queue_redraw()


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
	var sc := _draw_scale()
	# 내 용은 발밑에 은은한 빛을 깔아, 용이 여럿 뒤엉켜 있어도 어느 쪽이 나인지 바로 보이게 한다
	if is_player: Pixel.draw_glow(self, 0, -6, 86 * stage.scale, Color("#ffe6a8"), 0.17)
	# 마을 용은 발밑에 은은한 테를 늘 둔다 — 나무·풀 사이에서 사람이 어디 있는지 보이게
	if not is_player and config.get("fixed"):
		_ellipse_outline(40 * sc, 15 * sc, Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.45), 2)
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
