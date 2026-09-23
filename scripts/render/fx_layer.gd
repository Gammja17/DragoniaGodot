class_name FxLayer
extends Node2D
## 노드가 아닌 가벼운 개체들(탄·효과·빛 알갱이)을 한꺼번에 그리는 층.
## 2D판은 한 캔버스에 그리며 그때그때 섞기('lighter')를 바꿨는데, Godot 는 노드마다 섞기가 하나라
## 빛을 더하는 것과 그냥 얹는 것을 층을 나눠 그린다. 층 순서는 2D판 render() 의 순서를 따른다:
##   바닥 장판·예고(TELLS) → [y 정렬 개체] → 탄 → 효과 → 빛 알갱이 → 조준점

enum Mode { TELLS, BULLETS, BULLETS_ADD, EFFECTS, EFFECTS_ADD, PARTICLES, CROSSHAIR }

@export var mode: Mode


func _ready() -> void:
	if mode in [Mode.BULLETS_ADD, Mode.EFFECTS_ADD, Mode.PARTICLES]:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var E: Dictionary = GameState.entities
	if E.is_empty(): return
	match mode:
		Mode.TELLS:
			for h in E.hazards: h.draw(self)   # 바닥 장판은 개체들 밑에
			for e in E.enemies: EnemyAI.draw_tell(self, e)
		Mode.BULLETS, Mode.BULLETS_ADD:
			if Cutscene.on: return   # 허공에 멈춘 화살은 장면을 깬다
			var add := mode == Mode.BULLETS_ADD
			for b in E.bullets:
				if b.additive() == add: b.draw(self)
		Mode.EFFECTS, Mode.EFFECTS_ADD:
			var add := mode == Mode.EFFECTS_ADD
			for fx in E.effects:
				if fx.additive == add: fx.draw(self)
			if add: NightEvents.draw(self)   # 떨어지는 별의 꼬리
		Mode.PARTICLES:
			for p in E.particles: p.draw(self)
		Mode.CROSSHAIR:
			_draw_crosshair()


## 마우스 조준 표시. 커서가 적에게 붙었을 때는 그 적을 네 귀퉁이로 감싸 "여기를 맞힌다"를 분명히 보여 준다
func _draw_crosshair() -> void:
	var p = GameState.player
	if not p or GameState.isDialogueOpen: return
	# 터치에는 커서가 없다. 대신 자동 조준이 붙잡은 적을 괄호로 감싸 "여기로 나간다"를 보여 준다
	if not GameInput.mouse_inside and not GameInput.touch: return
	var color := Color(Data.get_module("elements").ELEMENTS[p.element].color)
	var aim: Dictionary = p.aim_angle()
	var target = aim.target
	if target:
		var r: float = 26 + (target.def.scale * 16 if target.def.get("scale") else 0)
		var cx := roundf(target.x)
		var cy := roundf(target.y - 20)
		var arm := r * 0.45
		var c := Color(color, 0.95)
		for s in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
			draw_polyline(PackedVector2Array([Vector2(cx + s[0] * r, cy + s[1] * r - s[1] * arm), Vector2(cx + s[0] * r, cy + s[1] * r),
				Vector2(cx + s[0] * r - s[0] * arm, cy + s[1] * r)]), c, 2)
	elif GameInput.mouse_inside:
		var w: Vector2 = GameCamera.current.screen_to_world(GameInput.mouse_pos)
		var cx := roundf(w.x)
		var cy := roundf(w.y)
		draw_arc(Vector2(cx, cy), 9, 0, TAU, 32, Color(color, 0.7), 2)
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			draw_line(Vector2(cx + d[0] * 13, cy + d[1] * 13), Vector2(cx + d[0] * 19, cy + d[1] * 19), Color(color, 0.9), 2)
