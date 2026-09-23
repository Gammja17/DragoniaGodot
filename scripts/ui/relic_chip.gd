extends PanelContainer
## 끼고 있는 유물 하나 (왼쪽 아래 줄). 핏줄마다 왼쪽 띠 색이 다르다 (2D판 .relic-chip.kin-*)

const KIN_COLORS := { "fang": "#ff8a6a", "scale": "#9fe07a", "wing": "#9fe3ff", "flame": "#ff9a3c" }


func setup(relic_name: String, small: String, kin) -> void:
	$Row/Name.text = relic_name
	$Row/Small.text = small
	$Row/Small.visible = small != ""
	var st: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	st.border_color = Color(KIN_COLORS.get(kin, "#d8b25a")) if kin else Color("#d8b25a")
	add_theme_stylebox_override("panel", st)
