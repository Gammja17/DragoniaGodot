class_name Hazard
extends RefCounted
## 2D판 entities/Hazard.js. 바닥의 위험 지대. 예고(delay) → 터짐(damage) → 남아서 지속 피해(linger, dps).
## 보스 기믹(운석, 얼음 기둥, 장판)과 플레이어 스킬(운석 낙하, 서릿발)이 함께 쓴다. FxLayer(HAZARDS)가 바닥에 그린다.
## opts: { r, inner?(고리 모양일 때 안쪽 반지름), delay, linger, damage, dps, faction: 'ENEMY' | 'ALLY',
##         color, effect?(터질 때 vfx), effectSize?, sound?, slow?(안에 있으면 느려짐), status?: { type, duration }, shake? }

var x: float
var y: float
var r := 120.0
var inner := 0.0
var delay := 0.8
var linger := 0.0
var damage := 0.0
var dps := 0.0
var faction := "ENEMY"
var color := Color("#ff5a3c")
var effect = null
var effect_size := 1.0
var sound = null
var slow := false
var status = null
var shake := 0.0
var t := 0.0
var burst := false
var remove := false


static func add(px: float, py: float, opts: Dictionary) -> Hazard:
	var h := Hazard.new()
	h.x = px; h.y = py
	h.r = opts.get("r", 120); h.inner = opts.get("inner", 0); h.delay = opts.get("delay", 0.8)
	h.linger = opts.get("linger", 0); h.damage = opts.get("damage", 0); h.dps = opts.get("dps", 0)
	h.faction = opts.get("faction", "ENEMY"); h.color = Color(opts.get("color", "#ff5a3c"))
	h.effect = opts.get("effect"); h.effect_size = opts.get("effectSize", 1) if opts.get("effectSize") else 1.0
	h.sound = opts.get("sound"); h.slow = bool(opts.get("slow", false)); h.status = opts.get("status"); h.shake = opts.get("shake", 0) if opts.get("shake") else 0.0
	GameState.entities.hazards.append(h)
	return h


func _targets() -> Array:
	var E: Dictionary = GameState.entities
	var list: Array = [GameState.player] + Combat.allies() if faction == "ENEMY" else (E.enemies + E.humans + E.bosses).filter(func(e): return e.get("awake") != false)
	return list.filter(func(e):
		var d := Util.dist(self, e)
		return d <= r + (50 if e.def.get("scale") else 0) and d >= inner)


func light():
	return { r = r * 1.6, color = color, intensity = 0.7, emissive = true } if burst and linger > 0 else null


func update(dt: float) -> void:
	t += dt
	var player = GameState.player
	if not burst and t >= delay:
		burst = true
		for e in _targets():
			if damage: e.take_damage(damage)
			if status and e != player: Status.apply(e, status.type, status.duration)
			if status and e == player and status.type != "BURN": e.slow_timer = maxf(e.slow_timer, status.duration)
		if effect: Vfx.spawn_effect(effect, x, y, { size = effect_size, angle = -PI / 2 })
		if sound: Sfx.play(sound)
		if shake: GameCamera.current.shake(shake)
	if burst:
		var left := delay + linger - t
		if left <= 0:
			remove = true
			return
		for e in _targets():
			if dps: e.take_damage(dps * dt, true)
			if slow and e == player: e.slow_timer = maxf(e.slow_timer, 0.3)
			if slow and e != player: Status.apply(e, "SLOW", 0.4)


func draw(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2(x, y), 0, Vector2(1, 0.55))   # 바닥에 누운 원
	if not burst:
		var k := t / delay
		ci.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 0.5 + k * 0.4), 4)
		if inner: ci.draw_arc(Vector2.ZERO, inner, 0, TAU, 48, Color(color, 0.5 + k * 0.4), 4)
		_disc(ci, inner + (r - inner) * k, Color(color, 0.12 + k * 0.22))
	else:
		var left := (delay + linger - t) / (linger if linger else 1.0)
		_disc(ci, r, Color(color, minf(0.4, left * 0.8)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if burst and linger > 0 and not inner: Pixel.draw_glow(ci, x, y, r * 0.9, color, 0.25)


## 채운 원. inner 가 있으면 가운데가 뚫린 고리
func _disc(ci: CanvasItem, outer: float, c: Color) -> void:
	if not inner:
		ci.draw_circle(Vector2.ZERO, outer, c)
		return
	var pts := PackedVector2Array()
	for i in 49: pts.append(Vector2.from_angle(TAU * i / 48.0) * outer)
	for i in 49: pts.append(Vector2.from_angle(TAU * (48 - i) / 48.0) * inner)
	ci.draw_colored_polygon(pts, c)
