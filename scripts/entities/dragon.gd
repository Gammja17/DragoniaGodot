class_name Dragon
extends Node2D
## 2D판 entities/Dragon.js. 플레이어와 NPC 공용.
##
## 걷기·달리기·대시, 비행, 숨결과 조준, 스킬, 필살기, 맞기·쓰러지기, 경험치·레벨·승급,
## 말 걸기·줍기·낚시·먹기, 마을 용의 어슬렁거림·혼잣말·전투·따라다니기·놀이, 그리기(이름표·말풍선·장신구·체력바).
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
const INTERACT_RANGE := 120   # 이만큼 가까운 용에게 [Space] 로 말을 건다
const TALK_RANGE := 260       # 마우스로 가리킨 용은 이만큼 떨어져 있어도 된다
const TOUCH_AIM_RANGE := 700.0   # 터치: 이 안이면 등 뒤에 있어도 겨눈다
const TOUCH_LOCK_TIME := 1.1     # 터치: 한 번 붙잡은 적은 이만큼 놓지 않는다 (겨냥이 프레임마다 튀지 않게)
const TOUCH_HOMING := 5.5        # 터치: 숨결이 1초에 꺾을 수 있는 각도(rad). 겨눈 적을 따라간다

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
var preset := 0   # species HERO 의 프리셋 번호. 칸 번호(look)는 성장 단계로 고른다 (2D판 Dragon.preset)

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
var cooldowns := {}          # 스킬 id → 남은 대기 시간
var cd_max := {}             # 스킬 id → 그때 걸린 전체 대기 시간 (HUD 의 대기 표시용)
var channels := []           # 진행 중인 스킬 (systems/skills)
var tail_twin := false
var unlock_timer := 0.0
var ult := 0.0               # 필살기 게이지 0~100 (숨결이 셋 모이면 찬다)
var beam = null              # 삼원 융합 브레스 { time, angle, tick }
var fire_timer := 0.0        # 다음 브레스까지
var slow_timer := 0.0        # 빙판·얼음·그물에 느려진 시간
var gale := 0.0              # 성장 트리 '질풍': 대시 뒤 연사가 빨라지는 남은 시간
var fury := 0.0              # 포효 뒤 분노 시간
var guard := 0.0             # 강철 비늘 남은 시간
var feast := 0.0
var dash_edge := false       # 이번 대시에서 간발을 이미 냈나
var dash_trail := 0.0        # 유물 '불씨 발자국': 다음 불길까지
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
var atk_timer := 0.0      # NPC 전투: 다음 사격까지
var passive := false      # 오늘은 구경만 하기로 한 스승 (수련)
var mending = null        # 살리기: 일으키러 가는 쓰러진 용
var mend_t := 0.0         # 살리기: 일으키는 데 남은 시간
var heal_cd := 0.0        # 살리기: 다음 돌봄까지
# 사이 (NpcActions · Romance). 세이브가 이름으로 되살린다
var dates := 0
var last_gift_day = null
var last_talk_day = null
var last_present_day = null
var last_play_day = null
var last_date_day = null
var last_egg_day = null
var last_ride_day = null
var last_meditate_day = null
# 플레이어
var carrying = null          # 'EGG'
var fishing = null           # { x, y, wait, bite } 낚시 중일 때
var aim_lock = null          # 터치 자동 조준이 붙잡은 적
var aim_lock_timer := 0.0
# 컷씬 무대로 걸어 들어오는 중이면 흐릿하다 (Cutscene)
var stage_alpha := 1.0:
	set(v):
		stage_alpha = v
		modulate.a = v
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
	preset = look
	if species == "HERO": look = preset * 3 + mini(2, stage_index)
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


## 밤에 주변을 밝히는 빛 (render/lighting.gd)
func light():
	return { r = 300, color = "#ffe2b0", dy = -40 } if is_player else { r = 170, color = "#ffe2b0", intensity = 0.55, dy = -40 }


func update(dt: float) -> void:
	if chat_fade > 0: chat_fade -= dt * 0.3
	if species == "HERO":   # 자라면 다음 단계 그림으로 (저장을 불러온 뒤에도 여기서 맞춰진다)
		var want := preset * 3 + mini(2, stage_index)
		if want != look:
			look = want
			sheet = DragonSprites.get_sheet(species, colors, look)
			animator = SpriteSheet.Animator.new(sheet)
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
	self_modulate.a = 0.55 if down_timer > 0 else 1.0   # 쓰러져 누운 몸은 흐릿하다
	queue_redraw()


func say(text: String) -> void:
	current_chat = text
	chat_fade = 3.0


## 세상이 멈춘 동안(대화·컷씬) 겉모습만 움직인다: 숨쉬기 · 걷는 발 · 날갯짓. 자리와 싸움은 그대로 둔다
func animate_only(dt: float) -> void:
	hover_y = sin(GameState.game_time * 2 + anim_phase) * 6 if sheet.flying else 0.0
	if is_player: hover_y += fly_lift
	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	self_modulate.a = 0.55 if down_timer > 0 else 1.0
	queue_redraw()


