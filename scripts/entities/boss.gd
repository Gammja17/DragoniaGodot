class_name Boss
extends Node2D
## 2D판 entities/Boss.js. 보스. 공통 패턴(RING, AIMED, SPIRAL, CHARGE) 위에 보스마다 고유 기믹이 있다 (data/enemies 의 patterns).
##  모르가스: SUMMON(망령 소환), BONE_RAIN(얼음 기둥 비), 한 번 되살아난다(revive). 뼈 무더기에서 일어선다(rise)
##  잘고라:   TWIN_BEAM(두 머리의 회전 광선), 조준탄이 불·번개를 번갈아 쏜다. BUMP(두 머리가 들이받아 휘청인다)
##  글라시아: HOMING(따라오는 얼음 조각), ICE_FIELD(느려지는 빙판), BLIZZARD(눈보라에 밀려남).
##            알 벽을 지킨다(guards: 그쪽으로는 쏘지 않고 다가오면 밀어낸다). 마지막 판은 장면으로 멈춘다(yield)
##  바실:     BURROW(땅속으로 숨었다가 발밑에서 솟구침), QUAKE(번져 나가는 충격파 고리).
##            모래 밑에서 솟는다(rise). 돌진이 끝나면 등의 창끝이 빛나는 빈틈(spears)
##  이그나르: METEOR_RAIN, FLAME_WALL(틈이 있는 불의 벽). 마지막 판 전에 카이론이 합류한다(phases.scene),
##            마지막 판에는 내 속성을 따라 쓴다(mirror)
## 때리는 힘은 결투장의 세기를 따른다 (_hit: 잡몹과 같은 셈)
##
## 그리는 순서: [이 노드] 그림자·빛·돌진 예고선 → [BeamFx] 회전 광선(더하기) → [Body] 몸(맞으면 밝게) → [Top] z z z

const WAKE_RANGE := 520     # 이 안에 들어오면 깨어난다
const LEASH_RANGE := 1100   # 결투장에서 이만큼 벗어나면 돌아가서 회복
const ORB_SPEED := 300
const COLOR_MATRIX := preload("res://shaders/color_matrix.gdshader")

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var id: String
var def: Dictionary
var home := Vector2.ZERO
var hp: float
var max_hp: float
var status := {}
var status_immune := true
var sheet: SpriteSheet
var animator: SpriteSheet.Animator
var facing := "down"
var awake := false
var hit_flash := 0.0
var squash := 0.0
var pattern_timer := 2.0
var pattern_index := 0
var revived := false
var phase2 := false
var phase := 0               # 몇 번째 페이즈인가 (phases)
var stagger := 0.0           # 페이즈가 넘어가는 동안, 간발로 빈틈이 난 동안 잠깐 숨을 고른다
var opening := false         # 간발로 만든 빈틈 — 두 배로 맞는다
var is_hidden := false       # 땅속에 있는 동안: 안 보이고 안 맞는다
var remove := false
var spiral = null            # { left, angle, timer }
var charge = null            # { windup, time, angle, chain }
var beam = null              # { time, angle, spin, warm }
var burrow = null            # { time, erupting }
var blizzard = null          # { time, angle, timer }
var type := "BOSS"
var dying := 0.0             # 쓰러지는 중: 흰 빛 속에 무너지는 남은 시간
var lingering := false       # 무너진 뒤: 흐릿하게 남아 마지막 말을 한다 (이그나르는 무릎을 꿇은 채 남는다). 장면이 끝나면 흩어진다
var vanishing := 0.0         # 빛가루로 흩어지는 남은 시간
var _linger_until := 0
var tell = null              # 탄막을 뿜기 직전의 예고 { pat, t } — 몸이 번쩍이고 경고음이 난다. 이 동안 피할 자리를 찾는다
var threat := 0.0            # 큰 공격이 날아오는 중인 남은 시간 (간발 판정 창)
const TELL_PATTERNS := ["RING", "AIMED", "SPIRAL", "HOMING"]
const GROUND_PATTERNS := ["BONE_RAIN", "ICE_FIELD", "METEOR_RAIN", "QUAKE", "FLAME_WALL"]
const DYING_TIME := 1.8
const VANISH_TIME := 1.6
const RISE_TIME := 1.8       # 흩어진 뼈가 맞춰져 일어서는 데 걸리는 시간 (def.rise)
static var _introduced := {} # 이번 판에 등장 장면을 본 보스

# def.rise = "bones" 인 보스(모르가스)는 뼈 무더기로 누워 있다가, 깨어나면 뼈가 맞춰지며 일어선다
var risen := 1.0             # 0: 뼈 무더기 → 1: 다 일어섬
var rising := false          # 일어서는 중 (이 동안은 맞지도 때리지도 않는다)
var frost_at := -1.0         # 깨어나며 서리가 번지기 시작한 때 (game_time). 결투장의 FROST 가 따라 짙어진다
var thaw_at := -1.0          # 쓰러진 때. 서리와 도깨비불이 녹아 사라진다

# def.guards (글라시아): 결투장의 그 소품(알 벽)을 지킨다. 그쪽으로는 쏘지 않고, 가까이 오면 몸으로 밀어낸다
const GUARD_RADIUS := 330.0
var guard = null             # 지키는 것의 가운데 (Vector2). 처음 쓸 때 찾는다
var shove := 0.0             # 밀어내는 남은 시간
var shove_dir := Vector2.ZERO
var _warned_at := -99.0
var yielding := false        # 싸움을 멈추고 장면을 기다린다 (phases 의 yield)
var wrap_to = null           # 장면 속에서 옮겨 가는 자리 (Vector2)
var ally = null              # 싸움 도중 합류한 용 (이그나르: 카이론). 쓰러지면 공격을 멈추게 하고, 결투장을 떠나면 되돌린다
var _ally_home := Vector2.ZERO
var _mirror_i := 0           # def.mirror: 마지막 판에 내 속성을 번갈아 따라 쓴다 (이그나르의 세 빛깔 불)
var _spear_hinted := false   # def.spears: 창끝이 빛나는 빈틈을 처음 한 번 알려 준다 (바실)
var _dmg_k := -1.0           # 때리는 힘의 배율: 지도 세기(Enemy.MAP_POWER)의 절반만큼 (잡몹과 같은 셈)

