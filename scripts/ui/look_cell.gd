class_name LookCell
extends Button
## 새 용 만들기의 외형 한 칸. 고른 칸은 금테와 옅은 금빛 바탕 (2D판 #c-gallery canvas.selected)

var value := {}          # { species, look }
var look_name := ""
var _sel_style: StyleBoxFlat
var _plain := {}


func _ready() -> void:
	for s in ["normal", "hover", "pressed"]: _plain[s] = get_theme_stylebox(s)


func setup(v: Dictionary, nm: String, colors: Dictionary) -> void:
	value = v
	look_name = nm
	tooltip_text = nm
	var portrait: Control = $Portrait
	portrait.sheet = DragonSprites.get_sheet(v.species, colors, int(v.look))
	portrait.queue_redraw()


func set_selected(on: bool) -> void:
	if on:
		if not _sel_style:
			_sel_style = StyleBoxFlat.new()
			_sel_style.bg_color = Color(1, 216 / 255.0, 74 / 255.0, 0.16)
			_sel_style.set_border_width_all(2)
			_sel_style.border_color = Color("#ffd84a")
		for s in ["normal", "hover", "pressed"]: add_theme_stylebox_override(s, _sel_style)
	else:
		for s in ["normal", "hover", "pressed"]: add_theme_stylebox_override(s, _plain[s])
