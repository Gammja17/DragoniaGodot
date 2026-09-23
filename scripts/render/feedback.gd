class_name Feedback
extends Node2D
## 2D판 render/feedback.js. 타격감.
##
## 맞고 때릴 때 화면이 아무 반응을 하지 않으면, 숫자만 줄어드는 표 같아진다.
##   hit_stop(t)   맞은 순간 세상이 아주 잠깐 멈춘다 (때린 맛의 팔 할이 이것이다)
##   flash(a, c)   화면이 한 번 번쩍한다 (내가 맞았을 때는 붉게)
##   이 노드        위험할 때 화면 가장자리가 붉게 맥박친다 (화면 좌표 층에 둔다)

static var _stop := 0.0          # 남은 멈춤 시간(실시간 초)
static var _flash_a := 0.0       # 번쩍임 세기
static var _flash_color := Color8(255, 90, 80)

var _vignette: GradientTexture2D


## 맞은 순간 아주 잠깐 멈춘다. 0.04~0.12초면 충분하다
static func hit_stop(t := 0.06) -> void:
	_stop = maxf(_stop, t)


## 화면이 한 번 번쩍한다
static func flash(a := 0.3, color := Color8(255, 90, 80)) -> void:
	_flash_a = maxf(_flash_a, a)
	_flash_color = color


## 매 프레임 부른다. 멈춰 있는 동안에는 dt 를 거의 0 으로 만들어 돌려준다
## (완전히 0 으로 만들면 애니메이션이 얼어붙어 어색하다)
static func apply_hit_stop(dt: float) -> float:
	if _stop <= 0: return dt
	_stop -= dt
	return dt * 0.12


static func update(dt: float) -> void:
	_flash_a = maxf(0, _flash_a - dt * 3.4)


## 지금 번쩍임 세기 (후처리가 화면을 일렁이게 할 때 쓴다)
static func flash_amount() -> float:
	return _flash_a


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var p = GameState.player
	# 1) 위험할 때 가장자리가 붉게 맥박친다
	if p and GameState.gameActive and p.hp > 0:
		var danger := 1 - minf(1, p.hp / (p.max_hp * 0.4))
		if danger > 0.02:
			var pulse := 0.55 + sin(GameState.game_time * 6) * 0.45
			# 원이 화면 비율에 눌리지 않게 정사각형 그림을 화면 가운데에 크게 편다 (반지름 = 바깥 원)
			var outer := maxf(size.x, size.y) * 0.72
			draw_texture_rect(_vignette_tex(minf(size.x, size.y) * 0.32 / outer), Rect2(size / 2 - Vector2(outer, outer), Vector2(outer, outer) * 2), false, Color(1, 1, 1, 0.72 * danger * pulse))
	# 2) 맞은 순간의 번쩍임
	if _flash_a > 0.004:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, _flash_a * 0.42))
	# 3) 퀘스트 목표가 화면 밖이면 가장자리에 방향 화살표 (2D판도 번쩍임 다음에 그렸다)
	if p: Guide.draw_edge(self, size.x, size.y)


## 가운데는 비고 가장자리로 갈수록 붉은 원형 그러데이션. inner: 안쪽 원 / 바깥 원
func _vignette_tex(inner: float) -> Texture2D:
	if _vignette == null or not is_equal_approx(_vignette.gradient.offsets[0], inner):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([inner, 1.0])
		g.colors = PackedColorArray([Color(180 / 255.0, 20 / 255.0, 20 / 255.0, 0), Color(190 / 255.0, 18 / 255.0, 18 / 255.0, 1)])
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.width = 256; _vignette.height = 256
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.0, 0.5)
	return _vignette