var _fx: Node2D
var _body: Node2D
var _top: Node2D


static func make(boss_id: String) -> Boss:
	var b := Boss.new()
	b.id = boss_id
	b.def = Data.get_module("enemies").BOSSES[boss_id]
	# 결투장 자리는 지도가 정한다 (World 가 덮어쓴다). def 의 좌표는 대비책
	b.x = b.def.x; b.y = b.def.y
	b.home = Vector2(b.def.x, b.def.y)
	b.hp = b.def.hp; b.max_hp = b.def.hp
	b.sheet = DragonSprites.get_sheet(b.def.species, b.def.colors, int(b.def.get("look", 0)))
	b.animator = SpriteSheet.Animator.new(b.sheet)
	b.name = "Boss_" + boss_id
	if b.def.get("rise"): b.risen = 0.0
	return b


func _ready() -> void:
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_beam)
	add_child(_fx)
	_body = Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = COLOR_MATRIX
	_body.material = mat
	# 줄여 그리는 시트는 보간을 켜 둬야 획이 빠지지 않는다
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if sheet.scale * def.scale < 1 else CanvasItem.TEXTURE_FILTER_NEAREST
	_body.draw.connect(_draw_body)
	add_child(_body)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)
	BossVoice.prepare(id)   # 울음을 미리 불러 둔다


## 결투장을 떠날 때 (지도가 바뀌거나 흩어져 사라질 때): 합류했던 용을 제 모습으로
func _exit_tree() -> void:
	if awake and dying <= 0 and Hud.current: Hud.current.set_boss_bar(null)   # 싸우다 떠나거나 쓰러져 지도가 바뀌어도 막대가 남지 않게
	if ally and is_instance_valid(ally):
		ally.passive = false
		ally.state = "WANDER"
		ally.home_x = _ally_home.x; ally.home_y = _ally_home.y
	ally = null


var rage: bool:
	get: return phase == def.phases.size() - 1 if def.get("phases") else (hp < def.hp * 0.4 or phase2)


func light():
	if is_hidden: return null
	var k := maxf(risen, 0.3)   # 뼈 무더기일 때는 희미하게
	return { r = 360, color = Data.get_module("elements").ELEMENTS[def.element].color, intensity = (0.9 if awake else 0.4) * k, dy = -60 }


func update(dt: float) -> void:
	if hit_flash > 0: hit_flash -= dt * 8
	if squash > 0: squash -= dt * 7
	var player = GameState.player
	var d := Util.dist(self, player)
	if not awake:
		# 이그나르는 먼저 말을 건다. 대면(ev_ignar_meet)에서 무엇을 고를지 정하기 전에는 깨어나지 않고, 손을 잡았다면 끝내 싸우지 않는다
		var held: bool = id == "IGNAR" and (GameState.story.get("route") == "dark" \
			or (GameState.quests.active.has("m6") and not GameState.story.get("choices", {}).get("ev_ignar_meet")))
		if d < WAKE_RANGE and not held:
			awake = true
			# 처음 만날 때는 장면으로 (카메라가 건너가고, 포효와 이름패). 다시 덤빌 때는 짧게
			if not _introduced.has(id) and not GameState.isDialogueOpen:
				_introduced[id] = true
				BossShow.intro(self)
			else:
				Cutscene.show_card(def.name, def.title, 1.8)
				Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 3, color = _el_color() })
				GameCamera.current.shake(10); BossVoice.cry(id)
				if def.get("rise"): start_rise()   # 다시 덤빌 때는 장면 없이 곧바로 일어선다
		animator.play_base("idle")
		animator.update(dt)
		return
	if rising:
		_update_rise(dt)
		return
	if risen < 1.0:   # 깨어났지만 등장 장면이 아직 뼈를 일으키기 전
		animator.update(dt)
		return
	if vanishing > 0:
		_update_vanish(dt)
		return
	if lingering:
		_update_linger(dt)
		return
	if dying > 0:
		_update_dying(dt)
		return
	if yielding:   # 싸움을 멈추고 장면을 기다린다
		animator.update(dt)
		return
	if shove > 0:   # 알 벽에서 밀려난다
		shove -= dt
		player.x += shove_dir.x * 560 * dt; player.y += shove_dir.y * 560 * dt
	if Util.dist(self, home) > LEASH_RANGE or d > LEASH_RANGE * 1.3:
		reset()
		return
	var speed_mult := Status.update(self, dt)
	if remove: return
	if def.get("phase2") and not phase2 and hp < def.hp * 0.5: _enter_phase2()
	# 페이즈: 체력이 문턱 아래로 내려가면 판이 바뀐다. 넘어가는 동안은 공격을 멈추고, 날아오던 탄도 걷힌다
	var phases = def.get("phases")
	if phases and phase + 1 < phases.size() and hp <= def.hp * phases[phase + 1].at: _enter_phase(phase + 1)
	if stagger > 0:
		stagger -= dt
		pattern_timer = maxf(pattern_timer, 0.6)
		if stagger <= 0: opening = false
	if threat > 0: threat -= dt
	if tell:
		tell.t -= dt
		if tell.t <= 0:
			var pat: String = tell.pat
			tell = null
			_fire(pat)

	var moving := false
	if burrow: _update_burrow(dt)
	elif charge: moving = _update_charge(dt, speed_mult)
	elif beam: _update_beam(dt)
	elif _blocking(dt, speed_mult): moving = true   # 알 벽에 다가오면 몸으로 막아선다
	else:
		# 적당한 거리를 두고 빙빙 돈다
		var a := atan2(player.y - y, player.x - x)
		var want := a if d > 300 else a + PI if d < 200 else a + PI / 2
		var sway := 0.25 if opening else 1.0   # 빈틈(비틀거림) 동안은 굼뜨다
		x += cos(want) * def.speed * speed_mult * sway * dt
		y += sin(want) * def.speed * speed_mult * sway * dt
		facing = Dragon.facing_from_vector(player.x - x, player.y - y, facing)
		moving = speed_mult > 0
		pattern_timer -= dt * (1 if speed_mult > 0 else 0)
		if pattern_timer <= 0 and tell == null: _start_pattern()
	if spiral: _update_spiral(dt)
	if blizzard: _update_blizzard(dt)

	if not is_hidden and d < 60 * def.scale: player.take_damage(_hit(def.contact) * dt * (2 if charge and not charge.windup > 0 else 1))

	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	var phase_name: String = (" · " + phases[phase].name) if phases else (" (분노)" if phase2 else "")
	Hud.current.set_boss_bar(def.name + phase_name, hp / def.hp)


