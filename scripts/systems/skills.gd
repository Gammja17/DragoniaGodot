class_name Skills
## 2D판 systems/skills.js. 플레이어 스킬의 실행부. 표는 data/skills.json.
## 배운 스킬은 player.skills, 장착은 player.slots = { Q, F, R }.
## 강화 단수(1~3)는 Growth 가 들고 있고, 여기서는 위력 배수 m 으로 받아 쓴다.
## 시간이 걸리는 스킬(폭풍, 방사, 회복, 급강하…)은 player.channels 에 넣어 매 프레임 진행하며, 자기 m 을 채널에 함께 실어 둔다.


static func defs() -> Dictionary:
	return Data.get_module("skills").SKILLS


## 여러 개를 시간차로 뿌린다 (2D판 setTimeout. 실제 시간으로 흐른다)
static func later(ms: float, fn: Callable) -> void:
	(Engine.get_main_loop() as SceneTree).create_timer(ms / 1000.0).timeout.connect(func():
		if GameState.gameActive: fn.call())


static func foes() -> Array:
	var E: Dictionary = GameState.entities
	return (E.enemies + E.humans + E.bosses).filter(func(e): return e.get("awake") != false)


static func power(p, element, m := 1.0) -> float:
	return p.damage_mult * m * (Weather.damage_mult(element) if element else 1.0)


static func hurt(e, dmg: float, color := "#fff") -> void:
	e.take_damage(dmg)
	Vfx.spawn_text(e.x, e.y - 50, "%d" % roundi(dmg), color, 16)


static func _push_away(p, e, d: float, amount: float) -> void:
	if e.status_immune: return
	e.x += ((e.x - p.x) / (d if d else 1.0)) * amount
	e.y += ((e.y - p.y) / (d if d else 1.0)) * amount


static func _angle_off(p, e, angle: float) -> float:
	var da: float = atan2(e.y - p.y, e.x - p.x) - angle
	return absf(atan2(sin(da), cos(da)))


# ---------- 강화 단수 ----------
## 배우지 않았으면 0, 배웠으면 1 이상
static func rank(id: String) -> int:
	if not GameState.player or not GameState.player.skills.has(id): return 0
	return int(GameState.growth.ranks.get(id, 1))


## 강화 단수와 성장 트리를 합친 스킬 위력 배수
static func cast_mult(id: String) -> float:
	return Data.get_module("skills").SKILL_RANKS[rank(id) - 1].power * (1 + Growth.stat("skill"))


## 강화 단수와 성장 트리를 합친 실제 대기 시간 (끝은 대장간 '숨길 트기')
static func cooldown(id: String) -> float:
	var cd_mult: float = Data.get_module("skills").SKILL_RANKS[rank(id) - 1].cd * (1 - Growth.stat("cdr"))
	return defs()[id].cooldown * cd_mult * (0.75 if Relics.has("GLACIA_TEAR") else 1.0) * (1 - minf(0.25, 0.05 * GameState.upgrades.get("cd", 0)))


static func learn(id: String, silent := false) -> bool:
	var p = GameState.player
	if not p or p.skills.has(id): return false
	p.skills.append(id)
	var free = null
	for s in Data.get_module("skills").SKILL_SLOTS:
		if not p.slots[s]:
			free = s
			break
	if free: p.slots[free] = id   # 빈 칸이 있으면 바로 장착
	if not silent:
		Hud.pop("새 스킬 [%s] 습득!" % defs()[id].name + (" ([%s] 칸에 끼웠다)" % free if free else " ([K] 스킬 나무에서 끼울 수 있다)"), "📖")
		Sfx.play("quest")
	check_unlocks(true)   # 이 스킬이 다른 각성 스킬의 조건이었을 수도 있다
	return true


# ---------- 스스로 깨우치는 스킬 · 각성 ----------
static func _self_cond(cond: String) -> bool:
	match cond:
		"kills25":
			var n := 0
			for k in GameState.stats.kills: n += GameState.stats.kills[k]
			return n >= 25
		"brink3": return GameState.stats.get("brinks", 0) >= 3
	return false


## 조건이 찬 SELF / AWAKEN 스킬을 자동으로 익힌다. 1초에 한 번 부른다
static func check_unlocks(silent := false) -> void:
	if not GameState.player: return
	for id in defs():
		if GameState.player.skills.has(id): continue
		var s: Dictionary = defs()[id].source
		if s.type == "SELF" and _self_cond(s.cond): learn(id)
		elif s.type == "AWAKEN" and s.need.all(func(n): return rank(n[0]) >= n[1]):
			if not silent: Sfx.play("evolve")
			learn(id)


