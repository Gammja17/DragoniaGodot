class_name Dragon
extends Node2D
## 2D판 entities/Dragon.js. 플레이어와 NPC 공용.
##
## 지금까지 옮긴 것: 걷기·달리기·대시(간발·물어뜯기), 숨결 쏘기와 조준, 맞기·쓰러지기, 경험치·레벨,
## 마을 용의 어슬렁거림과 혼잣말, 그리기(이름표·말풍선·장신구·머리 위 체력바).
## 스킬·필살기·비행·상호작용·마을 용의 전투와 따라다니기는 그 시스템을 옮기는 단계에서 같은 자리에 붙인다.
##
## 좌표는 2D판처럼 x, y(발 위치)로 다룬다. 노드 위치가 곧 발 위치라 부모의 y 정렬이 앞뒤를 가른다.

const WALK_SPEED := 260.0
const SPRINT_MULT := 1.5
const DASH_TIME := 0.2
const DASH_COOLDOWN := 1.0
const DASH_MULT := 3.4
const AIM_RANGE := 560       # 자동 조준(키보드): 이 거리 안, 바라보는 쪽 ±AIM_CONE 안의 가장 가까운 적을 겨눈다
const AIM_CONE := 1.0
const AIM_MAGNET := 95       # 마우스 조준: 커서가 적에게 이만큼 가까우면 그 적에게 살짝 붙여 준다
# 허기 단계: 배가 고프면 느려지고 숨결이 굼떠진다. 예전처럼 공격을 막지는 않는다
const HUNGER_PECKISH := 35
const HUNGER_STARVING := 12
const MOUTH_OFFSET := 40     # 화염구가 생성되는 위치(발 기준점에서 바라보는 방향으로)
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
var xp := 0.0
var max_xp := 240.0          # 성장은 느긋하게: 초반 레벨이 1.5배쯤 더 든다
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
var gold := 0
var inventory := { meat = 0 }
# 성장/브레스 (플레이어용)
var elements := ["FIRE"]
var element := "FIRE"
var skills := []             # 배운 스킬 id
var slots := { Q = null, F = null, R = null }
var cooldowns := {}
var ult := 0.0               # 필살기 게이지 0~100 (숨결이 셋 모이면 찬다)
var fire_timer := 0.0        # 다음 브레스까지
var slow_timer := 0.0        # 빙판·얼음·그물에 느려진 시간
var gale := 0.0              # 성장 트리 '질풍': 대시 뒤 연사가 빨라지는 남은 시간
var fury := 0.0              # 포효 뒤 분노 시간
var guard := 0.0             # 강철 비늘 남은 시간
var feast := 0.0
var dash_edge := false       # 이번 대시에서 간발을 이미 냈나
var invisible := false
var status := {}             # 대련 상대가 되면 상태 이상도 받는다
var status_immune := false
var def := {}

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
	feast -= dt
	dash_cd -= dt; invuln -= dt; fury -= dt; guard -= dt; slow_timer -= dt; gale -= dt
	var hunger_slow: float = [1.0, 0.86, 0.7][hunger_level]
	var base_speed: float = WALK_SPEED * stage.speed * (1 + 0.04 * GameState.upgrades.get("spd", 0)) * (1 + Growth.stat("speed")) \
		* (1.08 if Relics.has("WIND_FEATHER") else 1.0) * (0.55 if slow_timer > 0 else 1.0) * hunger_slow
	# Shift 를 탁 누르면 대시(잠깐 무적), 계속 누르고 있으면 달리기
	if GameInput.pressed("sprint") and ax != Vector2.ZERO and dash_cd <= 0:
		dash_dir = ax.normalized()
		dash_time = DASH_TIME; dash_cd = DASH_COOLDOWN * (1 - minf(0.6, Growth.stat("dash"))); invuln = DASH_TIME + 0.12
		dash_edge = false
		if Relics.resonates("wing"): dash_cd *= 0.75
		if Growth.has_perk("GALE"): gale = 3.0   # 성장 트리 '질풍'
		Sfx.play("dash")
		Vfx.spawn_effect("PUFF", x, y - 6)
	if dash_time > 0:
		if dash_time > DASH_TIME - 0.16: Flow.try_perfect_dodge(self)   # 대시 첫머리에 스친 것만 간발로 친다
		dash_time -= dt
		move_by(dash_dir.x, dash_dir.y, base_speed * DASH_MULT, dt)
		Flow.try_bite(self)
		# 유물 '불씨 발자국'(대시 자리에 남는 불길)은 장판을 옮길 때
		Particles.burst(x, y - 30 * stage.scale, colors.get("body", "#ffffff"), 0.35)
	elif ax != Vector2.ZERO:
		move_by(ax.x, ax.y, base_speed * (SPRINT_MULT if GameInput.down("sprint") else 1.0) * (1.45 if flying else 1.0), dt)
		hunger -= 0.35 * dt * hunger_mult * (3 if flying else 1)   # 나는 건 배가 빨리 꺼진다
	else:
		hunger -= 0.08 * dt * hunger_mult * (3 if flying else 1)
	if Relics.has("LIFE_STONE"): hp = minf(max_hp, hp + 1.5 * dt)
	hunger = maxf(0, hunger)

	# 숨결 바꾸기 (1~6)
	var all_els: Array = Data.get_module("elements").ELEMENTS.keys()
	for i in all_els.size():
		if GameInput.pressed("num%d" % (i + 1)) and elements.has(all_els[i]): element = all_els[i]
	fire_timer -= dt
	# 마우스 왼쪽 버튼을 꾹 누르고 있으면 연사 (터치의 [불] 버튼은 터치 조작을 옮길 때)
	var firing := GameInput.down("attack") or GameInput.mouse_down
	if firing and fire_timer <= 0: attack()

	# 보는 방향은 프레임 끝에 딱 한 번, 아래 순서대로 정한다.
	#   1) 쏘는 중이면 겨눈 쪽   — 숨결이 엉뚱한 쪽에서 나가지 않게
	#   2) 걷는 중이면 가는 쪽   — 방향키로도 자연스럽게 몸을 튼다
	#   3) 가만히 서 있으면 커서 쪽
	var look = null
	if firing: look = aim_angle().angle
	elif ax != Vector2.ZERO: look = atan2(ax.y, ax.x)
	elif GameInput.mouse_inside: look = aim_angle().angle
	if look != null: facing = facing_from_vector(cos(look), sin(look), facing)