func _el_color() -> Color:
	return Color(Data.get_module("elements").ELEMENTS[def.element].color)


## 지키는 것의 가운데 (def.guards 의 소품). 결투장에 없으면 null
func _guard():
	if guard == null and def.get("guards"):
		var best = null
		for p in GameState.entities.props:
			if p.type == def.guards and (best == null or Util.dist(p, self) < Util.dist(best, self)): best = p
		if best: guard = Vector2(best.x, best.y - 90)
	return guard


## 지키는 것 가까이 오면 그 사이를 막아서고, 닿으면 밀어낸다 (글라시아). 막아서는 동안은 쏘지 않는다
func _blocking(dt: float, speed_mult: float) -> bool:
	if _guard() == null: return false
	var p = GameState.player
	var pp := Vector2(p.x, p.y)
	if pp.distance_to(guard) > GUARD_RADIUS: return false
	var to: Vector2 = guard.lerp(pp, 0.6) - Vector2(x, y)
	if to.length() > 6:
		var step := minf(to.length(), def.speed * 1.9 * speed_mult * dt)
		x += to.normalized().x * step; y += to.normalized().y * step
	facing = Dragon.facing_from_vector(p.x - x, p.y - y, facing)
	if shove <= 0 and Vector2(x, y).distance_to(pp) < 70 * def.scale:
		shove = 0.35
		shove_dir = (pp - guard).normalized()
		p.take_damage(_hit(10))
		Sfx.play("gust")
		Vfx.spawn_effect("GUST", p.x, p.y - 30, { size = 1.6, color = "#bfe9ff" })
		if GameState.game_time - _warned_at > 10 and def.get("guardSay"):
			_warned_at = GameState.game_time
			BossShow.say(self, def.guardSay)
	return true


## 아직 거치지 않은, 장면이 있는 판(yield · scene)의 번호. 없으면 -1
func _must_phase() -> int:
	var phases = def.get("phases")
	if phases:
		for i in range(phase + 1, phases.size()):
			if phases[i].get("yield") or phases[i].get("scene"): return i
	return -1


## 바실: 돌진이 끝나 숨을 고르는 동안 등에 박힌 창끝이 빛난다 — 이때 치면 두 배로 들어간다
func _spear_opening() -> void:
	stagger = 1.6
	opening = true
	Sfx.play("chime")
	if not _spear_hinted:
		_spear_hinted = true
		Hud.pop("등에 박힌 창끝이 빛납니다. 지금 치면 두 배로 들어갑니다!", "🎯")


## 장면 속에서 제자리로 옮겨 간다 (글라시아가 알 벽 앞으로 가서 등을 돌린다)
func _step_wrap(dt: float) -> void:
	var d: Vector2 = wrap_to - Vector2(x, y)
	if d.length() < 4:
		x = wrap_to.x; y = wrap_to.y
		wrap_to = null
		facing = "up"
		animator.play_base("idle")
		return
	var step := minf(d.length(), 240 * dt)
	x += d.normalized().x * step; y += d.normalized().y * step
	facing = Dragon.facing_from_vector(d.x, d.y, facing)
	animator.play_base("move")
	animator.update(dt)


## 뼈가 맞춰지기 시작한다 (등장 장면의 { boss = "rise" }, 다시 덤빌 때, 되살아날 때)
func start_rise() -> void:
	rising = true
	if frost_at < 0: frost_at = GameState.game_time


func finish_rise() -> void:
	if risen >= 1.0 and not rising: return
	risen = 1.0
	rising = false
	if frost_at < 0: frost_at = GameState.game_time
	pattern_timer = maxf(pattern_timer, 1.2)   # 일어서자마자 쏟아붓지 않게
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 2.4, color = _el_color() })


## 무너졌다가 다시 맞춰진다 (되살아날 때)
func collapse() -> void:
	risen = 0.0
	for i in 5: Vfx.spawn_effect("SMOKE", x + Util.rand_range(-90, 90), y - Util.rand_range(0, 120), { size = 1.4 })
	start_rise()


