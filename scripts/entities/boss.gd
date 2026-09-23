class_name Boss
extends Node2D
## 2D판 entities/Boss.js. 보스. 공통 패턴(RING, AIMED, SPIRAL, CHARGE) 위에 보스마다 고유 기믹이 있다 (data/enemies 의 patterns).
##  모르가스: SUMMON(망령 소환), BONE_RAIN(얼음 기둥 비), 한 번 되살아난다(revive)
##  잘고라:   TWIN_BEAM(두 머리의 회전 광선), 조준탄이 불·번개를 번갈아 쏜다
##  글라시아: HOMING(따라오는 얼음 조각), ICE_FIELD(느려지는 빙판), BLIZZARD(눈보라에 밀려남)
##  바실:     BURROW(땅속으로 숨었다가 발밑에서 솟구침), QUAKE(번져 나가는 충격파 고리)
##  이그나르: METEOR_RAIN, FLAME_WALL(틈이 있는 불의 벽)
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
	b.sheet = DragonSprites.get_sheet(b.def.species, b.def.colors)
	b.animator = SpriteSheet.Animator.new(b.sheet)
	b.name = "Boss_" + boss_id
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


var rage: bool:
	get: return phase == def.phases.size() - 1 if def.get("phases") else (hp < def.hp * 0.4 or phase2)


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
			Hud.pop("%s, %s" % [def.name, def.title], "⚔️")
			Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 3, color = _el_color() })
			GameCamera.current.shake(10); Sfx.play("dieBig")
		animator.play_base("idle")
		animator.update(dt)
		return
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

	var moving := false
	if burrow: _update_burrow(dt)
	elif charge: moving = _update_charge(dt, speed_mult)
	elif beam: _update_beam(dt)
	else:
		# 적당한 거리를 두고 빙빙 돈다
		var a := atan2(player.y - y, player.x - x)
		var want := a if d > 300 else a + PI if d < 200 else a + PI / 2
		x += cos(want) * def.speed * speed_mult * dt
		y += sin(want) * def.speed * speed_mult * dt
		facing = Dragon.facing_from_vector(player.x - x, player.y - y, facing)
		moving = speed_mult > 0
		pattern_timer -= dt * (1 if speed_mult > 0 else 0)
		if pattern_timer <= 0: _start_pattern()
	if spiral: _update_spiral(dt)
	if blizzard: _update_blizzard(dt)

	if not is_hidden and d < 60 * def.scale: player.take_damage(def.contact * dt * (4 if charge and not charge.windup > 0 else 1))

	animator.play_base("move" if moving else "idle")
	animator.update(dt)
	var phase_name: String = (" · " + phases[phase].name) if phases else (" (분노)" if phase2 else "")
	Hud.current.set_boss_bar(def.name + phase_name, hp / def.hp)


func _el_color() -> Color:
	return Color(Data.get_module("elements").ELEMENTS[def.element].color)


func reset() -> void:
	awake = false
	x = home.x; y = home.y
	hp = def.hp
	is_hidden = false; phase2 = false
	phase = 0; stagger = 0.0   # 쓰러지면 처음부터 다시다
	charge = null; spiral = null; beam = null; burrow = null; blizzard = null
	Hud.current.set_boss_bar(null)


## 판이 바뀐다: 한마디 하고, 탄을 걷고, 잠깐 숨을 고른 뒤 새 패턴으로
func _enter_phase(i: int) -> void:
	var ph: Dictionary = def.phases[i]
	phase = i
	pattern_index = 0
	stagger = 1.4
	charge = null; spiral = null; beam = null; burrow = null; blizzard = null
	is_hidden = false
	for b in GameState.entities.bullets:
		if b.faction == "ENEMY": b.remove = true
	if i == def.phases.size() - 1: phase2 = bool(def.get("glow", false))
	Hud.pop("%s — %s" % [ph.name, ph.say] if ph.get("say") else ph.name, "⚔️")
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
	var o := { faction = "ENEMY", element = def.element, damage = damage, speed = ORB_SPEED, life = 3.2, scale = 0.8 }
	o.merge(opts, true)
	Projectile.add(Projectile.new(m.x, m.y, angle, o))


