class_name HudRight
extends VBoxContainer
## 2D판 HUD 오른쪽 기둥: 지역 · 미니맵 · 습격 · 퀘스트 추적. 모양은 scenes/ui/hud_right.tscn.

signal collapse_pressed

@export var raid_style: StyleBox
@export var raid_active_style: StyleBox

@onready var _name: Label = $Biome/Lines/Name
@onready var _sub: Label = $Biome/Lines/Sub
@onready var _raid: Label = $Raid
@onready var quest: QuestLine = $Quest

var _last_map := ""


func _ready() -> void:
	$Collapse.pressed.connect(func(): collapse_pressed.emit())


func refresh() -> void:
	if not GameState.player: return
	if GameState.dungeon:
		_name.text = Delve.dungeon_name()
		_sub.visible = false
	else:
		if GameState.map_id != _last_map:
			_last_map = GameState.map_id
			Quests.notify("visit", GameState.map_id)
		_name.text = Names.map(GameState.map_id)
		var ev = NightEvents.event_name()
		_sub.text = "%s · %s" % [ev if ev else NightEvents.day_phase_name(), Weather.weather_name()]
		_sub.visible = true
	_raid.text = Raid.status_text()
	_raid.visible = _raid.text != ""
	_raid.add_theme_stylebox_override("normal", raid_active_style if GameState.raid.active else raid_style)
	_raid.add_theme_color_override("font_color", Color.WHITE if GameState.raid.active else Color("#cdc4af"))