## 머리 위에 잠깐 뜨는 표시 (!, ?, …, ♥ …). 컷씬 연출이 부른다
var _emote := ""
var _emote_at := 0
func emote(icon: String) -> void:
	_emote = icon
	_emote_at = Time.get_ticks_msec()


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
	if GameState.prologue or Ending.playing:
		moving = false   # 떨어지던 밤엔 아직 내 몸이 아니다 · 결말이 흐르는 동안에도
		return
	var ax := GameInput.axis()
	# 추적창을 눌러 알아서 걸어가는 중이면 방향키 대신 길잡이가 방향을 준다. 방향키를 건드리면 멈춘다
	if ax != Vector2.ZERO: Guide.cancel_nav()
	elif GameState.nav: ax = Guide.nav_axis(self, dt)
	if fishing: _update_fishing(dt, ax != Vector2.ZERO)
	feast -= dt
	dash_cd -= dt; invuln -= dt; fury -= dt; guard -= dt; slow_timer -= dt; gale -= dt
	var hunger_slow: float = [1.0, 0.86, 0.7][hunger_level]
	var base_speed: float = WALK_SPEED * stage.speed * (1 + 0.04 * GameState.upgrades.get("spd", 0)) * (1 + Growth.stat("speed")) \
		* (1.08 if Relics.has("WIND_FEATHER") else 1.0) * (0.55 if slow_timer > 0 else 1.0) * hunger_slow
	var locked := channels.any(func(c): return c.get("lock"))   # 급강하 중엔 조작 불가
	# Shift 를 탁 누르면 대시(잠깐 무적), 계속 누르고 있으면 달리기
	if locked: pass   # 스킬이 몸을 움직이는 중
	elif GameInput.pressed("sprint") and ax != Vector2.ZERO and dash_cd <= 0:
		dash_dir = ax.normalized()
		dash_time = DASH_TIME; dash_cd = DASH_COOLDOWN * (1 - minf(0.6, Growth.stat("dash"))); invuln = DASH_TIME + 0.12
		dash_edge = false; dash_trail = 0.0
		if Relics.resonates("wing"): dash_cd *= 0.75
		if Growth.has_perk("GALE"): gale = 3.0   # 성장 트리 '질풍'
		Sfx.play("dash")
		Vfx.spawn_effect("PUFF", x, y - 6)
	if locked: pass
	elif dash_time > 0:
		if dash_time > DASH_TIME - 0.16: Flow.try_perfect_dodge(self)   # 대시 첫머리에 스친 것만 간발로 친다
		dash_time -= dt
		move_by(dash_dir.x, dash_dir.y, base_speed * DASH_MULT, dt)
		Flow.try_bite(self)
		# 유물 '불씨 발자국': 대시가 지나간 자리에 불길이 남는다
		dash_trail -= dt
		if Relics.has("EMBER_TRAIL") and dash_trail <= 0:
			dash_trail = 0.06
			Hazard.add(x, y, { faction = "ALLY", r = 60, delay = 0.05, linger = 2.2, damage = 4 * damage_mult, dps = 9 * damage_mult, color = "#ff7a2a", effect = "FLAMES", effectSize = 0.9, status = { type = "BURN", duration = 2 } })
		Particles.burst(x, y - 30 * stage.scale, colors.get("body", "#ffffff"), 0.35)
	elif ax != Vector2.ZERO:
		move_by(ax.x, ax.y, base_speed * (SPRINT_MULT if GameInput.down("sprint") else 1.0) * (1.45 if flying else 1.0), dt)
		hunger -= 0.22 * dt * hunger_mult * (3 if flying else 1)   # 나는 건 배가 빨리 꺼진다
		Tutorial.mark("moved")
	else:
		hunger -= 0.06 * dt * hunger_mult * (3 if flying else 1)
	if GameInput.pressed("fly"): toggle_flight()
	if flying and hunger <= 0 and can_land(): land("배가 꺼져서 내려앉았다.")
	if Relics.has("LIFE_STONE"): hp = minf(max_hp, hp + 1.5 * dt)
	if Relics.has("VOW_RING") and GameState.partner and GameState.partner.state != "WANDER" and Util.dist(self, GameState.partner) < 420: hp = minf(max_hp, hp + 2 * dt)
	hunger = maxf(0, hunger)

	if _update_talk(): return   # 대화를 열었으면 이번 프레임은 여기까지

	for k in cooldowns: cooldowns[k] = maxf(0, cooldowns[k] - dt * Flow.cooldown_rate())   # 기세가 절정이면 기술이 빨리 돌아온다
	Skills.update_channels(self, dt)
	# 숨결 바꾸기 (1~6)
	var all_els: Array = Data.get_module("elements").ELEMENTS.keys()
	for i in all_els.size():
		if GameInput.pressed("num%d" % (i + 1)) and elements.has(all_els[i]): element = all_els[i]
	fire_timer -= dt
	aim_lock_timer -= dt   # 터치 자동 조준이 붙잡은 적
	# 마우스 왼쪽 버튼(모바일은 [불] 단추, 게임패드는 RT 나 오른쪽 스틱을 끝까지)을 꾹 누르고 있으면 연사
	var firing := GameInput.down("attack") or GameInput.mouse_down or GameInput.aim_stick().length() > 0.6
	if firing and fire_timer <= 0: attack()
	for slot in Data.get_module("skills").SKILL_SLOTS:
		if GameInput.pressed("skill" + slot): Skills.use_slot(self, slot)
	if GameInput.pressed("ultimate"): use_ultimate()
	if GameInput.pressed("nextElement"): cycle_element()   # 터치의 [속성] 버튼 · 게임패드 십자키 →
	if GameInput.pressed("prevElement"): cycle_element(-1)
	if beam: _update_beam(dt)
	if GameInput.pressed("interact"): interact()
	if GameInput.pressed("eat"): eat()

	# 보는 방향은 프레임 끝에 딱 한 번, 아래 순서대로 정한다.
	#   1) 쏘는 중이면 겨눈 쪽   — 숨결이 엉뚱한 쪽에서 나가지 않게
	#   2) 걷는 중이면 가는 쪽   — 방향키로도 자연스럽게 몸을 튼다
	#   3) 가만히 서 있으면 커서 쪽
	if not locked:
		var look = null
		if firing: look = aim_angle().angle
		elif GameInput.pad and GameInput.aim_stick() != Vector2.ZERO: look = GameInput.aim_stick().angle()
		elif ax != Vector2.ZERO: look = atan2(ax.y, ax.x)
		elif GameInput.mouse_inside and not GameInput.pad: look = aim_angle().angle
		if look != null: facing = facing_from_vector(cos(look), sin(look), facing)

	# 스스로 깨우치는 스킬·각성은 1초에 한 번만 살펴본다
	unlock_timer -= dt
	if unlock_timer <= 0:
		unlock_timer = 1.0
		Skills.check_unlocks()


# ---------- 비행 ----------
## 성체부터 난다. 하늘에서는 벽도 물도 없고 땅의 적이 못 치지만, 배가 세 배로 꺼진다
func toggle_flight() -> void:
	if flying:
		if can_land(): land()
		else: Hud.pop("여기엔 내려앉을 수 없다.", "☁️")
		return
	if stage_index < 2:
		Hud.pop("아직 날개가 몸을 못 든다. 성체가 되면 난다.", "🪽")
		return
	if GameState.dungeon or GameState.indoors or World.dens().has(GameState.map_id):
		Hud.pop("천장이 있다. 밖에서 날자.", "🪽")
		return
	if fishing or GameState.activity: return
	flying = true
	invuln = maxf(invuln, 0.3)
	Vfx.spawn_effect("PUFF", x, y - 6, { size = 1.4 })
	Sfx.play("dash")
	Hud.pop("날아오른다. [Z]로 다시 내려앉는다.", "🪽")


## 발밑이 땅이고 비어 있어야 내려앉는다
func can_land() -> bool: return not Collision.solid_at(x, y, 20)


func land(msg := "") -> void:
	flying = false
	Vfx.spawn_effect("PUFF", x, y - 6, { size = 1.2 })
	Sfx.play("dash")
	if msg != "": Hud.pop(msg, "🪽")


## 땅을 겨누는 스킬(운석·급강하)이 떨어질 자리. 커서가 적 위면 그 적, 아니면 커서 자리(최대 사거리까지)
func aim_point(max_range: float) -> Vector2:
	var aim := aim_angle()
	if aim.target: return Vector2(aim.target.x, aim.target.y)
	if GameInput.mouse_inside:
		var c: Vector2 = GameCamera.current.screen_to_world(GameInput.mouse_pos)
		var d := Vector2(c.x - x, c.y - y).length()
		if d == 0: d = 1
		var k := minf(1, max_range / d)
		return Vector2(x + (c.x - x) * k, y + (c.y - y) * k)
	return Vector2(x + cos(aim.angle) * max_range, y + sin(aim.angle) * max_range)


func cycle_element(step := 1) -> void:
	var have: Array = Data.get_module("elements").ELEMENTS.keys().filter(func(el): return elements.has(el))
	if have.size() < 2: return
	element = have[(have.find(element) + step + have.size()) % have.size()]
	Hud.pop("속성: %s" % Data.get_module("elements").ELEMENTS[element].name, "🔥")


## 새 숨결을 품는다
func unlock_element(id: String) -> void:
	if elements.has(id): return
	elements.append(id)
	element = id
	var el: Dictionary = Data.get_module("elements").ELEMENTS[id]
	# 숫자 키는 GameInput.words 가 바꾸지 못한다. 패드·터치에서는 그 기기에서 속성을 바꾸는 단추로 적는다
	var how := "십자 ←→로" if GameInput.pad else "[속성] 단추로" if GameInput.touch and not GameInput.mouse_inside else "숫자 [%s] 키로" % el.key
	Hud.pop("새 속성 [%s] 획득! %s (%s 바꾼다)" % [el.name, el.desc, how], "✨")
	var gift = Data.get_module("skills").ELEMENT_SKILLS.get(id)
	if is_player and gift: Skills.learn(gift)   # 맡겨 받은 숨결은 기술도 같이 온다
	# 숨결이 셋이 되는 순간 필살기가 열린다
	if elements.size() == 3: Hud.pop("속성이 셋이 되었다. 적을 맞혀 필살기 게이지를 채우면 [X]로 융합 브레스를 쓸 수 있다.", "🌈")


