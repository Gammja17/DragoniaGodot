class_name Flow
## 2D판 systems/flow.js. 싸움의 흐름. 세 가지가 서로 물려 돈다:
##
##   기세      맞히고 쓰러뜨릴수록 차오르고, 맞으면 반이 날아간다. 찰수록 숨결이 세진다
##   간발      날아오는 것을 아슬아슬하게 대시로 피하면 세상이 잠깐 느려지고 기세가 크게 찬다
##   물어뜯기  숨이 붙어 있는 적을 대시로 뚫고 지나가면 끝장을 내고 체력을 조금 되찾는다
##
## GameState.flow = { m: 기세 0~100, idle, slow: 느려진 세상의 남은 시간, edge: 간발 뒤 강화 시간, stacks/stackT: 굶주린 불꽃 }

const TIERS := [30, 60, 100]
const TIER_NAMES := ["", "기세", "기세 · 거셈", "기세 · 절정"]
const TIER_DMG := [1.0, 1.1, 1.2, 1.35]
const TIER_COLORS := ["#8a7a5a", "#ffd07a", "#ff9a3c", "#ff5a3c"]
const EDGE_RANGE := 78        # 이만큼 가까이 스친 것을 피했으면 간발
const BITE_RANGE := 62


static func F() -> Dictionary:
	if GameState.get("flow") == null or GameState.flow.is_empty():
		GameState.flow = { m = 0.0, idle = 0.0, slow = 0.0, edge = 0.0, stacks = 0, stackT = 0.0 }
	return GameState.flow


## 처음 한 번만 알려 준다 (GameState.stats 는 저장된다)
static func _once(key: String, text: String, icon: String) -> void:
	if not GameState.stats.has("seen"): GameState.stats.seen = {}
	if GameState.stats.seen.get(key): return
	GameState.stats.seen[key] = true
	Hud.pop(text, icon)


static func momentum() -> float: return F().m

static func tier() -> int:
	var m: float = F().m
	return 3 if m >= TIERS[2] else 2 if m >= TIERS[1] else 1 if m >= TIERS[0] else 0


## 숨결·기술 피해에 곱해진다
static func tier_name() -> String: return TIER_NAMES[tier()]
static func tier_color() -> Color: return Color(TIER_COLORS[tier()])


static func damage_mult() -> float:
	return TIER_DMG[tier()] * (1.5 if F().edge > 0 else 1.0)

## 연사 간격에 곱해진다. 유물 '굶주린 불꽃': 쓰러뜨릴 때마다 잠깐 빨라진다
static func rate_mult() -> float: return 1 - 0.1 * F().stacks

## 절정에서는 기술이 더 빨리 돌아온다
static func cooldown_rate() -> float: return 1.3 if tier() == 3 else 1.0

## 세상이 흐르는 빠르기. 간발 직후에는 나만 빼고 다 느려진다
static func world_time_scale() -> float: return 0.3 if F().slow > 0 else 1.0


static func add_momentum(n: float) -> void:
	var f := F()
	var before := tier()
	f.m = minf(100, f.m + n * (1.3 if Relics.resonates("flame") else 1.0))
	f.idle = 0.0
	var now := tier()
	var p = GameState.player
	if now > before and p:
		_once("flowTier", "기세: 맞지 않고 계속 맞히면 게이지가 차고 숨결이 세진다. 아슬아슬하게 대시로 피하면(간발) 한꺼번에 많이 찬다.", "🔥")
		Vfx.spawn_effect("AURA", p.x, p.y - 40, { size = 0.8 + now * 0.3, color = TIER_COLORS[now] })
		if now == 3:
			Vfx.spawn_text(p.x, p.y - 120 * p.stage.scale, "절정!", TIER_COLORS[now], 18)
			Sfx.play("evolve")


## 숨결이 적에게 닿았다
static func on_player_hit_enemy() -> void: add_momentum(2)


## 적을 쓰러뜨렸다
static func on_kill(big := false) -> void:
	add_momentum(20 if big else 8)
	if Relics.has("HUNGRY_FLAME"):
		var f := F()
		f.stacks = mini(3, f.stacks + 1); f.stackT = 3.0


## 내가 맞았다
static func on_player_hurt() -> void:
	F().m *= 0.8 if Relics.has("BOILING_BLOOD") else 0.5


static func update(dt: float) -> void:
	var f := F()
	f.slow = maxf(0, f.slow - dt)
	f.edge = maxf(0, f.edge - dt)
	if f.stackT > 0:
		f.stackT -= dt
		if f.stackT <= 0: f.stacks = 0
	f.idle += dt
	if f.idle > 8 and f.m > 0: f.m = maxf(0, f.m - 5 * dt)   # 싸움이 끊기면 식는다 (무리와 무리 사이에서 다 식던 것)


