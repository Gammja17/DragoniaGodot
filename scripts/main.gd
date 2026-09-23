extends Node2D
## 2D판 main.js 의 게임 루프. 갱신 순서가 결과를 바꾸는 곳이 많아서
## 노드마다 _process 를 돌리지 않고 여기서 2D판과 같은 순서로 부른다.

@onready var terrain: Terrain = $Terrain
@onready var world: Node2D = $World          # y 정렬: 아래쪽 개체가 앞에 온다
@onready var camera: GameCamera = $Camera
@onready var overlay: Overlay = $CrispLayer/Overlay
@onready var hud: Hud = $Hud


func _ready() -> void:
	World.container = world
	overlay.camera = camera
	overlay.world = world
	# 새 게임 설정 화면(customizer)을 옮기면 거기서 고른 설정이 들어온다. 지금은 기본 외형의 해츨링
	World.init_world({ name = "용", species = "LOOK", look = 0 })
	GameState.gameActive = true
	var p = GameState.player
	camera.cam_x = p.x - camera.w / 2
	camera.cam_y = p.y - camera.h / 2


func _exit_tree() -> void:
	World.dispose()


func _process(delta: float) -> void:
	var dt := clampf(delta, 0, 0.1)
	if GameInput.pressed("zoom"): hud.toast("시점: " + camera.cycle_zoom(), "🔍")
	if GameInput.wheel: camera.step_zoom(GameInput.wheel)   # 휠은 조용히 (알림이 정신 사납다고 해서)
	_update(dt)
	camera.follow(GameState.player)
	_mark_fade_targets()


func _update(dt: float) -> void:
	var E: Dictionary = GameState.entities
	GameState.game_time += dt
	GameState.player.update(dt)
	for e in E.npcs: e.update(dt)
	World.update_portals(hud)


## 나무 뒤에 가려지면 안 되는 것들 (Prop 이 이 목록을 보고 나무를 투명하게 한다).
## 2D판은 그릴 때 화면 근처 것만 골라 이 목록을 만든다
func _mark_fade_targets() -> void:
	var E: Dictionary = GameState.entities
	var list := []
	var near := func(e) -> bool:
		return e.x + 420 > camera.cam_x and e.x - 420 < camera.cam_x + camera.w \
			and e.y + 420 > camera.cam_y and e.y - 420 < camera.cam_y + camera.h
	for e in E.npcs + [GameState.player]:
		if not e.is_hidden and near.call(e): list.append(e)
	for p in E.props:
		if (p.type == "CHEST" and not p.opened) or (p.type == "BERRY" and p.ripe):
			if near.call(p): list.append(p)
	GameState.fadeTargets = list