## 필살기: 삼원 융합 브레스. 세 숨결을 하나로 뭉쳐 2.6초 동안 앞을 쓸어버린다
func use_ultimate() -> void:
	if elements.size() < 3: return
	if ult < 100:
		Hud.pop("필살기 게이지 %d%%. 적을 맞혀 채우세요." % floori(ult), "🌈")
		return
	ult = 0
	GameState.stats.fusions = GameState.stats.get("fusions", 0) + 1   # 융합 브레스를 쏜 수 (SKEAM 도전 과제)
	beam = { time = 2.6, angle = aim_angle().angle, tick = 0.0 }
	invuln = maxf(invuln, 0.6)
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 3.5, color = "#ffffff" })
	Vfx.spawn_effect("RUNE", x, y, { size = 2.6, color = "#ffffff" })
	Vfx.spawn_effect("BLOOM", x, y - 40, { size = 1.65, color = "#fff2b0" })
	Feedback.flash(0.3, Color.WHITE)
	Feedback.hit_stop(0.1); GameCamera.current.shake(14); Sfx.play("evolve")


func _update_beam(dt: float) -> void:
	var b: Dictionary = beam
	var E: Dictionary = GameState.entities
	b.time -= dt; b.tick -= dt
	# 빔은 바라보는 쪽으로 천천히 따라 돈다
	var da: float = aim_angle().angle - b.angle
	da = atan2(sin(da), cos(da))
	b.angle += clampf(da, -1.4 * dt, 1.4 * dt)
	if b.tick <= 0:
		b.tick = 0.1
		var sc: float = stage.scale
		var ox := x
		var oy := y - 40 * sc
		for e in E.enemies + E.humans + E.bosses:
			if e.get("awake") == false: continue
			var t := clampf((e.x - ox) * cos(b.angle) + (e.y - 20 - oy) * sin(b.angle), 0, 950)
			if Vector2(e.x - (ox + cos(b.angle) * t), e.y - 20 - (oy + sin(b.angle) * t)).length() > 75 + (50 if e.def.get("scale") else 0): continue
			e.take_damage(9 * damage_mult)
			Status.apply(e, "BURN", 3); Status.apply(e, "SLOW", 2)
			if randf() < 0.3: Vfx.spawn_effect(["FIRE_HIT", "ICE_HIT", "THUNDER_HIT"].pick_random(), e.x, e.y - 20, { size = 0.9 })
		GameCamera.current.shake(3); Sfx.play(["flame", "freeze", "zap"].pick_random())
	if b.time <= 0: beam = null


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
		max_xp = floorf(max_xp * (1.38 if level <= 8 else 1.25))
		max_hp += 12
	hp = max_hp
	if not is_player: return
	Growth.grant_points(levels * Growth.POINTS_PER_LEVEL)
	Hud.level_up(level, levels * Growth.POINTS_PER_LEVEL)   # 글자·빛기둥·소리는 대화·장면이 끝나 조용해진 뒤에 (Hud)
	check_evolution()


## 레벨 업 연출 (Hud 가 머리 위 글자를 띄우며 부른다):
## 발밑의 금빛 마법진, 몸을 감싸고 솟는 빛기둥, 퍼지는 고리, 떠오르는 반짝임
func level_up_fx() -> void:
	var sc: float = maxf(stage.scale, 0.9)   # 아기 용이라고 빛기둥까지 작으면 보이지 않는다
	Vfx.spawn_effect("MAGIC_CIRCLE", x, y, { size = 0.8 * sc, color = "#ffd84a" })
	Vfx.spawn_effect("PILLAR", x, y - 110 * sc, { size = sc, color = "#ffe9a0" })
	Vfx.spawn_effect("RING", x, y - 45 * sc, { size = 1.3 * sc, color = "#ffd84a" })
	for i in 6:
		Vfx.spawn_effect("SPARKLE", x + (randf() - 0.5) * 90 * sc, y - (10 + randf() * 90) * sc, { color = "#fff2b0" })
	Particles.burst(x, y - 40 * sc, "#f1c40f", 1.2, 28, 140)


## 레벨이 다음 단계에 닿으면 스승의 승급 시험을 받을 수 있다 (Story). 자동으로 자라지는 않는다
func check_evolution() -> void:
	if Story.pending_trial(): Hud.pop("몸이 근질거린다… 스승 카이론에게 [승급 시험]을 청할 수 있습니다!", "🐲")


## 승급 시험을 통과했을 때
func evolve(idx: int) -> void:
	stage_index = idx
	max_hp += 30
	hp = max_hp
	_outline = null
	Growth.grant_points(Growth.POINTS_PER_STAGE, "%s 단계로 승급" % stage.name)
	Hud.pop("승급! [%s] 단계에 올랐습니다" % stage.name + (". %s" % stage.unlock if stage.get("unlock") else ""), "🐲")
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 3, color = "#ffe9a0" })
	Vfx.spawn_effect("RING", x, y - 40, { size = 2.6 })
	Particles.burst(x, y - 30, func():
		var rgb := Util.hsl_to_rgb(40 + floori(randf() * 3) * 10, 1.0, 0.65)
		return Color8(roundi(rgb[0]), roundi(rgb[1]), roundi(rgb[2])), 1.4, 40)
	GameCamera.current.shake(10)
	Sfx.play("evolve")
	Quests.notify("stage", idx)