## 일어서는 동안: 몸이 땅에서 차오르고, 둘레에 찬 김과 뼛가루가 인다
func _update_rise(dt: float) -> void:
	risen = minf(1.0, risen + dt / RISE_TIME)
	animator.play_base("idle")
	animator.update(dt)
	if def.get("rise") == "sand":   # 모래를 뚫고 솟는다
		if randf() < 0.5: Vfx.spawn_effect("DUST", x + Util.rand_range(-110, 110), y - Util.rand_range(0, 40), { size = 1.5, color = "#c9a24a" })
		if randf() < 0.08: GameCamera.current.shake(4)
	else:   # 찬 김과 뼛가루
		if randf() < 0.5: Vfx.spawn_effect("SPARKLE", x + Util.rand_range(-110, 110), y - Util.rand_range(0, 60), { size = 1.2, color = "#e8f6ff" })
		if randf() < 0.12: Vfx.spawn_effect("SMOKE", x + Util.rand_range(-80, 80), y - Util.rand_range(0, 40), { size = 1.1 })
	if risen >= 1.0: finish_rise()


func reset() -> void:
	awake = false
	x = home.x; y = home.y
	hp = def.hp
	is_hidden = false; phase2 = false
	phase = 0; stagger = 0.0   # 쓰러지면 처음부터 다시다
	revived = false            # 되살아나는 것까지 처음부터
	yielding = false; wrap_to = null; shove = 0.0
	if def.get("rise"):        # 다시 뼈 무더기로 눕고, 서리도 옅어진다
		risen = 0.0; rising = false; frost_at = -1.0
	charge = null; spiral = null; beam = null; burrow = null; blizzard = null
	tell = null; threat = 0.0
	Hud.current.set_boss_bar(null)


## 판이 바뀐다: 한마디 하고, 탄을 걷고, 잠깐 숨을 고른 뒤 새 패턴으로
func _enter_phase(i: int) -> void:
	var ph: Dictionary = def.phases[i]
	phase = i
	if ph.get("yield"):   # 싸움을 멈추고 장면으로 (글라시아: 카이론이 그이의 말을 전한다)
		BossShow.yield_to(self)
		return
	if ph.get("scene"):   # 잠깐 멈추고 장면을 본 뒤 이 판을 시작한다 (이그나르: 카이론이 내려앉는다)
		BossShow.phase_scene(self, i)
		return
	start_phase(i)


## 판을 시작한다: 탄을 걷고, 잠깐 숨을 고른 뒤 새 패턴으로
func start_phase(i: int) -> void:
	var ph: Dictionary = def.phases[i]
	pattern_index = 0
	stagger = 1.4
	charge = null; spiral = null; beam = null; burrow = null; blizzard = null
	tell = null
	is_hidden = false
	for b in GameState.entities.bullets:
		if b.faction == "ENEMY": b.remove = true
	if i == def.phases.size() - 1: phase2 = bool(def.get("glow", false))
	BossShow.phase(self, ph)   # 세상이 잠깐 느려지고 보스의 한마디가 자막으로
	BossVoice.cry(id, "phase")
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 3.5, color = _el_color() })
	GameCamera.current.shake(12); Sfx.play("dieBig")
	if ph.get("summon"): _summon(ph.summon)


func _enter_phase2() -> void:
	phase2 = true
	Hud.pop("%s의 분노! 하늘이 불타오릅니다." % def.name, "🔥")
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 4, color = "#ff5a1f" })
	GameCamera.current.shake(16); Sfx.play("dieBig")
	_summon(["CULTIST", "CULTIST", "MAGMA_SLIME"])


func _mouth() -> Vector2:
	return Vector2(x, y - (70 if def.species == "SHADOW" else 50) * def.scale)


func _orb(angle: float, damage := 11.0, opts := {}) -> void:
	var m := _mouth()
	if _guard() != null and absf(angle_difference(angle, m.angle_to_point(guard))) < 0.55: return   # 알 쪽으로는 쏘지 않는다
	var o := { faction = "ENEMY", element = def.element, damage = damage, speed = ORB_SPEED, life = 3.2, scale = 0.8 }
	o.merge(opts, true)
	o.damage = _hit(float(o.damage))
	var mine: Array = GameState.player.elements
	if def.get("mirror") and rage and not mine.is_empty():   # 마지막 판에는 내가 가진 속성을 번갈아 따라 쓴다
		o.element = mine[_mirror_i % mine.size()]
		_mirror_i += 1
	Projectile.add(Projectile.new(m.x, m.y, angle, o))


## 보스가 때리는 힘. 지도가 셀수록 세다 (잡몹처럼: 체력은 그대로, 때리는 힘은 절반만큼 곱한다)
func _hit(v: float) -> float:
	if _dmg_k < 0: _dmg_k = 1.0 + (Enemy.map_power() - 1.0) * 0.5
	return v * _dmg_k


## 보스의 장판. 피해도 지도 세기를 따른다
func _hazard(hx: float, hy: float, opts: Dictionary) -> void:
	if opts.has("damage"): opts.damage = _hit(float(opts.damage))
	if opts.has("dps"): opts.dps = _hit(float(opts.dps))
	Hazard.add(hx, hy, opts)


func _summon(types: Array) -> void:
	for t in types:
		var a := Util.rand_range(0, 6.28)
		var e := Enemy.make(x + cos(a) * 220, y + sin(a) * 160, t)
		e.aggro = true
		World.add_entity("enemies", e)
		Vfx.spawn_effect("MAGIC_CIRCLE", e.x, e.y, { size = 1, color = _el_color() })
	Sfx.play("summon")


## 다음 패턴을 고른다. 탄을 곧바로 쏟는 패턴은 짧게 예고한 뒤에 쏜다 (몸이 번쩍이고 경고음) —
## 예전에는 고르는 그 프레임에 열여섯 발이 한꺼번에 나와서 읽을 틈이 없었다
func _start_pattern() -> void:
	var patterns: Array = def.phases[phase].patterns if def.get("phases") else def.patterns
	var pat: String = patterns[pattern_index % patterns.size()]
	pattern_index += 1
	pattern_timer = 1.9 if rage else 2.9
	if TELL_PATTERNS.has(pat):
		tell = { pat = pat, t = 0.35 if rage else 0.5 }
		Sfx.play("warn")
		return
	_fire(pat)


