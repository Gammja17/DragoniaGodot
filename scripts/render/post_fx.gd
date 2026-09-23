class_name PostFx
extends ColorRect
## 후처리 층. 화면 전체를 덮는 사각형 하나가 셰이더(assets/shaders/postfx.gdshader)로 아래 층들을 다시 그린다.
## 값은 화면 효과 판(ScreenFx)에서, 일렁임은 맞은 순간의 번쩍임(Feedback)에서 온다.


func _process(_dt: float) -> void:
	visible = ScreenFx.value("post")
	if not visible: return
	var m := material as ShaderMaterial
	for k in ["bloom", "threshold", "aberration", "vignette", "brightness", "contrast", "saturation"]:
		m.set_shader_parameter(k, ScreenFx.value(k))
	# 컷씬이 고른 화면 색 (회상은 바랜 색, 슬픔은 색이 빠진다). 설정 값 위에 곱한다
	var tone: Dictionary = Cutscene.tone
	m.set_shader_parameter("saturation", ScreenFx.value("saturation") * tone.sat)
	m.set_shader_parameter("vignette", ScreenFx.value("vignette") * tone.vig)
	m.set_shader_parameter("brightness", ScreenFx.value("brightness") * tone.bri)
	m.set_shader_parameter("contrast", ScreenFx.value("contrast") * tone.con)
	m.set_shader_parameter("warp", Feedback.flash_amount() * ScreenFx.value("warp"))
	m.set_shader_parameter("time", GameState.game_time)