func take_damage(dmg: float, _silent := false, _from = null) -> void:
	var act = GameState.activity
	if act and (act.type == "SPAR" or act.type == "DUEL") and act.npc == self:   # 대련: 실제 체력 대신 기력이 깎인다
		act.hp -= dmg
		animator.play("hit")
		return
	if not is_player and down_timer > 0: return
	if is_player and invuln > 0: return
	if not is_player: dmg *= Party.taken(self)   # 막기 동료는 덜 다친다
	if is_player:
		if guard > 0: dmg *= 0.3   # 강철 비늘
		dmg *= 1 - minf(0.6, Growth.stat("armor"))   # 성장 트리 '단단한 등'
		if Relics.has("GRON_PLATE"): dmg *= 0.85
		dmg *= 1 - minf(0.2, 0.04 * GameState.upgrades.get("def", 0))   # 대장간 '비늘돌 박기'
		if Relics.has("GLASS_FANG"): dmg *= 1.3
		if Relics.resonates("scale"): dmg *= 0.92
		if dmg >= 3:
			Flow.on_player_hurt()   # 기세가 꺾인다
			if Relics.has("THORN_SHELL"):   # 맞은 만큼 둘레에 되돌려 주고 밀어낸다
				for e in GameState.entities.enemies + GameState.entities.humans:
					if e.remove or Util.dist(e, self) > 150: continue
					e.take_damage(dmg * 1.5 + 6, false, self)
				Vfx.spawn_effect("SHOCKWAVE", x, y - 20, { size = 1.2, color = "#9fe07a" })
	var was_safe := is_player and hp > max_hp * 0.2
	hp -= dmg
	# 위기를 몇 번 넘겼는지는 '허물 벗기'를 스스로 깨우치는 조건이 된다
	if was_safe and hp > 0 and hp <= max_hp * 0.2: GameState.stats.brinks = GameState.stats.get("brinks", 0) + 1
	var felt: bool = is_player or dmg >= 2   # 마을 용이 장판 · 몸통에 프레임마다 조금씩 깎일 때마다 피가 튀고 움찔하던 것
	if felt: Particles.burst(x, y - 40, "#e74c3c", 0.8, 5)
	if is_player and dmg >= 3:
		Sfx.play("hurt")
		GameCamera.current.shake(minf(14, 4 + dmg * 0.45))
		Feedback.hit_stop(0.07)                              # 맞은 순간 세상이 잠깐 멈춘다
		Feedback.flash(minf(0.85, 0.3 + dmg / 40))           # 화면이 붉게 번쩍
		hurt_flash = 0.35
		Vfx.spawn_effect("SPARK", x, y - 44 * stage.scale, { size = 1.2, color = "#ff6b5e" })
		Vfx.spawn_text(x, y - 90 * stage.scale, "-%d" % roundi(dmg), "#ff6b5e", 18)
	if felt: animator.play("hit")
	if hp <= 0 and not is_player:           # 마을 용은 죽지 않고 잠시 쓰러진다
		hp = 0
		down_timer = 25
		var talk = Data.get_module("npcTalk").NPC_TALK.get(config.get("name"))
		say(talk.down if talk and talk.get("down") else "으윽…")
		if config.get("fixed") and (self == GameState.companion or (self == GameState.partner and state == "PARTNER_FOLLOW")):
			Hud.pop("%s 쓰러졌습니다! 살리기 동료가 일으키지 않으면 오늘은 마을로 돌아갑니다." % Util.josa(Names.npc(config.name), "이", "가"), "💫")
		elif config.get("fixed"): Hud.pop("%s 쓰러졌습니다! 잠시 후 일어납니다." % Util.josa(Names.npc(config.name), "이", "가"), "💫")
	if hp <= 0 and is_player:
		# 유물 '마지막 불씨': 하루 한 번, 쓰러질 일격을 버티고 둘레를 불태운다
		if Relics.has("LAST_EMBER") and GameState.emberDay != GameState.day:
			GameState.emberDay = GameState.day
			hp = 1; invuln = 3
			Hazard.add(x, y, { faction = "ALLY", r = 220, delay = 0.1, linger = 0, damage = 60 * damage_mult, color = "#ff7a2a", effect = "FIRE_HIT", effectSize = 2.4, sound = "boom", shake = 10, status = { type = "BURN", duration = 4 } })
			Hud.pop("마지막 불씨가 타올랐다! 체력 1로 버텼습니다 (하루 한 번)", "🔥")
			return
		# 성장 트리 '불사의 심장': 하루 한 번은 쓰러지지 않고 버틴다
		if Growth.has_perk("UNDYING") and GameState.revivedDay != GameState.day:
			GameState.revivedDay = GameState.day
			hp = 1; invuln = 3
			Vfx.spawn_effect("AURA", x, y - 40, { size = 2.4, color = "#ffd84a" })
			Hud.pop("불사의 심장이 뛴다! 체력 1로 버텼습니다 (하루 한 번)", "💛")
			Sfx.play("evolve")
			return
		# 쓰러진 값: 가진 고기 절반. 따라오던 짝 · 동료는 나를 업어다 놓고 그날은 돌아간다
		GameState.stats.downs = GameState.stats.get("downs", 0) + 1   # 쓰러진 수 (SKEAM 도전 과제)
		var lost := floori(inventory.meat / 2.0)
		inventory.meat -= lost
		var gone := Party.on_player_down()
		if GameState.dungeon: Hud.pop("쓰러졌다가 겨우 일어났습니다." + (" 기운을 차리느라 고기 %d개를 먹었습니다." % lost if lost > 0 else ""), "💀")   # 굴에서는 그 자리에서 일어난다
		else: Hud.pop("쓰러졌습니다… 마을 용들이 업어 와 " + ("고기를 먹여 살렸습니다. (고기 -%d)" % lost if lost > 0 else "돌봐 주었습니다."), "💀")
		if not gone.is_empty(): Hud.pop("%s 오늘은 마을로 돌아갑니다." % Util.josa("·".join(gone), "은", "는"), "🏠")
		hp = max_hp
		hunger = maxf(hunger, 40)
		World.revive_in_village()


# ---------- 숨결 ----------
## 브레스·스킬이 날아갈 방향.
##  마우스를 쓰는 중이면 커서 쪽이 기준이고, 커서가 적 위에 얹히면 그 적에게 살짝 붙는다.
##  터치로 할 때는 둘레의 적 하나를 붙잡아 겨누고(_lock_target), 키보드만 쓸 때는 바라보는 쪽 원뿔 안의 가장 가까운 적.
func aim_angle() -> Dictionary:
	var E: Dictionary = GameState.entities
	var foes: Array = E.enemies + E.humans + E.bosses
	var act = GameState.activity
	if act and (act.type == "SPAR" or act.type == "DUEL"): foes.append(act.npc)
	var sc: float = stage.scale
	var ox := x
	var oy := y - 40 * sc
	# 게임패드: 오른쪽 스틱이 가리키는 쪽. 그쪽 ±0.3 안의 적에게 살짝 붙여 준다
	var stick := GameInput.aim_stick() if GameInput.pad else Vector2.ZERO
	if stick != Vector2.ZERO:
		var want := stick.angle()
		var near = null
		var near_d := float(AIM_RANGE) * 1.2
		for e in foes:
			if e.get("awake") == false: continue
			var d := Util.dist(self, e)
			var da := atan2(e.y - 20 - oy, e.x - ox) - want
			da = atan2(sin(da), cos(da))
			if d < near_d and absf(da) < 0.3:
				near = e; near_d = d
		if near: return { angle = atan2(near.y - 20 - oy, near.x - ox), target = near }
		return { angle = want, target = null }
	if GameInput.mouse_inside and not GameInput.pad:
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
	if GameInput.touch and is_player:
		var locked = _lock_target(foes)
		return { angle = atan2(locked.y - 20 - oy, locked.x - ox), target = locked } if locked else { angle = angle, target = null }
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


# ---------- 말 걸기 · 줍기 · 낚시 ----------

