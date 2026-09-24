class_name DenPanel
extends GamePanel
## 2D판 ui/denPanel.js. 굴 꾸미기 판. [E] 로 열고, 줄을 누르면 그 살림살이를 들고 놓는 자리로 간다.
##  · [가진 것]    놓을 수 있는 것들. 누르면 들고 나간다
##  · [엮는다]     골드와 소재로 새로 만든다
##  · [놓아 둔 것] 치워서 되돌린다

const ITEM := preload("res://scenes/ui/den_item.tscn")

static var current: DenPanel

@export var tab_style: StyleBox
@export var tab_on_style: StyleBox
@export var tab_hover_style: StyleBox

var _tab := "have"


func _ready() -> void:
	super()
	current = self
	for b in $Frame/Lines/Body/Tabs.get_children():
		b.pressed.connect(func():
			_tab = b.name
			Sfx.play("ui")
			_render())


# ---------- 다른 시스템이 부르는 것 (Den · Story) ----------

static func show_panel() -> void:
	if not current or GameState.map_id != Den.MY_DEN: return
	current._render()
	current.open()


static func panel_open() -> bool: return current != null and current.visible


## 놓을 자리를 고르는 동안 화면 아래에 띄우는 안내 한 줄 (빈 글이면 지운다)
static func hint(text: String) -> void:
	Hud.current.set_hint(text)


# ---------- 판 ----------

## 하나를 들고 놓는 자리로 간다 (판은 닫힌다)
func _hold(id: String) -> void:
	GameState.holding = id
	close()
	Hud.pop("놓을 자리를 고르고 왼쪽 클릭. 오른쪽 클릭이면 그만둔다.", "🪑")


func _render() -> void:
	for b in $Frame/Lines/Body/Tabs.get_children():
		var on: bool = b.name == _tab
		for s in ["normal", "pressed"]: b.add_theme_stylebox_override(s, tab_on_style if on else tab_style)
		b.add_theme_stylebox_override("hover", tab_on_style if on else tab_hover_style)
		b.add_theme_color_override("font_color", Color("#1a1206") if on else Color("#cdc4af"))
		b.add_theme_color_override("font_hover_color", Color("#1a1206") if on else Color("#ece3cf"))
	var cozy := Den.cozy_of(Den.MY_DEN)
	$Frame/Lines/Body/Meta/Cozy.text = "아늑함 %d · %s" % [cozy.score, cozy.name]
	$Frame/Lines/Body/Meta/Note.text = cozy.note
	var list: VBoxContainer = $Frame/Lines/Body/Scroll/List
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var F := Den.furniture()
	var empty := ""
	match _tab:
		"have":
			for id in Den.owned_list():
				_item(id, "%s (가진 것 %d개)" % [F[id].note, Den.owned(id)], false, func():
					Sfx.play("ui")
					_hold(id))
			empty = "아직 가진 살림살이가 없다. [엮는다]에서 만들어 보자."
		"craft":
			for id in F:
				_item(id, Den.cost_text(id), not Den.can_afford(id), func():
					if not Den.craft(id): Hud.pop("재료나 골드가 모자랍니다.", "🪵")
					_render())
		"placed":
			var placed := Den.decor_of(Den.MY_DEN)
			for i in placed.size():
				var d: Dictionary = placed[i]
				_item(d.id, "누르면 치워서 되돌린다", false, func():
					Den.pick_up(i)
					World.refresh_den()
					Hud.pop("%s 치웠다." % Util.josa(F[d.id].name, "을", "를"), "🧹")
					_render())
			empty = "굴 안이 아직 휑하다."
	var el: Label = $Frame/Lines/Body/Empty
	el.visible = list.get_child_count() == 0 and empty != ""
	el.text = empty


func _item(id: String, extra: String, poor: bool, fn: Callable) -> void:
	var f: Dictionary = Den.furniture()[id]
	var b: Button = ITEM.instantiate()
	$Frame/Lines/Body/Scroll/List.add_child(b)
	b.get_node("Row/Info/Name").text = f.name
	b.get_node("Row/Info/Cozy").text = "아늑함 +%d%s%s" % [f.cozy, " · 벽에 건다" if f.get("wall") else "", " · 빛난다" if f.get("light") else ""]
	b.get_node("Row/Info/Extra").text = extra
	# 목록에 쓸 작은 그림. 가구마다 시트가 다르다
	var at := AtlasTexture.new()
	at.atlas = TileImages.get_texture(Den.sheet_of(f))
	var S := GameMap.TILE_SRC
	at.region = Rect2(f.tile[0] * S, f.tile[1] * S, f.span[0] * S, f.span[1] * S)
	b.get_node("Row/ThumbBox/Thumb").texture = at
	if poor: b.modulate.a = 0.45
	b.pressed.connect(fn)
