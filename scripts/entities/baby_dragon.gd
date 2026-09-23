class_name BabyDragon
extends Node2D
## 2D판 entities/BabyDragon.js. 내 아이. 부모에게서 물려받은 모습으로 따라다니다가 자라면 함께 싸운다.

const STAGE_SCALE := { "BABY": 0.36, "TEEN": 0.55, "ADULT": 0.8 }   # 부모 스프라이트 대비 크기

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var genes: Dictionary
var sheet: SpriteSheet
var animator: SpriteSheet.Animator
var pet_timer := 0.0
var follow_gap := randf() * 60
var element := "FIRE"      # 부모가 다른 숨결을 가르칠 수 있다
var play_time := 0.0       # 놀아 준 직후 신나서 도는 시간
var chat = null
var chat_fade := 0.0
var facing := "down"
var growth := 0.0          # 0~200
var stage := "BABY"        # BABY → TEEN → ADULT
var atk_timer := 0.0
var angle := 0.0
var home = null            # 성체가 되면 둥지 주변을 배회
var wander_timer := 0.0
var remove := false
var is_hidden := false
var max_hp := 0.0          # 회복 기술이 건드리지 않게 (아이에게는 체력이 없다)
var hp := 0.0
var down_timer := 0.0
var moving := false
var stage_alpha := 1.0:
	set(v):
		stage_alpha = v
		modulate.a = v
var _outline = null


## genes: { species, colors, look } — 부모에게서 물려받은 모습
static func make(px: float, py: float, g) -> BabyDragon:
	var b := BabyDragon.new()
	b.x = px; b.y = py
	var p = GameState.player
	b.genes = g if g else { species = p.species, colors = p.colors.duplicate(), look = p.look }
	b.sheet = DragonSprites.get_sheet(b.genes.species, b.genes.get("colors", {}), int(b.genes.get("look", 0)))
	b.animator = SpriteSheet.Animator.new(b.sheet)
	b.name = "Baby_%d" % b.get_instance_id()
	return b


## 쓰다듬기. 잠깐 쉬었다가 다시 할 수 있다
func pet() -> bool:
	if pet_timer > 0: return false
	pet_timer = 12.0
	Kids.add_affection(self, 6)
	Particles.burst(x, y - 30, "#ff7aa8", 0.9, 8)
	Hud.pop("아기를 쓰다듬었습니다. 기분이 좋아 보여요!", "💗")
	return true


func say(text: String) -> void:
	chat = text
	chat_fade = 2.5


func feed() -> void:
	Kids.add_affection(self, 20)
	Hud.pop("아기에게 고기를 먹였습니다!", "🍖")
	Particles.burst(x, y, "#2ecc71", 0.8, 10)
	grow(6)


## 성장치를 올리고, 문턱을 넘으면 다음 단계로 자란다
func grow(amount: float) -> void:
	growth += amount
	if growth >= 70 and stage == "BABY":
		stage = "TEEN"
		Kids.set_stage(self, "TEEN")
		Hud.pop("아기 용이 어린 용이 되었습니다! (전투 가능)", "🔥")
	elif growth >= 140 and stage == "TEEN":
		stage = "ADULT"
		Kids.set_stage(self, "ADULT")
		var nests: Array = GameState.entities.nests
		home = Vector2(nests[0].x, nests[0].y) if not nests.is_empty() else Vector2(x, y)
		Hud.pop("자식이 성체가 되었습니다! 이제 둥지 근처에서 지냅니다.", "🐉")


func light(): return { r = 110, color = "#ffe2b0", intensity = 0.5 }


func update(dt: float) -> void:
	var px := x
	var py := y
	if pet_timer > 0: pet_timer -= dt
	if chat_fade > 0: chat_fade -= dt
	if play_time > 0:            # 신나서 제자리를 빙글빙글
		play_time -= dt
		var a := GameState.game_time * 7
		x += cos(a) * 160 * dt
		y += sin(a) * 160 * dt
	var kid = Kids.find(self)
	if stage != "BABY": _fight(dt, kid)
	# 성체이거나 '둥지 지키기'를 시킨 아이는 둥지 주변에 머문다
	if stage == "ADULT" or (kid and kid.mode == "STAY"): _update_adult(dt)
	else: _update_young(dt)
	moving = Vector2(x - px, y - py).length() > 0.01
	if moving: facing = Dragon.facing_from_vector(x - px, y - py, facing)
	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	var s: float = sheet.scale * STAGE_SCALE[stage]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if s < 1 else CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _update_young(dt: float) -> void:
	var t = GameState.player
	angle = atan2(t.y - y, t.x - x)
	var keep := 70 + follow_gap   # 아이마다 조금씩 다른 거리에서 따라온다
	if Util.dist(self, t) > keep:
		Collision.slide_move(self, x + cos(angle) * 190 * dt, y + sin(angle) * 190 * dt, 12)


