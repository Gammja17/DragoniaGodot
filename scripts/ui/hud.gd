class_name Hud
extends CanvasLayer
## 2D판 ui/hud.js · ui/toast.js 가운데 지금 쓰는 것: 지역 이름 배너와 알림.
## 모양은 scenes/ui/hud.tscn · toast.tscn 에 있고, 여기서는 띄우고 움직이기만 한다.

const TOAST_SCENE := preload("res://scenes/ui/toast.tscn")
const MAX_TOASTS := 4

@onready var _banner: Control = $RegionBanner
@onready var _region_name: Label = $RegionBanner/Name
@onready var _region_sub: Label = $RegionBanner/Sub
@onready var _toasts: VBoxContainer = $ToastBox

var _banner_tween: Tween


func _ready() -> void:
	_banner.modulate.a = 0


## 지도를 옮기면 지역 이름을 위쪽에 잠깐 띄웠다 지운다 (2.8초).
## 글자 사이가 벌어졌다 모이고, 사라질 때 다시 조금 벌어진다
func show_region_banner(name_text: String, sub := "") -> void:
	_region_name.text = name_text
	_region_sub.text = sub
	GameState.bannerUntil = GameState.game_time + 3   # 이 동안은 사건 컷씬을 띄우지 않는다
	var spacing: FontVariation = _region_name.label_settings.font
	if _banner_tween: _banner_tween.kill()
	_banner.modulate.a = 0
	_banner.position.y = _banner_top() - 14
	spacing.spacing_glyph = 10
	var t := create_tween()
	_banner_tween = t
	# 0% → 14%: 떨어지며 나타나고 글자 사이가 10 → 4
	t.set_parallel(true).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner, "modulate:a", 1.0, 0.39)
	t.tween_property(_banner, "position:y", _banner_top(), 0.39)
	t.tween_property(spacing, "spacing_glyph", 4, 0.39)
	# 78% → 100%: 사라지며 4 → 7
	t.chain().tween_interval(1.79)
	t.chain().set_parallel(true).tween_property(_banner, "modulate:a", 0.0, 0.62)
	t.tween_property(spacing, "spacing_glyph", 7, 0.62)


func _banner_top() -> float:
	return get_viewport().get_visible_rect().size.y * 0.12


## 알림은 화면 위쪽 가운데에 차곡차곡 쌓인다. 한 번에 최대 4개, 3.4초
func toast(msg: String, icon := "✨") -> void:
	var t: Control = TOAST_SCENE.instantiate()
	t.get_node("Label").text = "%s %s" % [icon, msg]
	_toasts.add_child(t)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	t.modulate.a = 0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.27)
	tw.tween_interval(2.62)
	tw.tween_property(t, "modulate:a", 0.0, 0.51)
	tw.tween_callback(t.queue_free)