func _fire(pat: String) -> void:
	var r := rage
	threat = 2.0 if GROUND_PATTERNS.has(pat) else 0.9
	animator.play("attack")
	var player = GameState.player
	var m := _mouth()
	var aim := atan2(player.y - 40 - m.y, player.x - m.x)
	match pat:
		"RING":
			var n := 22 if r else 16
			var off := Util.rand_range(0, 6.28)
			for i in n: _orb(off + (i / float(n)) * TAU)
			Sfx.play("flame")
		"AIMED":
			# 잘고라는 두 머리가 불과 번개를 번갈아 뱉는다
			var spreads := [-0.4, -0.2, 0.0, 0.2, 0.4] if r else [-0.22, 0.0, 0.22]
			for i in spreads.size():
				_orb(aim + spreads[i], 13, { element = "FIRE" if i % 2 else "THUNDER" } if def.get("twin") else {})
			Sfx.play("shoot")
		"SPIRAL":
			spiral = { left = 36 if r else 24, angle = aim, timer = 0.0 }
		"CHARGE":
			charge = { windup = 0.7, time = 0.75, angle = aim, chain = (3 if r else 2) if def.get("chargeChain") else 1 }
			Sfx.play("warn")
		"BUMP":   # 잘고라: 두 머리가 같은 곳을 노리다 서로 들이받는다. 휘청이는 동안은 두 배로 맞는다
			stagger = 1.6
			opening = true
			GameCamera.current.shake(8); Sfx.play("thud")
			Vfx.spawn_effect("STAR", x, y - 95 * def.scale, { size = 2.2 })
			var lines = def.get("bumpSay")
			if lines: BossShow.say(self, lines.pick_random())
		"SUMMON":
			_summon(["GHOST", "GHOST", "BAT", "BAT"] if r else ["GHOST", "BAT", "BAT"])
		"BONE_RAIN":
			for i in (9 if r else 6):
				_hazard(player.x + Util.rand_range(-260, 260), player.y + Util.rand_range(-200, 200), { r = 80, delay = 0.8 + i * 0.12, damage = 16, color = "#bfe9ff",
					effect = "ICE_SPIKE", effectSize = 1.5, sound = null if i % 3 else "freeze", status = { type = "SLOW", duration = 1.5 } })
		"TWIN_BEAM":
			beam = { warm = 0.9, time = 4.0 if r else 3.0, angle = aim + 0.9, spin = (-1 if randf() < 0.5 else 1) * (1.1 if r else 0.85) }
			Sfx.play("warn")
		"HOMING":
			for i in (7 if r else 5): _orb(aim + (i - 2) * 0.5, 10, { homing = 1.6, speed = 230, life = 4.5 })
			Sfx.play("ice")
		"ICE_FIELD":
			for i in (5 if r else 3):
				var hx: float = player.x + Util.rand_range(-220, 220)
				var hy: float = player.y + Util.rand_range(-160, 160)
				if _guard() != null and Vector2(hx, hy).distance_to(guard) < 240: continue   # 알 벽 둘레에는 깔지 않는다
				_hazard(hx, hy, { r = 130, delay = 0.7, linger = 6, damage = 8, dps = 5, slow = true, color = "#7fd4ff", effect = "ICE_SPIKE", effectSize = 2, sound = "freeze" })
		"BLIZZARD":
			# 지키는 것이 있으면 그 반대쪽으로 불어 낸다 (얼음 조각이 알 쪽으로 날지 않게)
			var wind: float = Util.rand_range(0, 6.28) if _guard() == null else guard.angle_to_point(Vector2(player.x, player.y)) + Util.rand_range(-0.4, 0.4)
			blizzard = { time = 5.0 if r else 3.5, angle = wind, timer = 0.0 }
			Hud.pop("눈보라가 몰아칩니다! 바람을 거슬러 버티세요.", "🌨️")
			Sfx.play("gust")
		"BURROW":
			burrow = { time = 1.6 if r else 2.2, erupting = false }
			is_hidden = true
			Vfx.spawn_effect("DUST", x, y, { size = 3, color = "#c9a24a" })
			Sfx.play("gust")
		"QUAKE":
			for i in (4 if r else 3):
				_hazard(x, y, { r = 170 + i * 150, inner = 70 + i * 150, delay = 0.7 + i * 0.45, damage = 20, color = "#d8a24a", sound = "boom", shake = 8 })
			Sfx.play("warn")
		"METEOR_RAIN":
			for i in (11 if r else 7):
				var px: float = player.x + Util.rand_range(-320, 320)
				var py: float = player.y + Util.rand_range(-240, 240)
				_hazard(px, py, { r = 110, delay = 0.9 + i * 0.16, linger = 2, damage = 24, dps = 8, color = "#ff5a1f", effect = "FIRE_HIT", effectSize = 2.2, sound = "boom", shake = 6 })
			Sfx.play("warn")
		"FLAME_WALL":
			# 플레이어를 가로지르는 불의 벽. 한 군데 틈이 있다
			var across := aim + PI / 2
			var gap := floori(Util.rand_range(2, 9))
			for i in 11:
				if i == gap or i == gap + 1: continue
				var k := (i - 5) * 95
				_hazard(player.x + cos(across) * k + cos(aim) * 40, player.y + sin(across) * k + sin(aim) * 40,
					{ r = 60, delay = 1.0, linger = 3.5, damage = 18, dps = 14, color = "#ff7a2a", effect = "FLAMES", effectSize = 1.4, sound = "flame" if i == 0 else null })
			Sfx.play("warn")