## 청소년·성체는 근처의 적에게 불을 쏜다. 애정이 높을수록 아프다
func _fight(dt: float, kid) -> void:
	atk_timer -= dt
	if atk_timer > 0: return
	var E: Dictionary = GameState.entities
	var foe = null
	for e in E.humans + E.enemies + E.bosses:
		if e.get("awake") != false and e.type != "DUMMY" and Util.dist(self, e) < 300:
			foe = e
			break
	if not foe: return
	var damage: float = (12.0 if stage == "ADULT" else 8.0) * (1 + (kid.affection if kid else 0.0) / 100)
	Projectile.add(Projectile.new(x, y - 20, atan2(foe.y - 20 - (y - 20), foe.x - x), { faction = "ALLY", element = element, damage = damage, scale = 0.7 }))
	animator.play("attack")
	if kid and randf() < 0.15: say(Data.get_module("npcTalk").KID_TALK[kid.personality].bark.pick_random())
	atk_timer = 1.2 if stage == "ADULT" else 1.6


## 성체가 된 순간 그 자리에 멈추지 않고, 둥지 주변을 느긋하게 배회
func _update_adult(dt: float) -> void:
	wander_timer -= dt
	if wander_timer <= 0:
		wander_timer = Util.rand_range(2, 5)
		angle = Util.rand_range(0, TAU)
	# 둥지는 내 굴 안에만 있다. 밖에서는 지금 선 자리를 제집으로 삼는다
	if home == null:
		var nests: Array = GameState.entities.nests
		home = Vector2(nests[0].x, nests[0].y) if not nests.is_empty() else Vector2(x, y)
	if Util.dist(self, home) > 200: angle = atan2(home.y - y, home.x - x)
	Collision.slide_move(self, x + cos(angle) * 40 * dt, y + sin(angle) * 40 * dt, 12)


func _draw() -> void:
	var s: float = STAGE_SCALE[stage]
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 34 * s, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if GameState.talkTarget == self:
		var pts := PackedVector2Array()
		for i in 49: pts.append(Vector2(cos(TAU * i / 48.0) * (40 * s + 10), sin(TAU * i / 48.0) * (16 * s + 4)))
		draw_polyline(pts, Color("#ffd84a"), 3, true)
	var hover := sin(GameState.game_time * 3 + x) * 4 * s if sheet.flying else 0.0
	var f := animator.frame(facing)
	if _outline == null: _outline = Dragon.outline_for(f, false)
	SpriteSheet.draw_frame(self, sheet, f, 0, hover, s,
		{ t = GameState.game_time + follow_gap, moving = animator.name == "move", attacking = animator.name == "attack" and not animator.done,
		  hurt = maxf(0, 1 - animator.t * 4) if animator.name == "hit" and not animator.done else 0.0,
		  shape = Data.get_module("elements").STAGES[0].shape }, _outline)   # 새끼는 늘 해츨링 비율 — 머리가 크고 몸이 작다
	if stage == "BABY": _draw_shell(s * 1.6, hover)


## 아기는 머리에 알껍데기를 쓰고 있다 (Dragon 의 장신구 그리기와 같은 방식)
func _draw_shell(sc: float, hover: float) -> void:
	if not sheet.head: return
	if sheet.procedural and (facing == "up" or facing == "down"): return
	var s := sheet.scale * sc
	var hd: Array = sheet.head[facing]
	var b = sheet.box if sheet.box else { x = 0, y = 0, w = sheet.fw, h = sheet.fh }
	var left := -sheet.fw * s * sheet.anchor.x
	var top := hover - sheet.fh * s * sheet.anchor.y
	Pixel.draw_icon(self, "SHELL", left + (b.x + b.w * hd[0]) * s, top + (b.y + b.h * hd[1]) * s, maxf(2, roundf(3 * sc)))


# ---------- 이름표와 말풍선 (Overlay 가 화면 픽셀로) ----------
func crisp_anchor() -> Vector2:
	return Vector2(roundf(x), roundf(y - Dragon.head_top(sheet, STAGE_SCALE[stage]) - 6))


func draw_crisp(ci: CanvasItem, _zoom: float) -> void:
	if Cutscene.on: return
	var kid = Kids.find(self)
	if kid:
		var bold := Fonts.bold()
		var w := ceilf(Fonts.text_width(bold, kid.name, 12)) + 14
		ci.draw_rect(Rect2(-w / 2, -14, w, 19), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.78))
		Fonts.draw_centered(ci, bold, kid.name, 0, 0, 12, Color("#ffe9a0"))
	if chat_fade > 0 and chat:
		var a := minf(1, chat_fade)
		var font := Fonts.regular()
		var w := ceilf(Fonts.text_width(font, chat, 12)) + 24
		Dragon._bubble(ci, -w / 2, -46, w, 26, -20, a)
		Fonts.draw_centered(ci, font, chat, 0, -28, 12, Color(32 / 255.0, 32 / 255.0, 42 / 255.0, a))