func _summon(types: Array) -> void:
	for t in types:
		var a := Util.rand_range(0, 6.28)
		var e := Enemy.make(x + cos(a) * 220, y + sin(a) * 160, t)
		e.aggro = true
		World.add_entity("enemies", e)
		Vfx.spawn_effect("MAGIC_CIRCLE", e.x, e.y, { size = 1, color = _el_color() })
	Sfx.play("summon")


func _start_pattern() -> void:
	var patterns: Array = def.phases[phase].patterns if def.get("phases") else def.patterns
	var pat: String = patterns[pattern_index % patterns.size()]
	pattern_index += 1
	var r := rage
	pattern_timer = 1.9 if r else 2.9
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
		"SUMMON":
			_summon(["GHOST", "GHOST", "BAT", "BAT"] if r else ["GHOST", "BAT", "BAT"])
		"BONE_RAIN":
			for i in (9 if r else 6):
				Hazard.add(player.x + Util.rand_range(-260, 260), player.y + Util.rand_range(-200, 200), { r = 80, delay = 0.8 + i * 0.12, damage = 16, color = "#bfe9ff",
					effect = "ICE_SPIKE", effectSize = 1.5, sound = null if i % 3 else "freeze", status = { type = "SLOW", duration = 1.5 } })
		"TWIN_BEAM":
			beam = { warm = 0.9, time = 4.0 if r else 3.0, angle = aim + 0.9, spin = (-1 if randf() < 0.5 else 1) * (1.1 if r else 0.85) }
			Sfx.play("warn")
		"HOMING":
			for i in (7 if r else 5): _orb(aim + (i - 2) * 0.5, 10, { homing = 1.6, speed = 230, life = 4.5 })
			Sfx.play("ice")
		"ICE_FIELD":
			for i in (5 if r else 3):
				Hazard.add(player.x + Util.rand_range(-220, 220), player.y + Util.rand_range(-160, 160), { r = 130, delay = 0.7, linger = 6, damage = 8, dps = 5, slow = true, color = "#7fd4ff", effect = "ICE_SPIKE", effectSize = 2, sound = "freeze" })
		"BLIZZARD":
			blizzard = { time = 5.0 if r else 3.5, angle = Util.rand_range(0, 6.28), timer = 0.0 }
			Hud.pop("눈보라가 몰아칩니다! 바람을 거슬러 버티세요.", "🌨️")
			Sfx.play("gust")
		"BURROW":
			burrow = { time = 1.6 if r else 2.2, erupting = false }
			is_hidden = true
			Vfx.spawn_effect("DUST", x, y, { size = 3, color = "#c9a24a" })
			Sfx.play("gust")
		"QUAKE":
			for i in (4 if r else 3):
				Hazard.add(x, y, { r = 170 + i * 150, inner = 70 + i * 150, delay = 0.7 + i * 0.45, damage = 20, color = "#d8a24a", sound = "boom", shake = 8 })
			Sfx.play("warn")
		"METEOR_RAIN":
			for i in (11 if r else 7):
				var px: float = player.x + Util.rand_range(-320, 320)
				var py: float = player.y + Util.rand_range(-240, 240)
				Hazard.add(px, py, { r = 110, delay = 0.9 + i * 0.16, linger = 2, damage = 24, dps = 8, color = "#ff5a1f", effect = "FIRE_HIT", effectSize = 2.2, sound = "boom", shake = 6 })
			Sfx.play("warn")
		"FLAME_WALL":
			# 플레이어를 가로지르는 불의 벽. 한 군데 틈이 있다
			var across := aim + PI / 2
			var gap := floori(Util.rand_range(2, 9))
			for i in 11:
				if i == gap or i == gap + 1: continue
				var k := (i - 5) * 95
				Hazard.add(player.x + cos(across) * k + cos(aim) * 40, player.y + sin(across) * k + sin(aim) * 40,
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
		else: charge = null
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
		if Vector2(player.x - (m.x + cos(a) * t), player.y - 30 - (m.y + sin(a) * t)).length() < 30: player.take_damage(45 * dt)
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
		Hazard.add(x, y, { r = 170, delay = 0.75, damage = 34, color = "#d8a24a", effect = "DUST", effectSize = 3.5, sound = "boom", shake = 14 })
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
		Projectile.add(Projectile.new(sx, sy, z.angle, { faction = "ENEMY", element = "ICE", damage = 9, speed = 420, life = 2.8, scale = 0.7 }))
	if z.time <= 0: blizzard = null


func take_damage(dmg: float, silent := false, _from = null) -> void:
	if not awake or is_hidden: return
	if opening: dmg *= 2   # 간발로 만든 빈틈
	hp -= dmg
	if not silent:
		hit_flash = 1.0; squash = 1.0
	if hp > 0 or remove: return
	if def.get("revive") and not revived:      # 모르가스: 죽지 못한 용
		revived = true
		hp = def.hp * 0.45
		Hud.pop("%s의 뼈가 다시 맞춰집니다…!" % def.name, "💀")
		Vfx.spawn_effect("MAGIC_CIRCLE", x, y, { size = 3, color = "#bfe9ff" })
		_summon(["GHOST", "GHOST"])
		GameCamera.current.shake(10)
		return
	die()


func die() -> void:
	remove = true
	Hud.current.set_boss_bar(null)
	GameState.bossesDefeated[id] = true
	for i in 6: Vfx.spawn_effect("SMOKE", x + Util.rand_range(-90, 90), y - Util.rand_range(0, 140), { size = 1.6 })
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 4, color = "#fff2b0" })
	Vfx.spawn_effect("RING", x, y - 60, { size = 2.6 })
	Vfx.spawn_effect("STAR", x, y - 60, { size = 3 })
	GameCamera.current.shake(18); Sfx.play("dieBig")
	for i in 5: World.add_entity("items", Item.make(x + Util.rand_range(-80, 80), y + Util.rand_range(-50, 50), "MEAT"))
	World.add_entity("items", Item.make(x, y + 40, "GOLD", 80 + roundi(def.xp / 10.0)))
	Hud.pop("%s 처치!" % def.name, "🏆")
	var player = GameState.player
	if def.get("unlock"): player.unlock_element(def.unlock)
	var skill = Data.get_module("skills").BOSS_SKILLS.get(id)
	if skill: Skills.learn(skill)
	var relic = Relics.boss_relic(id)
	if relic: Relics.grant(relic, x, y)
	player.gain_xp(def.xp)
	# 셋 중 하나 고르는 유물(offerRelics)은 대화창을 옮길 때
	Quests.notify("boss", id)


