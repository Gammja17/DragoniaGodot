class_name SneakView
extends Node2D
## 몰래 다가가기(Sneak) 판 하나. 땅에 깔리는 것만 그린다 (scenes/sneak/sneak_view.tscn):
##   · 돌아보려는('?') · 돌아본 이의 시선 부채꼴. 가리개 뒤 그늘은 비워 둔다. 가까운 곳(Near)은 한 겹 더 진하다
##   · 엿들을 자리의 고리
## main 을 고치지 않고 매 프레임 돌 자리가 필요해서, 판의 박자(Sneak.tick)도 여기서 부른다.
## Sneak 이 World(개체) 바로 아래 층에 끼워 넣어 개체보다 먼저(밑에) 그려진다.

var run := {}   # 판의 상태 (Sneak 이 채운다)

@onready var _fans := [[$Fan0Far, $Fan0Near], [$Fan1Far, $Fan1Near]]
@onready var _goal: Line2D = $Goal


func _ready() -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * Sneak.LISTEN, sin(a) * Sneak.LISTEN * 0.55))
	_goal.points = pts


func _process(dt: float) -> void:
	if is_queued_for_deletion(): return
	Sneak.tick(self, minf(dt, 0.1))
	if is_queued_for_deletion(): return
	var show: bool = run.get("phase") == "play" and not Cutscene.on
	var ws: Array = run.get("watchers", [])
	for i in _fans.size():
		var w = ws[i] if i < ws.size() else null
		var on: bool = show and w != null and (w.phase == "warn" or w.phase == "look")
		for poly in _fans[i]: poly.visible = on
		if not on: continue
		var o := Vector2(w.e.x, w.e.y)
		# 돌아보기 전('?')에는 흐릿하게 어디를 볼지 미리 보여 주고, 돌아보면 또렷해진다
		var a: float = 1.0 if w.phase == "look" else 0.4
		_fans[i][0].polygon = Sneak.fan(run, o, w.aim, Sneak.REACH)
		_fans[i][1].polygon = Sneak.fan(run, o, w.aim, Sneak.NEAR)
		for poly in _fans[i]: poly.modulate = Color(w.tint.r, w.tint.g, w.tint.b, a)
	_goal.visible = show
	if show:
		_goal.position = run.listen
		_goal.modulate.a = 0.55 + sin(GameState.game_time * 4.0) * 0.35