## 말 걸 상대와 눈앞의 것을 고르고, [Space]·[T] 를 처리한다. 대화를 열었으면 true
func _update_talk() -> bool:
	var E0: Dictionary = GameState.entities
	var near := func(list: Array, rng: float):
		var best = null
		var bd := rng
		for e in list:
			var d := Util.dist(self, e)
			if d < bd:
				bd = d
				best = e
		return best
	# 말 걸 상대: 마우스로 가리킨 용이 우선, 없으면 가장 가까운 용. 둥지는 그 다음
	var pointed = null
	if GameInput.mouse_inside or GameInput.mouse_clicked:
		var c: Vector2 = GameCamera.current.screen_to_world(GameInput.mouse_pos)
		var pd := 90.0
		for e in E0.npcs + E0.babies:
			var d := Vector2(e.x - c.x, e.y - 50 - c.y).length()
			if d < pd:
				pd = d
				pointed = e
	var target = pointed if pointed and Util.dist(self, pointed) < TALK_RANGE else null
	if not target: target = near.call(E0.npcs, INTERACT_RANGE)
	if not target: target = near.call(E0.babies, 130)
	# 대련·술래잡기·수련 중에는 누구에게도 말을 걸 수 없다 (한창 싸우다 대화창이 열리던 것)
	if GameState.activity: target = null
	# 눈앞의 것이 먼저다. 따라오는 용은 물건보다 뒤로 밀리고, 물건이 용보다 가까워도 물건이 먼저다. 마우스로 콕 집은 용만 예외
	var thing = null if GameState.activity else nearby_thing()
	var follower: bool = target != null and not E0.babies.has(target) and target.state != "WANDER"
	if thing and target and target != pointed and (follower or thing.d < Util.dist(self, target)): target = null
	var is_kid: bool = target != null and E0.babies.has(target)
	var nests: Array = E0.nests
	var nest_near = nests[0] if not target and not nests.is_empty() and Util.dist(self, nests[0]) < 110 else null
	GameState.talkTarget = target   # 그릴 때 발밑에 표시한다
	# 굴 입구·굴 안은 [E] 로
	var mouth = null
	if not target and not nest_near:
		for pr in E0.props:
			if pr.type == "DEN_MOUTH" and Util.dist(self, pr) < 120:
				mouth = pr
				break
	# 이동 석비. 광장처럼 용이 북적이는 곳에서도 쓸 수 있게, 상대보다 가까이 서 있으면 석비가 먼저다
	var stone = Travel.nearby_waystone() if not flying and not fishing and not carrying else null
	var stone_first: bool = stone != null and not nest_near and (not target or Util.dist(self, stone) < 95 or Util.dist(self, stone) < Util.dist(self, target))
	var tip := ""
	var tip_at = null
	if nest_near:
		tip_at = nest_near
		tip = "Space · E 둥지에서 잔다" if Den.in_my_den() else "Space 둥지에서 쉬기"
	elif stone_first:
		tip_at = stone
		tip = "Space 석비로 건너뛴다"
	elif target:
		tip_at = target
		tip = "Space 아이와 대화" if is_kid else "Space 대화"
	elif mouth:
		tip_at = mouth
		tip = "E 내 굴에 들어간다 (둥지)" if mouth.den_id == "DEN_MINE" else "E 굴에 들어간다"
	elif thing:
		tip_at = thing.at
		tip = "E · Space %s" % thing.label
	elif Den.in_my_den():
		tip_at = self
		tip = "E 굴 꾸미기"
	Hud.current.set_interact(tip_at, tip)

	# 말 걸기는 [Space]. T 도 그대로 쓸 수 있다. 왼쪽 버튼은 브레스라, 탭으로 말 걸기는 터치에서만 (mouse_inside 가 false)
	var tapped: bool = GameInput.mouse_clicked and not GameInput.mouse_inside
	var want_talk: bool = not flying and (GameInput.pressed("confirm") or GameInput.pressed("talk") or (tapped and pointed != null and pointed == target))
	if tapped and pointed and pointed != target: Hud.pop("너무 멀다. 가까이 가서 말을 걸자.", "💬")
	# [T] 는 물건이 앞에 있어도 곁의 용에게 말을 건다 (따라오는 짝에게 말을 걸 길)
	if GameInput.pressed("talk") and not target and not GameState.activity and not flying:
		var n = near.call(E0.npcs, INTERACT_RANGE)
		if n:
			Dialogue.start(n, "TALK")
			return true
	if want_talk and stone_first:
		Travel.open_menu(stone)
		return true
	if want_talk and target:
		if is_kid: KidActions.open_hub(target)
		else: Dialogue.start(target, "TALK")
		return true
	if want_talk and nest_near:
		Story.open_nest_menu()
		return true
	if GameInput.pressed("confirm") and not flying: interact()   # 말 걸 상대가 없으면 눈앞의 것을 집는다
	return false


func _near_water():
	for i in 12:
		var a := angle + (i / 12.0) * TAU
		var wx := x + cos(a) * 110
		var wy := y + sin(a) * 110
		if Terrain.ground_at(wx, wy) == "WATER" and Terrain.active_biome() != "VOLCANO": return Vector2(wx, wy)   # 용암에선 낚시 불가
	return null


func _update_fishing(dt: float, moved: bool) -> void:
	var f: Dictionary = fishing
	if moved:   # 움직이면 낚시를 접는다
		fishing = null
		return
	if f.bite > 0:
		f.bite -= dt
		if f.bite <= 0:
			fishing = null
			Hud.pop("물고기가 달아났습니다…", "💨")
	else:
		f.wait -= dt
		if f.wait <= 0:
			f.bite = 1.0
			Particles.burst(f.x, f.y, "#bfe9ff", 0.5, 6)
			Sfx.play("splash")


## 들고 있는 알을 곁의 둥지에 놓는다. 놓았거나 못 놓는 까닭을 알렸으면 true.
## 둥지가 곁에 없으면 false 를 돌려 [E] 가 원래 하던 일(굴 꾸미기 · 줍기 · 낚시)로 넘어가게 한다
func _put_egg_in_nest() -> bool:
	var nest = null
	for n in GameState.entities.nests:
		if Util.dist(self, n) < 110: nest = n
	if not nest: return false
	if not GameState.den.get("built"):
		Hud.pop("아직 알을 품을 둥지가 없습니다. 굴 안 잠자리 앞에서 [Space]로 먼저 지으세요. (나뭇가지 8개, 30G)", "🪹")
		return true
	if nest.has_egg:
		Hud.pop("둥지에 이미 알이 있습니다.", "🥚")
		return true
	if GameState.kids.size() >= Data.get_module("core_config").MAX_KIDS:
		Hud.pop("식구가 꽉 찼습니다. 더는 알을 품을 수 없습니다.", "😅")
		return true
	# 제 알을 품으려면 다 자라야 한다. 아직 어리면 엘더에게 맡기는 길이 있다
	var adult := 0
	var stages: Array = Data.get_module("elements").STAGES
	for i in stages.size():
		if stages[i].id == "ADULT": adult = i
	if stage_index < adult:
		Hud.pop("아직 알을 품을 몸이 아닙니다. 엘더에게 맡겨 보세요.", "🥚")
		return true
	carrying = null
	nest.lay_egg(self, GameState.partner)
	Hud.pop("알을 둥지에 놓았습니다. 곁에 있어 주면 더 빨리 깹니다.", "🏠")
	return true


## 눈앞에 있는 물건 (말 걸 상대 말고). interact() 와 같은 순서로 본다. { label, d, at } 없으면 null
func nearby_thing():
	var E: Dictionary = GameState.entities
	var hit := func(list: Array, rng: float, label: String):
		var best = null
		var bd := rng
		for it in list:
			var d := Util.dist(self, it)
			if d < bd:
				bd = d
				best = it
		return { label = label, d = bd, at = best } if best else null
	if fishing: return null
	var props: Array = E.props
	var r = null
	if carrying == "EGG" and not E.nests.is_empty(): r = hit.call(E.nests, 110, "알을 둥지에 놓는다")
	if not r: r = hit.call(props.filter(func(p): return p.type == "CAVE"), 120, "굴에 들어간다")
	if not r: r = hit.call(props.filter(func(p): return p.type == "STAIRS_DOWN" or p.type == "STAIRS_UP"), 100, "오르내린다")
	if not r and not carrying: r = hit.call(props.filter(func(p): return p.type == "BOARD"), 90, "게시판을 본다")
	if not r: r = hit.call(E.items.filter(func(it): return not it.remove and (it.type == "MEAT" or (it.type == "EGG" and not carrying))), 60, "줍는다")
	if not r and not GameState.den.get("built"): r = hit.call(props.filter(func(p): return p.type == "STUMP" and p.ripe), 80, "나뭇가지를 줍는다")
	if not r and hunger < 95: r = hit.call(props.filter(func(p): return p.type == "BERRY" and p.ripe), 80, "열매를 딴다")
	if not r: r = hit.call(props.filter(func(p): return p.type == "CHEST" and not p.opened), 80, "상자를 연다")
	return r