static func _boss_attacking(b) -> bool:
	return (b.charge and not (b.charge.get("windup", 0) > 0)) or b.beam or b.spiral or b.blizzard or b.threat > 0


## 간발: 대시 첫머리에 적의 탄이나 내려치는 공격을 스치듯 피했는가. 대시 한 번에 한 번만
static func try_perfect_dodge(p) -> void:
	if p.dash_edge: return
	var E: Dictionary = GameState.entities
	var near := false
	for b in E.bullets:
		if not b.remove and b.faction == "ENEMY" and Util.dist(b, Vector2(p.x, p.y - 30)) < EDGE_RANGE: near = true
	for e in E.enemies:
		if not e.remove and (e.ai.s == "act" or (e.ai.s == "tell" and e.ai.t < 0.25)) and Util.dist(e, p) < 120: near = true
	for h in E.humans:
		if not h.remove and ((h.swing > 0 and h.swing < 0.25 and Util.dist(h, p) < 120) \
				or (h.charge and h.charge.windup > 0 and h.charge.windup < 0.3 and Util.dist(h, p) < 520)): near = true
	var boss_attacking := false
	for b in E.bosses:
		if not b.remove and b.awake and not b.is_hidden and Util.dist(b, p) < 760 and _boss_attacking(b): boss_attacking = true
	if not near and not boss_attacking: return
	p.dash_edge = true
	var f := F()
	f.slow = 1.6 if Relics.has("FROZEN_CLOCK") else 0.8
	f.edge = 3.0
	p.dash_cd = 0.0
	add_momentum(25)
	Vfx.spawn_text(p.x, p.y - 130 * p.stage.scale, "간발!", "#9fe3ff", 22)
	Vfx.spawn_effect("RING", p.x, p.y - 40, { size = 1.8, color = "#9fe3ff" })
	Feedback.flash(0.35, Color8(160, 220, 255))
	Sfx.play("crit")
	# 보스의 큰 공격을 간발로 피하면 보스가 비틀거린다. 그동안 두 배로 맞는다
	for b in E.bosses:
		if b.remove or not b.awake or b.is_hidden or Util.dist(b, p) > 760: continue
		if not _boss_attacking(b) or b.stagger > 0: continue
		b.stagger = 2.4; b.opening = true
		Vfx.spawn_text(b.x, b.y - 90 * b.def.get("scale", 1), "빈틈!", "#9fe3ff", 20)
		_once("flowBoss", "빈틈! 보스의 큰 공격을 간발로 피하면 잠깐 비틀거린다. 그동안 두 배로 맞는다.", "💥")
	# 유물 '폭풍의 눈': 간발로 피한 자리에 번개가 떨어진다
	if Relics.has("STORM_EYE"):
		for e in E.enemies + E.humans + E.bosses:
			if e.remove or Util.dist(e, p) > 300: continue
			e.take_damage(30 * p.damage_mult, false, p)
			Vfx.spawn_effect("THUNDER_HIT", e.x, e.y - 30, { size = 1.6 })
		GameCamera.current.shake(6); Sfx.play("zap")


## 물어뜯기: 숨이 붙어 있는 적을 대시로 뚫고 지나가면 끝장을 낸다. 보스와 대장에게는 통하지 않는다
static func try_bite(p) -> void:
	var E: Dictionary = GameState.entities
	var limit := 0.45 if Relics.has("RED_MOON_TOOTH") else 0.25
	for e in E.enemies + E.humans:
		if e.remove or e.def.get("noLoot") or e.def.get("scale") or e.type == "CAPTAIN": continue
		if Util.dist(e, p) > BITE_RANGE or e.hp > e.max_hp * limit: continue
		e.take_damage(e.hp + 1, false, p)
		var heal: float = p.max_hp * (0.09 if Relics.has("RED_MOON_TOOTH") else 0.03)
		p.hp = minf(p.max_hp, p.hp + heal)
		p.dash_cd = 0.0
		add_momentum(12)
		Vfx.spawn_text(e.x, e.y - 70, "물어뜯기!", "#ff8a6a", 18)
		Vfx.spawn_text(p.x, p.y - 100 * p.stage.scale, "+%d" % roundi(heal), "#9fe08a", 14)
		Vfx.spawn_effect("SLASH", e.x, e.y - 24, { size = 1.5, angle = atan2(p.dash_dir.y, p.dash_dir.x), color = "#ffb0a0" })
		Particles.burst(e.x, e.y - 20, "#ff6b5e", 1, 10)
		Feedback.hit_stop(0.09); GameCamera.current.shake(5)