## slot: 'Q' | 'F' | 'R'
static func use_slot(p, slot: String) -> void:
	var id = p.slots[slot]
	if not id:
		Hud.pop("[%s] 칸이 비어 있습니다. [K] 스킬 나무에서 끼우세요." % slot, "📖")
		return
	if p.cooldowns.get(id, 0) > 0 or p.channels.any(func(c): return c.get("lock")): return
	p.cooldowns[id] = cooldown(id); p.cd_max[id] = p.cooldowns[id]   # 스킬은 대기 시간만 쓴다 (허기는 안 든다)
	if Relics.has("ECHO_SHELL") and randf() < 0.25:
		p.cooldowns[id] = 0.4; Hud.pop("메아리! 스킬이 바로 돌아왔다.", "🐚")
	p.animator.play("attack")
	cast(id, p, cast_mult(id))


static func cast(id: String, p, m: float) -> void:
	var cam := GameCamera.current
	match id:
		"POUNCE":
			var t: Vector2 = p.aim_point(230)
			p.channels.append({ id = "POUNCE", m = m, time = 0.3, total = 0.3, lock = true, sx = p.x, sy = p.y, tx = t.x, ty = t.y, tick = 0.0 })
			p.invuln = 0.3
			Vfx.spawn_effect("PUFF", p.x, p.y - 6)
			Sfx.play("dash")
		"TAIL_SWIPE":
			for e in foes():
				var d := Util.dist(p, e)
				if d > 210: continue
				hurt(e, 34 * power(p, null, m))
				_push_away(p, e, d, 120)
			for i in 3:
				later(i * 40, func(): Vfx.spawn_effect("ARC", p.x, p.y - 30, { size = 2.0, angle = i * 2.1 + p.angle, color = "#ffd07a" if i else "#ffffff" }))
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 1.3, color = "#ffe9a0" })
			for e in foes():
				if Util.dist(p, e) <= 210:
					Vfx.spawn_effect("EMBER", e.x, e.y - 24, { size = 1.1, color = "#ffd07a" }); Particles.burst(e.x, e.y - 20, "#ffe9a0", 0.8, 6)
			Feedback.hit_stop(0.05); cam.shake(6); Sfx.play("slash")
			if Relics.has("TAIL_TWIN") and not p.tail_twin:   # 유물 '두 번 치는 꼬리'
				p.tail_twin = true
				(Engine.get_main_loop() as SceneTree).create_timer(0.26).timeout.connect(func():
					p.tail_twin = false
					if GameState.player == p: cast("TAIL_SWIPE", p, m * 0.6))
		"ROAR":
			for e in foes():
				var d := Util.dist(p, e)
				if d > 340: continue
				hurt(e, 15 * power(p, null, m))
				Status.apply(e, "STUN", 1.8)
				if Relics.has("ROAR_FLAME"):   # 유물 '불타는 목청'
					Status.apply(e, "BURN", 4); Vfx.spawn_effect("FLAMES", e.x, e.y, { size = 0.9 })
				_push_away(p, e, d, 90)
			p.fury = 6.0
			Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 0.83, color = "#ffb347" })
			for i in 3:
				later(i * 110, func():
					Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 1.6 + i * 0.7, color = "#fff2a8" })
					Vfx.spawn_effect("RING", p.x, p.y - 40, { size = 2 + i, color = "#ffd07a" }))
			Feedback.flash(0.25, Color8(255, 200, 120))
			Feedback.hit_stop(0.08); cam.shake(10); Sfx.play("roar")
		"METEOR":
			var t: Vector2 = p.aim_point(420)
			Hazard.add(t.x, t.y, { faction = "ALLY", r = 185, delay = 0.6, linger = 2.5, damage = 48 * power(p, "FIRE", m), dps = 6 * power(p, "FIRE", m),
				color = "#ff6a2a", effect = "FIRE_HIT", effectSize = 2.8, sound = "boom", shake = 12, status = { type = "BURN", duration = 4 } })
			Vfx.spawn_effect("RUNE", t.x, t.y, { size = 1.7, color = "#ff9a3c" })
			Vfx.spawn_effect("FALLING_STAR", t.x, t.y - 40, { size = 1.6, color = "#ffb347", angle = 0.6 })
			later(560, func():
				Vfx.spawn_effect("BLOOM", t.x, t.y - 20, { size = 1.32, color = "#ff7a2a" })
				for i in 8:
					var a := (i / 8.0) * TAU
					Vfx.spawn_effect("EMBER", t.x + cos(a) * 70, t.y - 10 + sin(a) * 45, { size = 1.2, color = "#ff9a3c" }))
			if Relics.has("METEOR_RAIN"):   # 유물 '별 부스러기'
				for i in 3:
					var a := (i / 3.0) * TAU + 0.5
					Hazard.add(t.x + cos(a) * 190, t.y + sin(a) * 190 * 0.7, { faction = "ALLY", r = 95, delay = 0.9 + i * 0.15, linger = 1, damage = 22 * power(p, "FIRE", m), color = "#ff8a4a", effect = "FIRE_HIT", effectSize = 1.6, sound = "boom", shake = 4, status = { type = "BURN", duration = 3 } })
			later(600, func(): Vfx.spawn_effect("SCORCH", t.x, t.y, { size = 1.3, color = "#1a0d08" }))
			Sfx.play("flame")
		"WING_GUST":
			var angle: float = p.aim_angle().angle
			for e in foes():
				var d := Util.dist(p, e)
				if d > 380 or _angle_off(p, e, angle) > 0.9: continue
				hurt(e, 12 * power(p, null, m) * (3 if Relics.has("GUST_BLADE") else 1))
				if not e.status_immune:
					e.x += cos(angle) * 230; e.y += sin(angle) * 230
				Status.apply(e, "SLOW", 2)
				if Relics.has("GUST_BLADE"):   # 유물 '칼바람 깃'
					Status.apply(e, "STUN", 1.2); Vfx.spawn_effect("HIT_SPARK", e.x, e.y - 20, { size = 1.4, color = "#dff4ff" })
			for b in GameState.entities.bullets:
				if b.faction == "ENEMY" and Util.dist(p, b) < 340:
					b.remove = true; Particles.burst(b.x, b.y, "#cfe9ff", 0.4, 2)
			for i in range(1, 4): Vfx.spawn_effect("WHIRL", p.x + cos(angle) * i * 90, p.y - 30 + sin(angle) * i * 90, { size = 0.7 + i * 0.35, angle = angle, color = "#dff4ff" })
			for i in 5:
				var off := (i - 2) * 0.22
				Vfx.spawn_effect("STREAK", p.x + cos(angle + off) * 120, p.y - 30 + sin(angle + off) * 120, { size = 1.6, angle = angle + off, color = "#ffffff" })
			Sfx.play("gust")
		"HEAL":
			p.channels.append({ id = "HEAL", m = m, time = 4.0, tick = 0.0 })
			for a in Combat.allies() + GameState.entities.babies:
				if Util.dist(p, a) < 400 and a.max_hp: a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.35 * m)
			Vfx.spawn_effect("AURA", p.x, p.y - 40, { size = 2, color = "#8dffb0" })
			Vfx.spawn_effect("SIGIL", p.x, p.y, { size = 1.6, color = "#8dffb0" })
			for i in 10: later(i * 120, func(): Vfx.spawn_effect("SPARKLE", p.x + Util.rand_range(-60, 60), p.y - Util.rand_range(0, 60), { size = 1, color = "#c8ffd8" }))
			Sfx.play("heal")
		"SHED":
			p.slow_timer = 0.0
			p.invuln = maxf(p.invuln, 1.2)
			p.hp = minf(p.max_hp, p.hp + p.max_hp * 0.2)
			for e in foes():
				var d := Util.dist(p, e)
				if d > 260 or e.status_immune: continue
				_push_away(p, e, d, 150)
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 2, color = "#cfe9ff" })
			Vfx.spawn_effect("AURA", p.x, p.y - 40, { size = 1.8, color = "#dff4ff" })
			Particles.burst(p.x, p.y - 40, "#dff4ff", 0.9, 24)
			Sfx.play("heal")
		"FLAME_BREATH":
			p.channels.append({ id = "FLAME_BREATH", m = m, time = 3.0 if Relics.has("LONG_BREATH") else 1.8, tick = 0.0 })   # 유물 '긴 숨'
		"IRON_SCALE":
			p.guard = 5.0
			Vfx.spawn_effect("HALO", p.x, p.y - 40, { size = 1.6, color = "#dfe8f4" })
			Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 0.66, color = "#cfd8e6" })
			Sfx.play("guard")
		"RALLY":
			GameState.rally = 10.0
			for a in Combat.allies() + GameState.entities.babies:
				if a.max_hp: a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.4 * m)
				if a.down_timer > 0: a.down_timer = 0.1   # 쓰러진 용도 일으켜 세운다
				Vfx.spawn_effect("AURA", a.x, a.y - 30, { size = 1.2, color = "#ffd84a" })
				if a.has_method("say"): a.say(["간다!", "우오오!", "같이 싸우자!"].pick_random())
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 3, color = "#ffd84a" })
			cam.shake(6); Sfx.play("roar")
		# ---- 맡겨 받은 숨결의 기술 ----
		"TIDE":
			var angle: float = p.aim_angle().angle
			for e in foes():
				var d := Util.dist(p, e)
				if d > 420 or _angle_off(p, e, angle) > 0.8: continue
				hurt(e, 20 * power(p, "WATER", m), "#7fc4ff")
				Status.apply(e, "WET", 6)
				if not e.status_immune:
					e.x += cos(angle) * 260; e.y += sin(angle) * 260
			for b in GameState.entities.bullets:
				if b.faction == "ENEMY" and Util.dist(p, b) < 360: b.remove = true   # 날아오던 것도 같이 쓸려 간다
			for i in range(1, 5): Vfx.spawn_effect("WATER_SPLASH", p.x + cos(angle) * i * 95, p.y + sin(angle) * i * 95, { size = 0.8 + i * 0.3 })
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 1.8, color = "#4aa3ff" })
			cam.shake(7); Sfx.play("gust")
		"UPHEAVAL":
			for i in 8:
				var a := (i / 8.0) * TAU
				Hazard.add(p.x + cos(a) * 170, p.y + sin(a) * 130, { faction = "ALLY", r = 95, delay = 0.25 + (i % 2) * 0.12, linger = 0,
					damage = 30 * power(p, "EARTH", m), color = "#c9a06a", effect = "EARTH_RISE", effectSize = 1.6, sound = "boom" if i == 0 else null, shake = 10 if i == 0 else 0, status = { type = "STUN", duration = 1.6 } })
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 2.4, color = "#c9a06a" })
		"BRAMBLE":
			var t: Vector2 = p.aim_point(380)
			Hazard.add(t.x, t.y, { faction = "ALLY", r = 175, delay = 0.35, linger = 5, damage = 10 * power(p, "GRASS", m), dps = 7 * power(p, "GRASS", m),
				color = "#6fcf5a", effect = "GRASS_HIT", effectSize = 2.2, sound = "zap", status = { type = "POISON", duration = 5 } })
			Vfx.spawn_effect("MAGIC_CIRCLE", t.x, t.y, { size = 1.5, color = "#6fcf5a" })
			for i in 7:
				var a := (i / 7.0) * TAU
				Vfx.spawn_effect("ROOT", t.x + cos(a) * 110, t.y + sin(a) * 85, { size = 1 + (i % 2) * 0.3 })
			for e in foes():
				if Vector2(e.x - t.x, e.y - t.y).length() < 175: Status.apply(e, "SLOW", 3)
		"FROST_NOVA":
			for e in foes():
				if Util.dist(p, e) > 340: continue
				hurt(e, 22 * power(p, "ICE", m), "#aee6ff")
				Status.apply(e, "STUN", 2.5)
				Status.apply(e, "SLOW", 5)
				Vfx.spawn_effect("ICE_SPIKE", e.x, e.y + 10, { size = 1.2 })
			Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 2.6, color = "#aee6ff" })
			Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 1.1, color = "#aee6ff" })
			for i in 10:
				var a := (i / 10.0) * TAU
				later(i * 25, func(): Vfx.spawn_effect("ICE_SPIKE", p.x + cos(a) * 150, p.y + sin(a) * 105, { size = 1.1 }))
			Particles.burst(p.x, p.y - 40, "#aee6ff", 1, 40)
			Feedback.hit_stop(0.06); Sfx.play("freeze")
		"STORM":
			p.channels.append({ id = "STORM", m = m, time = 3.0, tick = 0.0 })
			Vfx.spawn_effect("SIGIL", p.x, p.y, { size = 2.2, color = "#ffe27a" })
			Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 1.1, color = "#ffe27a" })
			Sfx.play("thunder")
		"ICE_SPIKES":
			var angle: float = p.aim_angle().angle
			for i in range(1, 7):
				Hazard.add(p.x + cos(angle) * i * 85, p.y + sin(angle) * i * 85, { faction = "ALLY", r = 70, delay = 0.1 + i * 0.08, linger = 0,
					damage = 24 * power(p, "ICE", m), color = "#7fd4ff", effect = "ICE_SPIKE", effectSize = 1.3, sound = "ice" if i % 2 else null, status = { type = "STUN", duration = 1.4 } })
		"AURORA":
			# 불 → 얼음 → 번개가 번갈아 깔리는 긴 빛의 띠
			var angle: float = p.aim_angle().angle
			var bands := [
				{ color = "#ff6a2a", effect = "FIRE_HIT", element = "FIRE", status = { type = "BURN", duration = 4 }, sound = "flame" },
				{ color = "#7fd4ff", effect = "ICE_SPIKE", element = "ICE", status = { type = "SLOW", duration = 4 }, sound = "ice" },
				{ color = "#ffe27a", effect = "THUNDER_HIT", element = "THUNDER", status = { type = "STUN", duration = 1.2 }, sound = "zap" },
			]
			for i in range(1, 9):
				var b: Dictionary = bands[i % 3]
				Hazard.add(p.x + cos(angle) * i * 95, p.y + sin(angle) * i * 95, { faction = "ALLY", r = 100, delay = 0.08 * i, linger = 1.6,
					damage = 30 * power(p, b.element, m), dps = 8 * power(p, b.element, m),
					color = b.color, effect = b.effect, effectSize = 1.8, sound = b.sound if i % 3 == 0 else null, status = b.status })
			Vfx.spawn_effect("RUNE", p.x, p.y, { size = 2.2, color = "#c77dff" })
			Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 1.43, color = "#e0b0ff" })
			Feedback.flash(0.2, Color8(200, 150, 255))
			cam.shake(8); Sfx.play("evolve")
		"DIVE":
			var t: Vector2 = p.aim_point(420)
			p.channels.append({ id = "DIVE", m = m, time = 0.55, total = 0.55, sx = p.x, sy = p.y, tx = t.x, ty = t.y, lock = true, tick = 0.0 })
			p.invuln = 0.7
			Vfx.spawn_effect("DUST", p.x, p.y, { size = 1.5, color = "#d8c8a8" })
			Sfx.play("gust")
		"TEMPEST":
			p.channels.append({ id = "TEMPEST", m = m, time = 2.0, tick = 0.0, spin = 0.0 })
			Vfx.spawn_effect("WHIRL", p.x, p.y - 30, { size = 2.4, color = "#dff4ff" })
			cam.shake(4); Sfx.play("gust")
		"BLINK":
			var angle: float = p.aim_angle().angle
			var sx: float = p.x
			var sy: float = p.y - 30
			var length := 380.0
			for e in foes():     # 지나가는 선분 근처의 적
				var t := clampf((e.x - p.x) * cos(angle) + (e.y - p.y) * sin(angle), 0, length)
				if Vector2(e.x - (p.x + cos(angle) * t), e.y - (p.y + sin(angle) * t)).length() < 70:
					hurt(e, 30 * power(p, "THUNDER", m), "#ffe27a")
					Vfx.spawn_effect("THUNDER_HIT", e.x, e.y - 16)
			p.x += cos(angle) * length; p.y += sin(angle) * length
			p.invuln = 0.35
			Vfx.spawn_bolt(sx, sy, p.x, p.y - 30)
			Vfx.spawn_effect("THUNDER_BALL", sx, sy); Vfx.spawn_effect("THUNDER_BALL", p.x, p.y - 30)
			Sfx.play("thunder")


