extends Node2D
## 2D판 main.js 의 게임 루프. 갱신 순서가 결과를 바꾸는 곳이 많아서
## 노드마다 _process 를 돌리지 않고 여기서 2D판과 같은 순서로 부른다.

@onready var terrain: Terrain = $Terrain
@onready var world: Node2D = $World          # y 정렬: 아래쪽 개체가 앞에 온다
@onready var camera: GameCamera = $Camera


func _ready() -> void:
	# 1단계: 시작 지도(웨스턴 마을)의 바닥만 깔고, 기본 외형의 해츨링을 세운다.
	# 새 게임 설정 화면(customizer)을 옮기면 거기서 고른 설정이 들어온다
	var maps: Dictionary = Data.get_module("maps")
	var start: String = maps.START_MAP
	var spec: Dictionary = maps.MAPS[start].duplicate()
	spec.id = start
	GameState.map_id = start
	var m := GameMap.build(spec)
	Terrain.set_active_map(m)
	Collision.build_prop_grid([])

	var player := Dragon.new().setup(m.w / 2.0, m.h * 0.62, { name = "용", species = "LOOK", look = 0 }, true)
	world.add_child(player)
	GameState.player = player
	camera.cam_x = player.x - camera.w / 2
	camera.cam_y = player.y - camera.h / 2


func _process(delta: float) -> void:
	var dt := clampf(delta, 0, 0.1)
	if GameInput.pressed("zoom"): print("시점: ", camera.cycle_zoom())
	if GameInput.wheel: camera.step_zoom(GameInput.wheel)   # 휠은 조용히 (알림이 정신 사납다고 해서)
	GameState.game_time += dt
	GameState.player.update(dt)
	camera.follow(GameState.player)