## [E] 눈앞의 것
func interact() -> void:
	var E: Dictionary = GameState.entities
	if GameState.activity: return   # 대련·술래잡기 중에는 상자도 석비도 나중이다
	# 알을 들고 둥지 앞에 섰으면 놓는 것이 먼저다 (굴 안에서는 아래 Den 이 [E] 를 늘 채 가기 때문에)
	if not fishing and carrying == "EGG" and _put_egg_in_nest(): return
	if not fishing and Arena.nearby():          # 수련장 시험 표지
		Arena.open()
		return
	if not fishing and Story.try_awaken(): return          # 구름 위 빈 둥지 — 고룡의 깨어남
	if not fishing and Den.try_interact(): return          # 보금자리 굴 — 들어가기 / 안에서는 꾸미기
	if not fishing and Delve.try_interact(): return        # 굴 입구·오르내리는 구멍
	if not fishing and not carrying:                       # 이동 석비
		var stone = Travel.nearby_waystone()
		if stone:
			Travel.open_menu(stone)
			return
	if not fishing and not carrying:                       # 마을 게시판 — 숫자를 채우는 일거리는 여기에만 붙는다
		for b in E.props:
			if b.type == "BOARD" and Util.dist(self, b) < 90:
				Chores.open_board()
				return
	# 낚시 중: 입질이 왔을 때 누르면 낚는다
	if fishing:
		if fishing.bite > 0:
			var n := 2 if randf() < 0.25 else 1
			inventory.meat += n
			GameState.stats.fish = GameState.stats.get("fish", 0) + 1   # 낚은 물고기 수 (SKEAM 도전 과제)
			Vfx.spawn_text(x, y - 100 * stage.scale, "고기 +%d (물고기)" % n, "#9fe3ff", 16)
			Particles.burst(fishing.x, fishing.y, "#bfe9ff", 0.7, 10)
			gain_xp(6)
		else:
			Hud.pop("너무 일찍 당겼습니다.", "🎣")
		fishing = null
		return
	# 1) 줍기
	var picked := false
	for item in E.items:
		if item.remove or Util.dist(self, item) >= 60: continue
		if item.type == "MEAT":
			inventory.meat += 1
			item.remove = true
			picked = true
			Sfx.play("pickup")
			Hud.pop("고기 획득!", "🍖")
		elif item.type == "EGG" and not carrying:
			carrying = "EGG"
			item.remove = true
			picked = true
			Hud.pop("알을 들었습니다. 내 굴 둥지에 놓거나 엘더에게 맡기세요.", "🥚")
	if picked: return
	# 2) 그루터기에서 나뭇가지 줍기 (둥지 재료)
	for s in E.props:
		if s.type == "STUMP" and s.ripe and Util.dist(self, s) < 80 and not GameState.den.get("built"):
			s.gather()
			return
	# 3) 열매 따기
	for b in E.props:
		if b.type == "BERRY" and b.ripe and Util.dist(self, b) < 80 and hunger < 95:
			b.harvest()
			return
	# 3-0) 보물상자 열기
	for c in E.props:
		if c.type == "CHEST" and not c.opened and Util.dist(self, c) < 80:
			c.open()
			return
	# 3-1) 아기 쓰다듬기 (고기를 먹이는 건 아이 대화창에서)
	for k in E.babies:
		if Util.dist(self, k) < 80 and not carrying and k.pet(): return
	# 5) 물가라면 낚시
	var water = _near_water() if not carrying else null
	if water:
		fishing = { x = water.x, y = water.y, wait = Util.rand_range(1.5, 4.5), bite = 0.0 }
		Hud.pop("낚싯줄을 드리웠습니다. 찌가 흔들릴 때 [Space]!", "🎣")


## [C] 고기를 먹는다. 상호작용과 섞어 두면 상자를 열려다 고기가 먹힌다
func eat() -> void:
	if inventory.meat <= 0:
		Hud.pop("가진 고기가 없습니다.", "🍖")
		return
	if hunger >= 95:
		Hud.pop("배가 불러서 더는 못 먹겠다.", "✋")
		return
	inventory.meat -= 1
	hunger = minf(100, hunger + 40)
	hp = minf(max_hp, hp + 30)
	Tutorial.mark("ate")
	Vfx.spawn_text(x, y - 90 * stage.scale, "+40", "#9fe08a", 15)
	if Relics.has("GREEDY_MAW"):
		feast = 12.0
		Vfx.spawn_text(x, y - 112 * stage.scale, "포식!", "#ffb347", 15)
	Hud.pop("고기를 먹었습니다.", "😋")
	Sfx.play("eat")


## 터치 자동 조준: 붙잡을 적 하나. 둘레를 다 보되 앞쪽을 조금 더 친다.
## 엄지가 이동과 겨냥을 다 맡아야 해서, 옆으로 피하며 쏘면 숨결이 늘 허공으로 나가던 것
func _lock_target(foes: Array):
	var alive := func(e) -> bool: return e != null and is_instance_valid(e) and not e.remove and e.get("awake") != false and e.hp > 0
	if alive.call(aim_lock) and aim_lock_timer > 0 and Util.dist(self, aim_lock) < TOUCH_AIM_RANGE: return aim_lock
	var best = null
	var best_score := INF
	for e in foes:
		if not alive.call(e): continue
		var d := Util.dist(self, e)
		if d > TOUCH_AIM_RANGE: continue
		var da := atan2(e.y - y, e.x - x) - angle
		da = atan2(sin(da), cos(da))
		var score := d * (1 + 0.45 * absf(da) / PI)   # 앞쪽이 조금 유리할 뿐, 뒤도 겨눈다
		if score < best_score:
			best = e
			best_score = score
	aim_lock = best
	aim_lock_timer = TOUCH_LOCK_TIME
	return best


func attack() -> void:
	var el: Dictionary = Data.get_module("elements").ELEMENTS[element]
	var st := stage_index
	var slug: float = [1.0, 1.1, 1.25][hunger_level]   # 배가 고프면 숨결이 굼떠진다
	fire_timer = (el.rateByStage[st] if el.get("rateByStage") else el.rate) * (0.75 if fury > 0 else 1.0) * slug * (0.65 if gale > 0 else 1.0) * Flow.rate_mult()
	animator.play("attack")
	var aim := aim_angle()
	var a: float = aim.angle
	var pellets: int = el.pelletsByStage[st] if el.get("pelletsByStage") else el.pellets
	# 모바일에서만 유도탄. 엄지로 겨눌 수 없으니 숨결이 붙잡은 적 쪽으로 휘어 간다 (마우스를 쓰는 중이면 겨냥은 손끝에)
	var seek = aim.target if GameInput.touch and is_player and not GameInput.mouse_inside else null
	for i in pellets: breathe(a + (i - (pellets - 1) / 2.0) * el.spread, 1.0, seek)
	var sc: float = stage.scale
	Vfx.spawn_effect("MUZZLE", x + cos(a) * 50 * sc, y - 40 * sc + sin(a) * 50 * sc, { angle = a + PI / 2, size = 0.7 + sc * 0.4, color = el.color })
	GameCamera.current.kick(a, 3.5 if el.pellets > 1 else 2.0)   # 쏘는 반대쪽으로 화면이 살짝 밀린다
	Sfx.play(el.sound)