func _update_spiral(dt: float) -> void:
	var s: Dictionary = spiral
	s.timer -= dt
	while s.timer <= 0 and s.left > 0:
		_orb(s.angle, 9)
		s.angle += 0.52
		s.left -= 1
		s.timer += 0.065
	if s.left <= 0: spiral = null


func _update_charge(dt: float, speed_mult: float) -> bool:
	var c: Dictionary = charge
	var player = GameState.player
	if c.windup > 0:               # 돌진 전 움찔 (피할 시간)
		c.windup -= dt
		c.angle = atan2(player.y - y, player.x - x)
		return false
	c.time -= dt
	x += cos(c.angle) * 620 * speed_mult * dt
	y += sin(c.angle) * 620 * speed_mult * dt
	facing = Dragon.facing_from_vector(cos(c.angle), sin(c.angle), facing)
	if randf() < 0.5: Particles.burst(x, y, Data.get_module("elements").ELEMENTS[def.element].trail, 0.5)
	if randf() < 0.25: Vfx.spawn_effect("DUST", x, y, { size = 1.2, color = "#c9b18a" })
	if c.time <= 0:
		c.chain -= 1
		if c.chain > 0:
			c.windup = 0.45; c.time = 0.7; Sfx.play("warn")   # 바실: 연속 돌진
		else:
			charge = null
			if def.get("spears"): _spear_opening()
	return true


## 잘고라: 두 머리에서 뻗는 회전 광선. warm 동안은 예고선만
func _update_beam(dt: float) -> void:
	var b: Dictionary = beam
	var player = GameState.player
	if b.warm > 0:
		b.warm -= dt
		if b.warm <= 0: Sfx.play("beam")
		return
	b.time -= dt
	b.angle += b.spin * dt
	var m := _mouth()
	for a in [b.angle, b.angle + PI]:
		# 광선(선분)과 플레이어 사이 거리
		var t := clampf((player.x - m.x) * cos(a) + (player.y - 30 - m.y) * sin(a), 0, 700)
		if Vector2(player.x - (m.x + cos(a) * t), player.y - 30 - (m.y + sin(a) * t)).length() < 30: player.take_damage(_hit(45) * dt)
	if b.time <= 0: beam = null


## 바실: 땅속에서 플레이어를 쫓다가 발밑에서 솟구친다
func _update_burrow(dt: float) -> void:
	var b: Dictionary = burrow
	var player = GameState.player
	b.time -= dt
	var a := atan2(player.y - y, player.x - x)
	x += cos(a) * 330 * dt
	y += sin(a) * 330 * dt
	if randf() < 0.4: Vfx.spawn_effect("DUST", x + Util.rand_range(-20, 20), y + Util.rand_range(-10, 10), { size = 0.9, color = "#c9a24a" })
	if b.time <= 0 and not b.erupting:
		b.erupting = true
		b.time = 0.75
		_hazard(x, y, { r = 170, delay = 0.75, damage = 34, color = "#d8a24a", effect = "DUST", effectSize = 3.5, sound = "boom", shake = 14 })
		Sfx.play("warn")
	elif b.time <= 0:
		is_hidden = false
		burrow = null


## 글라시아: 눈보라가 플레이어를 한쪽으로 밀어내고, 그 방향으로 얼음 조각이 날아든다
func _update_blizzard(dt: float) -> void:
	var z: Dictionary = blizzard
	var player = GameState.player
	z.time -= dt; z.timer -= dt
	player.x += cos(z.angle) * 150 * dt
	player.y += sin(z.angle) * 150 * dt
	if z.timer <= 0:
		z.timer = 0.22
		var side: float = z.angle + PI / 2
		var k := Util.rand_range(-420, 420)
		var sx: float = player.x - cos(z.angle) * 560 + cos(side) * k
		var sy: float = player.y - sin(z.angle) * 560 + sin(side) * k
		Projectile.add(Projectile.new(sx, sy, z.angle, { faction = "ENEMY", element = "ICE", damage = _hit(9), speed = 420, life = 2.8, scale = 0.7 }))
	if z.time <= 0: blizzard = null


func take_damage(dmg: float, silent := false, _from = null) -> void:
	if not awake or is_hidden or dying > 0 or lingering or vanishing > 0 or rising or risen < 1.0 or yielding: return
	if opening: dmg *= 2   # 간발로 만든 빈틈
	hp -= dmg
	if not silent:
		hit_flash = 1.0; squash = 1.0
	if hp > 0 or remove: return
	var yi := _must_phase()
	if yi >= 0:   # 장면이 있는 판은 한 방에 쓰러져도 거친다 (장면으로 끝나는 판이면 체력 1, 아니면 그 판의 몫부터)
		hp = 1.0 if def.phases[yi].get("yield") else def.hp * float(def.phases[yi].at)
		_enter_phase(yi)
		return
	if def.get("revive") and not revived:      # 모르가스: 죽지 못한 용. 무너졌다가 다시 맞춰진다
		revived = true
		hp = def.hp * 0.45
		BossShow.revive(self)
		_summon(["GHOST", "GHOST"])
		return
	die()


## 쓰러진다: 세상이 느려지고 흰 빛 속에 무너진다(_update_dying). 무너진 뒤에는 흐릿하게 남아 마지막 말을 하고(lingering),
## 장면이 끝나면 빛가루로 흩어진다. 숨결·기술·유물·경험치·이야기는 쓰러지는 그 순간에 준다 —
## 무너지는 사이에 내가 쓰러지거나 지도를 떠나도 잃지 않게 (이야기 장면은 무너짐이 끝날 때까지 Chronicle 이 기다린다)
func die() -> void:
	if dying > 0 or remove or lingering: return
	dying = DYING_TIME
	awake = true
	thaw_at = GameState.game_time   # 결투장의 서리와 도깨비불이 녹기 시작한다
	if ally and is_instance_valid(ally): ally.passive = true
	charge = null; spiral = null; beam = null; burrow = null; blizzard = null
	is_hidden = false
	Hud.current.set_boss_bar(null)
	GameState.bossesDefeated[id] = true
	for b in GameState.entities.bullets:
		if b.faction == "ENEMY": b.remove = true
	for e in GameState.entities.enemies: e.remove = true   # 불려 나온 졸개도 함께 흩어진다
	for h in GameState.entities.hazards:
		if h.get("faction") == "ENEMY": h.remove = true
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 4, color = "#fff2b0" })
	Vfx.spawn_effect("CRIT_FLASH", x, y - 60, { size = 3 })
	BossShow.finale(self)
	_grant()


