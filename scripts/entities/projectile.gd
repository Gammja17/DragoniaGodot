class_name Projectile
extends RefCounted
## 2D판 entities/Projectile.js. 모든 투사체. faction 'ALLY'(플레이어/짝/자식)는 적·사냥꾼·보스에게,
## 'ENEMY'는 플레이어(와 마을 용)에게만 맞는다. 노드가 아니라 FxLayer 가 그린다.
## opts: { faction, element, kind: 'BREATH' | 'ARROW', damage, speed, life, scale, radius, pierce, fromPlayer, slow, homing, homingTarget, by }

const CRIT_CHANCE := 0.12   # 치명타: 피해 2배
const ARROW := Rect2(176, 160, 16, 16)   # Tiny Dungeon 시트의 화살(위쪽을 향함)

var x: float
var y: float
var faction: String
var kind: String
var element: String
var damage: float
var vx: float
var vy: float
var angle: float
var life: float
var scale: float
var radius: float
var pierce: bool
var hit_set := {}             # 관통탄이 이미 맞힌 대상
var from_player: bool         # 플레이어가 쏜 탄만 필살기 게이지를 채운다
var slow: float               # 맞은 용을 이만큼(초) 느리게 한다 (그물)
var homing: float             # 초당 꺾을 수 있는 각도(rad)
var homing_target = null      # 따라갈 상대. 없으면 플레이어 (사냥꾼의 그물)
var by = null                 # 쏜 용. 적이 "나를 친 쪽"을 기억한다 (모르면 null)
var speed: float
var t := 0.0
var remove := false
var ricochet := false
var shard := false
var chain_bonus := 0


static func els() -> Dictionary:
	return Data.get_module("elements").ELEMENTS


func _init(px: float, py: float, a: float, opts := {}) -> void:
	x = px; y = py
	faction = opts.get("faction", "ALLY")
	kind = opts.get("kind", "BREATH")
	element = opts.get("element", "FIRE") if opts.get("element") else "FIRE"
	var el: Dictionary = els()[element]
	damage = opts.get("damage", el.damage)
	speed = opts.get("speed", el.speed)
	vx = cos(a) * speed
	vy = sin(a) * speed
	angle = a
	life = opts.get("life", el.get("life", 1.2))
	scale = opts.get("scale", 1.0)
	radius = opts.get("radius", el.get("radius", 40))   # 맞는 범위
	pierce = bool(opts.get("pierce", el.get("pierce", false))) and faction == "ALLY"   # 관통: 같은 적은 한 번만 맞는다
	from_player = bool(opts.get("fromPlayer", false))
	slow = opts.get("slow", 0.0)
	homing = opts.get("homing", 0.0)
	homing_target = opts.get("homingTarget")
	by = opts.get("by")


## 빛을 더해 그리는가 (빛나는 숨결). 물·독즙·바위는 밝은 풀밭 위에서 하얗게 날아가 버려 제 색 그대로
func additive() -> bool:
	return kind == "BREATH" and not els()[element].proj.get("solid", false)


func light():
	return { r = 170 * scale, color = Data.get_module("elements").ELEMENTS[element].color, emissive = true } if kind == "BREATH" else null


func update(dt: float) -> void:
	if homing:
		var tg = homing_target if homing_target else GameState.player
		# 쫓던 상대가 쓰러지면 더 꺾지 않고 가던 길로 날아간다
		if tg and not tg.remove:
			var ty: float = tg.y - (20 if homing_target else 30)
			var da := atan2(ty - y, tg.x - x) - angle
			da = atan2(sin(da), cos(da))
			angle += clampf(da, -homing * dt, homing * dt)
			vx = cos(angle) * speed; vy = sin(angle) * speed
	x += vx * dt
	y += vy * dt
	life -= dt
	t += dt
	if life < 0: remove = true
	if kind == "BREATH" and randf() < 0.25: Particles.burst(x, y, els()[element].trail, 0.4)