## 시간이 걸리는 스킬의 진행. Dragon 이 매 프레임 부른다
static func update_channels(p, dt: float) -> void:
	var cam := GameCamera.current
	for c in p.channels:
		var m: float = c.get("m", 1.0)
		c.time -= dt
		c.tick -= dt
		match c.id:
			"HEAL":
				p.hp = minf(p.max_hp, p.hp + p.max_hp * 0.35 * m / 4 * dt)
				if c.tick <= 0:
					c.tick = 0.4; Vfx.spawn_effect("HEART", p.x + Util.rand_range(-30, 30), p.y - 60, { color = "#8dffb0" })
			"STORM":
				if c.tick <= 0:
					c.tick = 0.18
					var near := foes().filter(func(e): return Util.dist(p, e) < 480)
					if not near.is_empty():
						var e = near.pick_random()
						Vfx.spawn_bolt(e.x + Util.rand_range(-40, 40), e.y - 420, e.x, e.y - 16)
						Vfx.spawn_effect("SPARK", e.x, e.y - 16, { size = 1.2, color = "#fff2a8", angle = Util.rand_range(0, 6) })
						hurt(e, 12 * power(p, "THUNDER", m), "#ffe27a")
						Sfx.play("zap")
			"FLAME_BREATH":
				if c.tick <= 0:
					c.tick = 0.12
					var angle: float = p.angle
					for e in foes():
						var d := Util.dist(p, e)
						if d > 330 or _angle_off(p, e, angle) > (0.8 if Relics.has("LONG_BREATH") else 0.55): continue
						e.take_damage(7 * power(p, "FIRE", m))
						Status.apply(e, "BURN", 3)
					var r := Util.rand_range(80, 300)
					var a := angle + Util.rand_range(-0.45, 0.45)
					Vfx.spawn_effect("FLAMES", p.x + cos(a) * r, p.y - 10 + sin(a) * r, { size = 0.9 + r / 300 })
					Vfx.spawn_effect("EMBER", p.x + cos(a) * r, p.y - 30 + sin(a) * r, { size = 0.9, color = "#ff9a3c" })
					Vfx.spawn_effect("MUZZLE", p.x + cos(angle) * 50, p.y - 40 + sin(angle) * 50, { angle = angle + PI / 2, size = 1.4, color = "#ff9a3c" })
					Sfx.play("flame")
			"TEMPEST":
				# 회전하며 주변을 계속 베고 날아오는 탄을 지운다
				if c.tick <= 0:
					c.tick = 0.16
					c.spin += PI * 0.6
					for e in foes():
						if Util.dist(p, e) < 230: hurt(e, 11 * power(p, null, m))
					for b in GameState.entities.bullets:
						if b.faction == "ENEMY" and Util.dist(p, b) < 230:
							b.remove = true; Particles.burst(b.x, b.y, "#cfe9ff", 0.4, 2)
					Vfx.spawn_effect("SLASH", p.x, p.y - 30, { size = 2.6, angle = c.spin, color = "#dff4ff" })
					Sfx.play("slash")
				if c.time <= 0:
					Vfx.spawn_effect("GUST", p.x, p.y - 30, { size = 2.2, color = "#dff4ff" }); cam.shake(5)
			"DIVE", "POUNCE":
				var k: float = 1 - maxf(0, c.time) / c.total
				p.x = c.sx + (c.tx - c.sx) * k; p.y = c.sy + (c.ty - c.sy) * k
				var big: bool = c.id == "DIVE"
				p.dive_height = sin(k * PI) * (160 if big else 45)   # 그릴 때 이만큼 떠오른다
				if c.time <= 0:
					p.dive_height = 0.0
					Vfx.spawn_effect("BLOOM" if big else "DUST", p.x, p.y - (20 if big else 0), { size = 2.2 if big else 1.4, color = "#ffe9a0" if big else "#d8c8a8" })
					for i in 6:
						var a := (i / 6.0) * TAU
						Vfx.spawn_effect("STREAK", p.x + cos(a) * 60, p.y + sin(a) * 40, { size = 1.4 if big else 0.9, angle = a, color = "#fff2c8" })
					Feedback.hit_stop(0.08 if big else 0.04); cam.shake(12 if big else 5); Sfx.play("boom" if big else "thud")
					if not big and Relics.has("POUNCE_QUAKE"):   # 유물 '무거운 착지'
						for e in foes():
							if Util.dist(p, e) < 200: Status.apply(e, "STUN", 1.3)
						Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 1.8, color = "#c9a06a" }); cam.shake(6)
					for e in foes():
						if Util.dist(p, e) < (210 if big else 130):
							hurt(e, (42 if big else 28) * power(p, null, m))
							Status.apply(e, "STUN", 1.2 if big else 0.6)
					if big:
						Vfx.spawn_effect("SHOCKWAVE", p.x, p.y, { size = 2.4, color = "#ffe9c4" })
						Vfx.spawn_effect("DUST", p.x, p.y, { size = 2.2, color = "#d8c8a8" })
						cam.shake(12); Sfx.play("boom")
					else:
						Vfx.spawn_effect("SLASH", p.x, p.y - 30, { size = 2.2, color = "#ffffff" })
						cam.shake(4); Sfx.play("slash")
	p.channels = p.channels.filter(func(c): return c.time > 0)