## 무너진 뒤에도 흐려진 채 남는다. 이그나르(kneel)는 무릎을 꿇은 채 끝까지 남는다 (결말의 선택을 기다린다)
func _update_linger(dt: float) -> void:
	animator.play_base("idle")
	animator.update(dt * 0.5)
	if def.get("kneel"): return
	if Time.get_ticks_msec() > _linger_until and not Cutscene.on and not GameState.isDialogueOpen: vanish()


## 빛가루로 흩어진다 (장면이 끝날 때 · 결말에서 '끝낸다')
func vanish() -> void:
	if vanishing > 0 or remove: return
	lingering = false
	vanishing = VANISH_TIME
	Sfx.play("chime")


func _update_vanish(dt: float) -> void:
	vanishing -= dt
	animator.update(dt * 0.5)
	if randf() < 0.8: Vfx.spawn_effect("SPARKLE", x + Util.rand_range(-70, 70) * def.scale, y - Util.rand_range(10, 130) * def.scale, { size = 1.4, color = "#fff2b0" })
	if vanishing > 0: return
	remove = true
	Vfx.spawn_effect("BLOOM", x, y - 60, { size = 2.2 })
	Vfx.spawn_effect("RING", x, y - 60, { size = 2.0 })


## 세상이 멈춘 장면 안에서도 숨 쉬고, 흩어지던 것은 끝까지 흩어진다 (Cutscene.animate)
func animate_only(dt: float) -> void:
	if vanishing > 0: _update_vanish(dt)
	elif rising: _update_rise(dt)          # 등장 장면 속에서 뼈가 맞춰진다
	elif wrap_to != null: _step_wrap(dt)   # 장면 속에서 제자리로 옮겨 간다
	else: animator.update(dt * (0.5 if lingering else 1.0))


## 무너지는 동안: 몸이 떨리며 흐려지고, 빛가루가 솟는다. 다 흩어지면 보상을 남기고 사라진다
func _update_dying(dt: float) -> void:
	dying -= dt
	var k := 1.0 - dying / DYING_TIME
	hit_flash = 1.0 if fmod(k * 14, 2.0) < 1.0 else 0.0
	squash = 0.4
	animator.play_base("hit")
	animator.update(dt)
	if randf() < 0.7: Vfx.spawn_effect("SPARKLE", x + Util.rand_range(-70, 70) * def.scale, y - Util.rand_range(10, 130) * def.scale, { size = 1.3, color = "#fff2b0" })
	if randf() < 0.25: Vfx.spawn_effect("SMOKE", x + Util.rand_range(-90, 90), y - Util.rand_range(0, 120), { size = 1.4 })
	if dying > 0: return
	_drops()
	lingering = true
	_linger_until = Time.get_ticks_msec() + 7000


## 무너짐이 끝날 때: 떨어지는 것들과 마지막 빛
func _drops() -> void:
	for i in 6: Vfx.spawn_effect("SMOKE", x + Util.rand_range(-90, 90), y - Util.rand_range(0, 140), { size = 1.6 })
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 4, color = "#fff2b0" })
	Vfx.spawn_effect("RING", x, y - 60, { size = 2.6 })
	Vfx.spawn_effect("STAR", x, y - 60, { size = 3 })
	Vfx.spawn_effect("BLOOM", x, y - 60, { size = 2.4 })
	GameCamera.current.shake(18); Sfx.play("boom")
	for i in 5: World.add_entity("items", Item.make(x + Util.rand_range(-80, 80), y + Util.rand_range(-50, 50), "MEAT"))
	World.add_entity("items", Item.make(x, y + 40, "GOLD", 80 + roundi(def.xp / 10.0)))


## 쓰러뜨린 값: 숨결 · 기술 · 유물 · 경험치 · 이야기
func _grant() -> void:
	var player = GameState.player
	if def.get("unlock"): player.unlock_element(def.unlock)
	var skill = Data.get_module("skills").BOSS_SKILLS.get(id)
	if skill: Skills.learn(skill)
	var relic = Relics.boss_relic(id)
	if relic: Relics.grant(relic, x, y)
	player.gain_xp(def.xp)
	RelicOffer.offer("%s의 둥지에서" % def.name)   # 셋 중 하나 고르는 유물 (조용해지면 뜬다)
	Quests.notify("boss", id)


# ---------- 그리기 ----------

func _process(_dt: float) -> void:
	_body.material.set_shader_parameter("m", Basis.from_scale(Vector3(2.2, 2.2, 2.2)) if hit_flash > 0 else Basis.IDENTITY)   # 맞으면 brightness(2.2)
	var a := 1.0
	if vanishing > 0: a = (0.55 if not def.get("kneel") else 1.0) * vanishing / VANISH_TIME
	elif lingering: a = 1.0 if def.get("kneel") else 0.55   # 흐릿하게 남은 마지막 모습
	elif dying > 0: a = clampf(dying / DYING_TIME * 1.4, 0.55, 1)
	elif not awake and not Cutscene.on and not def.get("rise"): a = 0.75
	_body.modulate.a = a * risen   # 뼈 무더기일 때는 몸이 없다. 일어서며 차오른다
	queue_redraw(); _fx.queue_redraw(); _body.queue_redraw(); _top.queue_redraw()