# ---------- 그리기 ----------

func _process(_dt: float) -> void:
	_body.material.set_shader_parameter("m", Basis.from_scale(Vector3(2.2, 2.2, 2.2)) if hit_flash > 0 else Basis.IDENTITY)   # 맞으면 brightness(2.2)
	_body.modulate.a = 1.0 if awake else 0.75
	queue_redraw(); _fx.queue_redraw(); _body.queue_redraw(); _top.queue_redraw()


func _draw() -> void:
	if is_hidden: return
	var sc: float = def.scale
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 40 * sc, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if opening: Pixel.draw_glow(self, 0, -40 * sc, 90 * sc, Color("#9fe3ff"), 0.35 + sin(GameState.game_time * 14) * 0.15)
	if charge and charge.windup > 0:   # 돌진 예고선
		draw_line(Vector2.ZERO, Vector2(cos(charge.angle), sin(charge.angle)) * 460, Color("#ff4d4d", 0.35 + sin(GameState.game_time * 30) * 0.15), 50, true)
	var tint = Status.tint(self)
	if tint: Pixel.draw_glow(self, 0, -60 * sc, 90 * sc, tint, 0.5)
	if phase2: Pixel.draw_glow(self, 0, -60 * sc, 150 * sc, Color("#ff5a1f"), 0.3 + sin(GameState.game_time * 8) * 0.1)


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
	# draw_frame 은 제 변형을 쓰고 되돌리므로, 눌림(발 위 hover 를 축으로)은 몸 노드의 크기로 준다
	_body.scale = Vector2(1 + 0.1 * q, 1 - 0.1 * q)
	_body.position = Vector2(0, hover * (1 - _body.scale.y))
	SpriteSheet.draw_frame(_body, sheet, animator.frame(facing), 0, hover, sc)


func _draw_top() -> void:
	if is_hidden or awake: return
	var sc: float = def.scale
	Fonts.draw_centered(_top, Fonts.bold(), "z z z", 0, -130 * sc + sin(GameState.game_time * 2) * 4, 12, Color.WHITE)