## 이 숨결이 대상에 걸린 상태와 반응하나
func reaction(target):
	var table = Data.get_module("elements").REACTIONS.get(element)
	var s: Dictionary = target.status
	if not table or s.is_empty(): return null
	for k in table:
		if s.get(k, 0) > 0:
			var r: Dictionary = table[k].duplicate()
			r.on = k
			return r
	return null


func apply_reaction(r: Dictionary, target, targets: Array) -> void:
	Vfx.spawn_text(target.x, target.y - 78, r.name, els()[element].color, 17)
	if r.get("clear"): target.status[r.on] = 0.0
	if r.get("stun"): Status.apply(target, "STUN", r.stun)
	if r.get("burn"): Status.apply(target, "BURN", r.burn)
	if r.get("poison"): Status.apply(target, "POISON", r.poison)
	if r.get("spread"):
		Vfx.spawn_effect("SHOCKWAVE", target.x, target.y - 20, { size = r.spread / 90.0, color = els()[element].color })
		for e in targets:
			if e == target or e.remove or Util.dist(e, target) > r.spread: continue
			e.take_damage(damage * 0.8, false, self)
			if r.get("burn"): Status.apply(e, "BURN", r.burn)
	chain_bonus = r.get("chain", 0)


## 대상에 맞았을 때 (systems/combat). targets: 번개가 튈 수 있는 다른 대상들
func hit(target, targets := []) -> void:
	if hit_set.has(target): return
	hit_set[target] = true
	if not pierce: remove = true
	var el: Dictionary = els()[element]
	if kind == "BREATH": Vfx.spawn_effect(el.hit, x, y, { angle = angle, size = scale })
	if faction != "ALLY":
		target.take_damage(damage)
		if slow and target == GameState.player and not (target.invuln > 0):
			target.slow_timer = maxf(target.slow_timer, slow)
			Hud.pop("그물에 걸렸다! 잠깐 발이 무겁다.", "🕸️")
		return
	var p = GameState.player
	if from_player and (p.elements.size() >= 3): p.ult = minf(100, p.ult + 1.5)
	if from_player: Flow.on_player_hit_enemy()
	# 유물 '갈고리 숨결': 맞은 자리에서 가까운 다른 적에게 한 번 더 튄다
	if from_player and kind == "BREATH" and not ricochet and Relics.has("RICOCHET"):
		var next = null
		var best := 260.0
		for tt in targets:
			if tt != target and not tt.remove and Util.dist(tt, target) < best:
				best = Util.dist(tt, target); next = tt
		if next:
			var c := Projectile.new(x, y, atan2(next.y - 20 - y, next.x - x), { faction = "ALLY", element = element, damage = damage * 0.7, scale = scale * 0.8, fromPlayer = true })
			c.ricochet = true; c.hit_set[target] = true
			add(c)
	# 유물 '갈라진 비늘': 숨결이 맞은 자리에서 작은 조각 둘로 갈라져 나간다 (조각은 다시 갈라지지 않는다)
	if from_player and kind == "BREATH" and not shard and Relics.has("SPLIT_SCALE"):
		for side in [-1, 1]:
			var c := Projectile.new(x, y, angle + side * 0.7, { faction = "ALLY", element = element, damage = damage * 0.4, scale = scale * 0.6, fromPlayer = true })
			c.shard = true; c.hit_set[target] = true; c.life = minf(c.life, 0.35)
			add(c)
	var crit := randf() < CRIT_CHANCE + (0.1 if Relics.has("HUNTER_CHARM") else 0.0) + (0.08 if from_player and Relics.resonates("fang") else 0.0)
	Sfx.play("crit" if crit else "hit")
	# 속성 연계: 이미 걸려 있는 상태에 이 숨결이 닿으면 반응이 난다 (REACTIONS)
	var react = reaction(target) if kind == "BREATH" else null
	var dmg: float = damage * ((3.0 if Relics.has("BASIL_FANG") else 2.0) if crit else 1.0) * (react.mult if react and react.get("mult") else 1.0)
	if EnemyAI.blocks_from(target, x, y):        # 방패 고블린의 정면 — 튕긴다
		Vfx.spawn_effect("SPARK", x, y, { size = 0.9, color = "#cfe0ff" })
		Vfx.spawn_text(target.x, target.y - 50, "막힘", "#cfe0ff", 13)
		remove = true
		return
	target.take_damage(dmg, false, self)   # 맞은 쪽을 넘겨 주면 그쪽으로 밀린다
	Vfx.spawn_effect("CRIT_FLASH" if crit else "HIT_SPARK", target.x, target.y - 24, { size = 1.2 if crit else 1.0, color = null if crit else el.color })
	GameCamera.current.shake(3 if crit else 1.2)
	Vfx.spawn_text(target.x, target.y - 50, ("%d!" if crit else "%d") % roundi(dmg), "#ffd84a" if crit else "#fff", 22 if crit else 15)
	if crit:
		Feedback.hit_stop(0.05); GameCamera.current.shake(4)   # 치명타는 한 박자 멈춘다
	else:
		Feedback.hit_stop(0.018)                               # 보통 타도 한 프레임쯤은 멈춘다. 맞았다는 느낌은 여기서 난다
	if kind != "BREATH": return
	if react: apply_reaction(react, target, targets)
	if el.get("push") and not target.status_immune and not target.def.get("scale"):
		target.x += cos(angle) * el.push; target.y += sin(angle) * el.push
	if el.get("status"):
		# 이미 느려진 적에게 냉기를 또 맞히면 얼어붙는다
		if el.status.type == "SLOW" and target.status.get("SLOW", 0) > 0: Status.apply(target, "STUN", 1.2)
		Status.apply(target, el.status.type, el.status.duration)
	if el.get("chain"):
		var from = target
		var used := { target: true }
		var bounces: int = el.chain.count + (1 if Relics.has("ZALGORA_SCALE") else 0) + chain_bonus   # 젖은 적에게는 더 멀리 튄다 (감전)
		for i in bounces:
			var next = null
			for tt in targets:
				if not tt.remove and not used.has(tt) and Util.dist(from, tt) < el.chain.range:
					next = tt
					break
			if next == null: break
			Vfx.spawn_bolt(from.x, from.y - 16, next.x, next.y - 16)
			next.take_damage(el.chain.damage)
			Vfx.spawn_text(next.x, next.y - 50, "%d" % el.chain.damage, "#ffe27a", 14)
			used[next] = true
			from = next


func draw(ci: CanvasItem) -> void:
	if kind == "ARROW":
		_sprite(ci, TileImages.get_texture("dungeon"), ARROW, 2.5, 0.5, 0.5, angle + PI / 2)
		return
	var p: Dictionary = els()[element].proj
	var frame: int = p.frames[floori(t * p.fps) % p.frames.size()]
	_sprite(ci, Vfx.texture(p.img), Rect2(frame * p.fw, 0, p.fw, p.fh), 3 * scale, p.ax, p.ay, angle + p.get("spin", 0) * t)


## drawPixelSprite: 기준점을 정수 좌표에 두고 돌려 그린다
func _sprite(ci: CanvasItem, tex: Texture2D, src: Rect2, s: float, ax: float, ay: float, rot: float) -> void:
	var w := src.size.x * s
	var h := src.size.y * s
	ci.draw_set_transform(Vector2(roundf(x), roundf(y)), rot)
	ci.draw_texture_rect_region(tex, Rect2(-w * ax, -h * ay, w, h), src)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func add(b: Projectile) -> void:
	var B: Array = GameState.entities.bullets
	B.append(b)
	var cap: int = Data.get_module("core_config").MAX_BULLETS
	if B.size() > cap: B.assign(B.slice(B.size() - cap))
