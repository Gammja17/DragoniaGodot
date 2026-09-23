class_name Particles
## 2D판 entities/Particle.js. 빛 알갱이. 노드가 아니라 가벼운 객체로 쌓고 FxLayer(더하기)가 그린다.


class Particle:
	var x: float
	var y: float
	var color: Color
	var life: float
	var vx := (randf() - 0.5) * 90
	var vy := (randf() - 0.5) * 90
	var remove := false

	func _init(px: float, py: float, c: Color, l: float) -> void:
		x = px; y = py; color = c; life = l

	func update(dt: float) -> void:
		x += vx * dt
		y += vy * dt
		life -= dt
		if life < 0: remove = true

	func draw(ci: CanvasItem) -> void:
		if life <= 0: return
		var r := 5 + minf(1, life) * 7
		Pixel.draw_glow(ci, x, y, r, color, minf(1, life))


## 파티클을 count개 뿌리고 상한을 유지. color 는 "#rrggbb", Color, 또는 색을 돌려주는 Callable
static func burst(x: float, y: float, color, life := 1.0, count := 1) -> void:
	var P: Array = GameState.entities.particles
	for i in count:
		var c = color.call() if color is Callable else color
		P.append(Particle.new(x, y, Color(c) if c is String else c, life))
	var cap: int = Data.get_module("core_config").MAX_PARTICLES
	if P.size() > cap: P.assign(P.slice(P.size() - cap))