## 0 배부름 · 1 출출함(조금 느려짐) · 2 굶주림(많이 느려짐)
var hunger_level: int:
	get: return 2 if hunger < HUNGER_STARVING else 1 if hunger < HUNGER_PECKISH else 0

## 허기가 주는 속도. 유물 '무쇠 위장'과 성장 트리 '무쇠 위장'이 함께 줄여 준다
var hunger_mult: float:
	get: return (0.5 if Relics.has("IRON_STOMACH") else 1.0) * (1 - minf(0.6, Growth.stat("hunger")))

var damage_mult: float:
	get:
		var scorn := 1.45 if Growth.has_perk("SCORN") and hp <= max_hp * 0.35 else 1.0   # 성장 트리 '역린'
		var m: float = stage.damage * (1 + 0.08 * GameState.upgrades.get("dmg", 0)) * (1 + Growth.stat("dmg")) * scorn \
			* (1.15 if Relics.has("OLD_FANG") else 1.0) * (1.3 if fury > 0 else 1.0)
		if is_player: m *= Flow.damage_mult() * (1.4 if Relics.has("GLASS_FANG") else 1.0) * (1.25 if feast > 0 else 1.0)
		return m


# ---------- 경험치 · 맞기 ----------
func gain_xp(amount: float) -> void:
	if is_player and GameState.blessingDay == GameState.day: amount *= 1.25   # 엘더의 축복
	xp += amount
	if xp < max_xp: return
	var levels := 0
	while xp >= max_xp:   # 퀘스트 보상처럼 한 번에 여러 레벨이 오를 수 있다
		level += 1
		levels += 1
		xp -= max_xp
		max_xp = floorf(max_xp * 1.38)
		max_hp += 12
	hp = max_hp
	if not is_player: return
	Growth.grant_points(levels * Growth.POINTS_PER_LEVEL, "레벨 %d 달성" % level)
	Hud.pop("LEVEL UP! LV.%d" % level, "🔥")
	Sfx.play("level")
	Particles.burst(x, y, "#f1c40f", 1.2, 25)
	Vfx.spawn_effect("STAR", x, y - 50, { size = 1.6 })
	# 승급 시험 안내(스승 카이론)는 이야기를 옮길 때