## 현재 속성의 브레스 한 발
func breathe(a: float, mult := 1.0, seek = null) -> void:
	var sc: float = stage.scale
	var mx := x + cos(a) * MOUTH_OFFSET * sc
	var my := y - 40 * sc + sin(a) * MOUTH_OFFSET * sc
	var breath_bonus := 1 + Growth.stat("breath") if is_player else 1.0   # 성장 트리 '타오르는 목'
	var el: Dictionary = Data.get_module("elements").ELEMENTS[element]
	var damage: float = el.damage * damage_mult * breath_bonus * Weather.damage_mult(element) * mult
	Projectile.add(Projectile.new(mx, my, a, { faction = "ALLY", element = element, damage = damage, scale = 0.7 + sc * 0.3,
		pierce = el.get("pierce", false) and stage_index >= el.get("pierceFromStage", 0), fromPlayer = true,
		homing = TOUCH_HOMING if seek else 0.0, homingTarget = seek, by = self }))


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

	var act = GameState.activity
	if act and act.get("npc") == self:
		NpcActions.update_activity_npc(self, dt)
		return
	if act and act.get("rival") == self: return   # 허수아비 내기 중인 맞수 (Story 가 움직인다)

	if down_timer > 0:               # 쓰러져 쉬는 중
		down_timer -= dt
		if down_timer <= 0:
			if not Party.on_get_up(self):   # 따라오던 동료는 그날은 돌아간다
				hp = max_hp; say("(툭툭 털고 일어난다.)")
		return
	if hp < max_hp: hp = minf(max_hp, hp + 4 * dt)

	if walk_to:   # 일과대로 걸어가는 중 (systems/routine 이 옮긴다)
		facing = facing_from_vector(walk_to.x - x, walk_to.y - y, facing)
		return
	var following := state != "WANDER"
	var fights: bool = config.get("fixed") or following
	var dodging: bool = fights and _dodge(dt)   # 발밑의 예고부터 비킨다. 비키는 동안에도 쏘기는 한다
	if following and not dodging and Party.role_id(self) == "MEDIC" and _mend(dt): return   # 살리기: 쓰러진 용부터 일으킨다
	var busy: bool = fights and _fight(dt, following, not dodging)
	if dodging: pass
	elif following: _update_partner(dt, busy)
	elif not busy: _update_wander(dt)


## 마을 용·짝·동료의 전투. 싸우는 중이면 true
func _fight(dt: float, following: bool, can_move := true) -> bool:
	var E: Dictionary = GameState.entities
	if passive: return false   # 오늘은 구경만 하기로 한 스승 (수련)
	var foe = null
	var best := 460.0
	for e in E.humans + E.enemies + E.bosses:
		if not Combat.hittable(e): continue   # 허수아비는 제자의 몫이다. 땅속의 적 · 쓰러지는 보스 · 무릎 꿇은 보스도 쏘지 않는다
		var d := Util.dist(self, e)
		if d < best:
			best = d; foe = e
	if foe == null: return false
	var el: String = config.get("element", "FIRE") if config.get("element") else "FIRE"
	var reach := Party.reach(el) * 0.9   # 브레스가 닿는 거리 안에서만 쏜다 (불은 360 남짓인데 400에서 쏴서 허공에서 사라졌다)
	# 따라다니는 중이 아니면 적당한 거리를 유지하며 맞선다
	if not can_move: pass
	elif not following:
		var a := atan2(foe.y - y, foe.x - x)
		var mv := a if best > 280 else a + PI if best < 170 else a + PI / 2
		move_by(cos(mv), sin(mv), 130, dt)
	elif best > reach * (0.55 if Party.guarding(self) else 0.9):   # 막기는 적 앞으로 더 나선다
		# 동료: 브레스가 닿는 데까지 다가선다. 다만 내 곁(250px)을 벗어나지는 않는다
		var to := Vector2(foe.x - x, foe.y - y).normalized()
		if (Vector2(x, y) + to * 40).distance_to(Vector2(GameState.player.x, GameState.player.y)) < 250: move_by(to.x, to.y, 200, dt)
	facing = facing_from_vector(foe.x - x, foe.y - y, facing)
	atk_timer -= dt
	if atk_timer <= 0 and best < reach:
		var aim := atan2(foe.y - 20 - (y - 40), foe.x - x)
		# 따라나선 용은 내 피해를 따라 큰다 (Party). 마을에 남은 용은 제 힘(power) 그대로
		var dmg: float = (Party.shot_damage(self) if following else float(config.get("power", 8))) * (1.5 if GameState.rally > 0 else 1.0) \
			* (1.5 if Relics.has("TWIN_SOUL") and following else 1.0) \
			* (1.3 if Relics.has("VOW_RING") and self == GameState.partner else 1.0) \
			* (1.3 if Relics.has("CAPTAIN_HORN") and GameState.raid.active else 1.0)
		Projectile.add(Projectile.new(x, y - 40, aim, { faction = "ALLY", element = el, damage = dmg, by = self }))
		animator.play("attack")
		atk_timer = Party.interval() if following else 1.25
		var talk = Data.get_module("npcTalk").NPC_TALK.get(config.get("name"))
		if talk and talk.get("battle") and randf() < 0.18: say(talk.battle.pick_random())
	return true


## 발밑의 위험에서 비켜선다: 적의 장판 예고 · 남아서 타는 장판 · 번지는 고리 · 보스의 돌진 예고선과 광선 · 나를 노린 돌진 예고선.
## 비켜서는 중이면 true
func _dodge(dt: float) -> bool:
	var me := Vector2(x, y)
	var away := Vector2.ZERO
	for h in GameState.entities.hazards:
		if h.faction != "ENEMY" or (h.burst and not (h.linger > 0 and h.dps > 0)): continue   # 이미 터진 것은 남아서 타는 것만
		var c := Vector2(h.x, h.y)
		var d := me.distance_to(c)
		var out := (me - c).normalized() if d > 1 else Vector2.RIGHT
		if h.inner > 0:   # 번져 나가는 고리: 가까운 쪽 가장자리로 빠진다
			if d > h.inner - 20 and d < h.r + 20: away += out if h.r - d < d - h.inner else -out
		elif d < h.r + 24: away += out
	for b in GameState.entities.bosses:
		if b.charge and b.charge.windup > 0: away += _off_line(Vector2(b.x, b.y), b.charge.angle, 470, 60 * b.def.scale)
		if b.beam:
			for a in [b.beam.angle, b.beam.angle + PI]: away += _off_line(b._mouth(), a, 700, 70)
	for e in GameState.entities.enemies:
		if e.def.move == "charge" and e.ai.s == "tell" and EnemyAI.target_of(e) == self: away += _off_line(Vector2(e.x, e.y), e.ai.dir, 340, 50)
	if away == Vector2.ZERO: return false
	move_by(away.x, away.y, 300, dt)
	return true


## from 에서 angle 쪽으로 뻗은 선(길이 length, 폭 width) 위에 서 있으면 선에서 벗어나는 쪽. 아니면 0
func _off_line(from: Vector2, angle: float, length: float, width: float) -> Vector2:
	var dir := Vector2.from_angle(angle)
	var rel := Vector2(x, y) - from
	var along := rel.dot(dir)
	var side := rel - dir * along
	if along < -width or along > length or side.length() > width: return Vector2.ZERO
	return side.normalized() if side.length() > 1 else dir.orthogonal()


## 살리기: 쓰러진 용(동료 · 마을 용)에게 달려가 일으키고, 다친 나를 곁에서 조금씩 돌본다. 일으키러 가는 중이면 true
func _mend(dt: float) -> bool:
	var r: Dictionary = Party._d().ROLES.MEDIC
	var p = GameState.player
	heal_cd -= dt
	if heal_cd <= 0 and p.hp < p.max_hp * float(r.healBelow) and Util.dist(self, p) < float(r.healRange):
		heal_cd = float(r.healEvery)
		var amount: float = p.max_hp * float(r.heal)
		p.hp = minf(p.max_hp, p.hp + amount)
		Vfx.spawn_text(p.x, p.y - 100 * p.stage.scale, "+%d" % roundi(amount), "#9fe08a", 14)
	if mending == null or not is_instance_valid(mending) or mending.down_timer <= 0 or not GameState.entities.npcs.has(mending):
		mending = null
		for n in GameState.entities.npcs:   # 장면이 눕혀 둔 용(999)은 빼고
			if n != self and n.down_timer > 0 and n.down_timer < 900 and (n.config.get("fixed") or n.state != "WANDER") and Util.dist(self, n) < float(r.reach):
				mending = n
				mend_t = float(r.mend)
				break
	if mending == null: return false
	if Util.dist(self, mending) > 60:
		move_by(mending.x - x, mending.y - y, 260, dt)
		return true
	mend_t -= dt
	if randf() < 0.3: Particles.burst(mending.x, mending.y - 30, "#9fe08a", 0.4, 3)
	if mend_t > 0: return true
	mending.down_timer = 0.0
	mending.hp = mending.max_hp * 0.5
	Vfx.spawn_effect("RING", mending.x, mending.y - 20, { size = 1.0, color = "#9fe08a" })
	Hud.pop("%s %s 일으켰습니다." % [Util.josa(Names.npc(config.name), "이", "가"), Util.josa(Names.npc(mending.config.name), "을", "를")], "💚")
	mending = null
	return false