func _draw() -> void:
	if is_hidden: return
	var sc: float = def.scale
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 40 * sc * (0.5 + 0.5 * risen), Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if def.get("rise") == "bones" and risen < 1.0:   # 무덤 앞의 뼈 무더기. 일어설수록 흩어져 몸이 된다
		var pa := 1.0 - risen
		Pixel.draw_icon(self, "BONES", 40, -26, 4, Color(1, 1, 1, pa))
		Pixel.draw_icon(self, "DRAGON_SKULL", -6, -34 - risen * 30, 5, Color(1, 1, 1, pa))
		Pixel.draw_icon(self, "BONES", -52, -8, 4, Color(1, 1, 1, pa))
	elif def.get("rise") == "sand" and risen < 1.0:   # 모래 밑에 숨은 폭군: 모래가 봉긋하게 솟아 들썩인다
		var pa := 1.0 - risen
		var t := GameState.game_time * 3.0
		draw_set_transform(Vector2(0, -6), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, (70 + sin(t) * 6) * sc * 0.6, Color(0.55, 0.43, 0.24, 0.85 * pa))
		draw_circle(Vector2(-10, -10), (40 + sin(t * 1.3) * 4) * sc * 0.6, Color(0.66, 0.53, 0.31, 0.75 * pa))
		draw_set_transform(Vector2.ZERO)
	if opening: Pixel.draw_glow(self, 0, -40 * sc, 90 * sc, Color("#9fe3ff"), 0.35 + sin(GameState.game_time * 14) * 0.15)
	if charge and charge.windup > 0:   # 돌진 예고선
		draw_line(Vector2.ZERO, Vector2(cos(charge.angle), sin(charge.angle)) * 460, Color("#ff4d4d", 0.35 + sin(GameState.game_time * 30) * 0.15), 50, true)
	var tint = Status.tint(self)
	if tint: Pixel.draw_glow(self, 0, -60 * sc, 90 * sc, tint, 0.5)
	if phase2: Pixel.draw_glow(self, 0, -60 * sc, 150 * sc, Color("#ff5a1f"), 0.3 + sin(GameState.game_time * 8) * 0.1)
	if tell:   # 뿜기 직전: 몸 둘레가 빠르게 번쩍인다
		Pixel.draw_glow(self, 0, -60 * sc, 130 * sc, _el_color(), 0.35 + sin(GameState.game_time * 40) * 0.25)


## 회전 광선 (예고 중엔 가는 선)
func _draw_beam() -> void:
	if not beam: return
	var m := _mouth() - Vector2(x, y)
	var warm: bool = beam.warm > 0
	for pair in [[beam.angle, Color("#ff9a3c")], [beam.angle + PI, Color("#ffe27a")]]:
		var to: Vector2 = m + Vector2(cos(pair[0]), sin(pair[0])) * 700
		var strokes := [[4, 0.5]] if warm else [[46, 0.25], [20, 0.6], [7, 1.0]]
		for s in strokes:
			var c: Color = Color.WHITE if s[0] == 7 else pair[1]
			c.a = s[1] * (0.5 + sin(GameState.game_time * 30) * 0.3 if warm else 1.0)
			_fx.draw_line(m, to, c, s[0], true)


func _draw_body() -> void:
	if is_hidden: return
	var sc: float = def.scale
	var hover := sin(GameState.game_time * 2) * 8 if sheet.flying else 0.0
	var q := sin(squash * PI) if squash > 0 else 0.0
	# 무릎을 꿇은 이그나르: 날갯짓을 멈추고 몸을 낮춘다
	var kneel: bool = (lingering or vanishing > 0) and def.get("kneel", false)
	if kneel:
		hover = 0.0
		q = 0.35
	# draw_frame 은 제 변형을 쓰고 되돌리므로, 눌림(발 위 hover 를 축으로)은 몸 노드의 크기로 준다
	_body.scale = Vector2(1 + 0.1 * q, 1 - 0.1 * q)
	_body.position = Vector2(0, hover * (1 - _body.scale.y) + (14 * sc if kneel else 0.0) + (1.0 - risen) * 36 * sc)   # 일어서는 동안은 땅에서 솟는다
	SpriteSheet.draw_frame(_body, sheet, animator.frame(facing), 0, hover, sc)


func _draw_top() -> void:
	if is_hidden: return
	if def.get("spears") and risen >= 1.0 and vanishing <= 0: _draw_spears()
	if awake or Cutscene.on or def.get("rise"): return   # 장면 속에서는 잠든 표시를 하지 않는다 (먼저 말을 거는 이그나르). 뼈 무더기는 자지 않는다
	var sc: float = def.scale
	Fonts.draw_centered(_top, Fonts.bold(), "z z z", 0, -130 * sc + sin(GameState.game_time * 2) * 4, 12, Color.WHITE)


## 바실의 등에 박힌 오래된 창끝 셋 (def.spears 는 몸 크기 1일 때의 자리). 빈틈이면 빛난다
func _draw_spears() -> void:
	var sc: float = def.scale
	var t := GameState.game_time
	for s in def.spears:
		var px: float = float(s[0]) * sc
		var py: float = float(s[1]) * sc
		if opening: Pixel.draw_glow(_top, px, py - 8, 24, Color("#ffd38a"), 0.55 + sin(t * 12) * 0.2)
		var tip := PackedVector2Array([Vector2(px - 4, py), Vector2(px + 1, py - 16), Vector2(px + 4, py)])
		_top.draw_colored_polygon(tip, Color("#fff2c0") if opening else Color("#b8c0c8"))
		_top.draw_polyline(tip, Color("#2a2420"), 2.0)