func take_damage(dmg: float, _silent := false, _from = null) -> void:
	# 대련 중 기력 깎기는 대련을 옮길 때
	if not is_player and down_timer > 0: return
	if is_player and invuln > 0: return
	if is_player:
		if guard > 0: dmg *= 0.3   # 강철 비늘
		dmg *= 1 - minf(0.6, Growth.stat("armor"))   # 성장 트리 '단단한 등'
		if Relics.has("GRON_PLATE"): dmg *= 0.85
		dmg *= 1 - minf(0.2, 0.04 * GameState.upgrades.get("def", 0))   # 대장간 '비늘돌 박기'
		if Relics.has("GLASS_FANG"): dmg *= 1.3
		if Relics.resonates("scale"): dmg *= 0.92
		if dmg >= 3:
			Flow.on_player_hurt()   # 기세가 꺾인다
			# 유물 '가시 껍질'(되돌려 주기)은 유물을 옮길 때
	var was_safe := is_player and hp > max_hp * 0.2
	hp -= dmg
	# 위기를 몇 번 넘겼는지는 '허물 벗기'를 스스로 깨우치는 조건이 된다
	if was_safe and hp > 0 and hp <= max_hp * 0.2: GameState.stats.brinks = GameState.stats.get("brinks", 0) + 1
	Particles.burst(x, y - 40, "#e74c3c", 0.8, 5)
	if is_player and dmg >= 3:
		Sfx.play("hurt")
		GameCamera.current.shake(minf(14, 4 + dmg * 0.45))
		Feedback.hit_stop(0.07)                              # 맞은 순간 세상이 잠깐 멈춘다
		Feedback.flash(minf(0.85, 0.3 + dmg / 40))           # 화면이 붉게 번쩍
		hurt_flash = 0.35
		Vfx.spawn_effect("SPARK", x, y - 44 * stage.scale, { size = 1.2, color = "#ff6b5e" })
		Vfx.spawn_text(x, y - 90 * stage.scale, "-%d" % roundi(dmg), "#ff6b5e", 18)
	animator.play("hit")
	if hp <= 0 and not is_player:           # 마을 용은 죽지 않고 잠시 쓰러진다
		hp = 0
		down_timer = 25
		var talk = Data.get_module("npcTalk").NPC_TALK.get(config.get("name"))
		say(talk.down if talk and talk.get("down") else "으윽…")
		if config.get("fixed"): Hud.pop("%s(이)가 쓰러졌습니다! 잠시 후 일어납니다." % Names.npc(config.name), "💫")
	if hp <= 0 and is_player:
		# 유물 '마지막 불씨'는 장판을 옮길 때. 성장 트리 '불사의 심장': 하루 한 번은 쓰러지지 않고 버틴다
		if Growth.has_perk("UNDYING") and GameState.revivedDay != GameState.day:
			GameState.revivedDay = GameState.day
			hp = 1; invuln = 3
			Vfx.spawn_effect("AURA", x, y - 40, { size = 2.4, color = "#ffd84a" })
			Hud.pop("불사의 심장이 뛴다! 체력 1로 버텼습니다 (하루 한 번)", "💛")
			Sfx.play("evolve")
			return
		Hud.pop("쓰러졌습니다... 마을에서 눈을 뜹니다.", "💀")
		hp = max_hp
		hunger = maxf(hunger, 40)
		World.revive_in_village()


# ---------- 숨결 ----------
## 브레스·스킬이 날아갈 방향.
##  마우스를 쓰는 중이면 커서 쪽이 기준이고, 커서가 적 위에 얹히면 그 적에게 살짝 붙는다.
##  키보드만 쓸 때는 바라보는 쪽 원뿔 안의 가장 가까운 적을 자동으로 겨눈다. (터치 조준은 터치 조작을 옮길 때)
func aim_angle() -> Dictionary:
	var E: Dictionary = GameState.entities
	var foes: Array = E.enemies + E.humans + E.bosses
	var sc: float = stage.scale
	var ox := x
	var oy := y - 40 * sc
	if GameInput.mouse_inside:
		var c: Vector2 = GameCamera.current.screen_to_world(GameInput.mouse_pos)
		var near = null
		var near_d := float(AIM_MAGNET)
		for e in foes:
			if e.get("awake") == false: continue
			var d := Vector2(e.x - c.x, e.y - 20 - c.y).length()
			if d < near_d:
				near = e; near_d = d
		if near: return { angle = atan2(near.y - 20 - oy, near.x - ox), target = near }
		return { angle = atan2(c.y - oy, c.x - ox), target = null }
	var best = null
	var best_d := float(AIM_RANGE)
	for e in foes:
		if e.get("awake") == false: continue
		var d := Util.dist(self, e)
		if d >= best_d: continue
		var da := atan2(e.y - y, e.x - x) - angle
		da = atan2(sin(da), cos(da))
		if absf(da) < AIM_CONE or d < 120:
			best = e; best_d = d
	if best: return { angle = atan2(best.y - 20 - oy, best.x - ox), target = best }
	return { angle = angle, target = null }