## 짝·동료: 플레이어를 따라다닌다. 싸우는 중엔 조금 더 떨어져도 봐준다
func _update_partner(dt: float, fighting := false) -> void:
	var p = GameState.player
	if Util.dist(self, p) > (260 if fighting else 110):
		# 싸우는 중이라면 몸은 플레이어를 쫓아가도 얼굴은 적에게 둔다
		var look := facing
		move_by(p.x - x, p.y - y, 240, dt)
		if fighting: facing = look


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
	if beam: _draw_beam()
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
		shape = stage.get("shape") if is_player and species != "HERO" else null,   # 자라면서 몸 비율이 바뀌는 건 내 용뿐이다 (마을 용은 다 성체). HERO 는 단계마다 그림이 따로 있다
	}
	SpriteSheet.draw_frame(self, sheet, f, 0, body_y - dive_height, sc, motion, _outline)
	_draw_accessory(sc, hover_y - dive_height)
	# 정체의 무늬. 어린 용이 된 뒤 목 아래에서 희미하게 빛나고, 자랄수록 또렷해진다
	if is_player and not GameState.story.get("rites", []).is_empty():
		var n: int = GameState.story.rites.size()
		var pulse := 0.22 + n * 0.08 + sin(GameState.game_time * 2.2) * 0.08
		var fx := (-6.0 if facing == "left" else 6.0 if facing == "right" else 0.0) * sc
		Pixel.draw_glow(self, fx, hover_y - dive_height - 30 * sc, (7 + n * 2) * sc, Color("#c58aff"), pulse)
	if fishing: _draw_fishing(sc)
	if carrying == "EGG": Pixel.draw_icon(self, "EGG", 0, -100 * sc + hover_y, 2.5)
	if not is_player: _draw_hp_bar(hp / max_hp, -12, 60)
	else: _draw_player_bar()


## 낚싯줄과 찌. 입질이 오면 찌가 떨고 느낌표가 뜬다
func _draw_fishing(sc: float) -> void:
	var f: Dictionary = fishing
	var bob := sin(GameState.game_time * 40) * 5 if f.bite > 0 else sin(GameState.game_time * 3) * 2
	var fx: float = f.x - x
	var fy: float = f.y - y
	var p0 := Vector2(0, -50 * sc)
	var c := Vector2(fx / 2, minf(0, fy) - 70)
	var p1 := Vector2(fx, fy + bob)
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(p0.lerp(c, t).lerp(c.lerp(p1, t), t))
	draw_polyline(pts, Color(1, 1, 1, 0.7), 1.5, true)
	draw_rect(Rect2(fx - 4, fy - 5 + bob, 8, 5), Color("#ff4d4d"))
	draw_rect(Rect2(fx - 4, fy + bob, 8, 5), Color.WHITE)
	if f.bite > 0:
		var font := Fonts.bold()
		var w := Fonts.text_width(font, "!", 36)
		draw_string_outline(font, Vector2(fx - w / 2, fy - 22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 5, Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(fx - w / 2, fy - 22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#ffd84a"))


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


## 삼원 융합 브레스: 불·얼음·번개 세 가닥이 꼬인 빛줄기.
## 2D판은 더하기('lighter')로 그린다. 한 노드 안에서 섞기를 바꿀 수 없어 반투명으로 얹는다 (조명을 옮길 때 더하기 층으로)
func _draw_beam() -> void:
	var b: Dictionary = beam
	var sc: float = stage.scale
	var o := Vector2(0, -40 * sc)
	var k := minf(1, b.time * 3)
	var n := Vector2(-sin(b.angle), cos(b.angle))
	var dir := Vector2(cos(b.angle), sin(b.angle))
	var strands := [[Color("#ff7a2a"), -1], [Color("#7fd4ff"), 0], [Color("#ffe27a"), 1]]
	for i in 3:
		var wob := sin(GameState.game_time * 22 + i * 2) * 14
		draw_line(o, o + dir * 950 + n * (strands[i][1] * 30 + wob), Color(strands[i][0], 0.5), 46 * k, true)
	draw_line(o, o + dir * 950, Color(1, 1, 1, 0.95), 18 * k, true)


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
	if not is_hidden and _emote != "": _draw_emote(ci)
	if is_player or is_hidden or Cutscene.on: return   # 컷씬에서는 대화창이 말하는 이를 알려 준다
	var nm := Names.npc(config.get("name", ""))
	var bold := Fonts.bold()
	var nw := ceilf(Fonts.text_width(bold, nm, 12)) + 16
	ci.draw_rect(Rect2(-nw / 2, -16, nw, 21), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.78))
	ci.draw_rect(Rect2(-nw / 2, 4, nw, 1), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.55))
	Fonts.draw_centered(ci, bold, nm, 0, 0, 12, Color("#ece3cf"))
	# 퀘스트 표시 (! 새 부탁 / ? 보고할 것)
	var mark: String = Quests.marker(self) if config.get("fixed") else ""
	if mark != "":
		var my := -26 + sin(GameState.game_time * 4) * 3
		var mw := Fonts.text_width(bold, mark, 36)
		ci.draw_string_outline(bold, Vector2(-mw / 2, my), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 5, Color(0, 0, 0, 0.8))
		ci.draw_string(bold, Vector2(-mw / 2, my), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#7dd36a") if mark == "?" else Color("#ffd84a"))
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


## 머리 위 표시. 톡 튀어나왔다가(0.12초) 머물고, 끝에 스르르 사라진다
func _draw_emote(ci: CanvasItem) -> void:
	var t := (Time.get_ticks_msec() - _emote_at) / 1000.0
	if t > Cutscene.EMOTE_TIME:
		_emote = ""
		return
	var pop := minf(1, t / 0.12)
	var sc := 1.0 + (1 - pop) * 0.6 if t < 0.12 else 1.0 + sin(minf(1, (t - 0.12) / 0.2) * PI) * 0.08
	var alpha := minf(1, (Cutscene.EMOTE_TIME - t) / 0.35)
	var col := Color("#ffd84a")
	match _emote:
		"?", "!?": col = Color("#9fd6ff")
		"♥": col = Color("#ff7aa8")
		"💢": col = Color("#ff6a5a")
		"💧": col = Color("#8fc8ff")
		"…": col = Color("#ece3cf")
		"♪": col = Color("#b7f0a0")
	var glyph := _emote
	if glyph == "💢": glyph = "#"      # 픽셀 글꼴에 없는 그림 글자는 비슷한 모양으로
	elif glyph == "💧": glyph = ";"
	var font := Fonts.bold()
	var fs := 24   # 12px 픽셀 글꼴은 12의 배수로만 또렷하다
	var w := maxf(34, Fonts.text_width(font, glyph, fs) + 18) * sc
	var h := 32.0 * sc
	var by := -34.0 - h - (30 if Quests.marker(self) != "" and config.get("fixed") else 0)
	var bob := sin(t * 5) * 2
	_bubble(ci, -w / 2, by + bob, w, h, by + h + bob, alpha)
	var tw := Fonts.text_width(font, glyph, fs)
	ci.draw_string(font, Vector2(-tw / 2, by + bob + h / 2 + fs * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.darkened(0.55), alpha))


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
