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
	m.set_shader_parameter("warp", Feedback.flash_amount() * ScreenFx.value("warp"))
	m.set_shader_parameter("time", GameState.game_time)