func attack() -> void:
	var el: Dictionary = Data.get_module("elements").ELEMENTS[element]
	var st := stage_index
	var slug: float = [1.0, 1.25, 1.5][hunger_level]   # 배가 고프면 숨결이 굼떠진다
	fire_timer = (el.rateByStage[st] if el.get("rateByStage") else el.rate) * (0.75 if fury > 0 else 1.0) * slug * (0.65 if gale > 0 else 1.0) * Flow.rate_mult()
	animator.play("attack")
	var a: float = aim_angle().angle
	var pellets: int = el.pelletsByStage[st] if el.get("pelletsByStage") else el.pellets
	for i in pellets: breathe(a + (i - (pellets - 1) / 2.0) * el.spread)
	var sc: float = stage.scale
	Vfx.spawn_effect("MUZZLE", x + cos(a) * 50 * sc, y - 40 * sc + sin(a) * 50 * sc, { angle = a + PI / 2, size = 0.7 + sc * 0.4, color = el.color })
	GameCamera.current.kick(a, 3.5 if el.pellets > 1 else 2.0)   # 쏘는 반대쪽으로 화면이 살짝 밀린다
	Sfx.play(el.sound)


## 현재 속성의 브레스 한 발
func breathe(a: float, mult := 1.0) -> void:
	var sc: float = stage.scale
	var mx := x + cos(a) * MOUTH_OFFSET * sc
	var my := y - 40 * sc + sin(a) * MOUTH_OFFSET * sc
	var breath_bonus := 1 + Growth.stat("breath") if is_player else 1.0   # 성장 트리 '타오르는 목'
	var el: Dictionary = Data.get_module("elements").ELEMENTS[element]
	# 날씨가 숨결을 거드는 배율은 날씨를 옮길 때 곱한다
	var damage: float = el.damage * damage_mult * breath_bonus * mult
	Projectile.add(Projectile.new(mx, my, a, { faction = "ALLY", element = element, damage = damage, scale = 0.7 + sc * 0.3,
		pierce = el.get("pierce", false) and stage_index >= el.get("pierceFromStage", 0), fromPlayer = true }))


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
	else: _draw_player_bar()


## 내 용 머리 위의 체력바. 구석의 막대만으로는 싸우는 중에 눈이 가지 않아 언제 맞았는지도 모른 채 쓰러진다.
## 다쳤을 때만 머리 위에 띄운다. 줌과 무관하게 화면 픽셀 크기로
func _draw_player_bar() -> void:
	var r := hp / max_hp
	if r >= 1: return
	var k := 1.0 / GameCamera.current.zoom.x
	var W := 74.0
	var H := 8.0
	draw_set_transform(Vector2(roundf(x) - x, roundf(y - head_top(sheet) - 2 + hover_y) - y), 0, Vector2(k, k))
	draw_rect(Rect2(-W / 2 - 2, -H - 2, W + 4, H + 4), Color(8 / 255.0, 7 / 255.0, 14 / 255.0, 0.82))
	draw_rect(Rect2(-W / 2, -H, W * r, H), Color("#7ddc5a") if r > 0.5 else Color("#ffc93c") if r > 0.25 else Color("#ff5a4d"))
	# 위험하면 테두리가 맥박친다
	if r <= 0.3:
		draw_rect(Rect2(-W / 2 - 2, -H - 2, W + 4, H + 4), Color(1, 90 / 255.0, 77 / 255.0, 0.5 + sin(GameState.game_time * 8) * 0.4), false, 2)
	draw_set_transform(Vector2.ZERO)


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
