// 2D판 적 변종(서리·용암·모래 …)이 쓰던 캔버스 filter(hue-rotate · saturate · grayscale · brightness)를
// 색 행렬 하나로 합쳐 곱한다 (행렬은 Enemy.filter_matrix 가 CSS Filter Effects 명세대로 만든다).
// white: 맞은 순간 하얗게 번쩍 (2D판은 흰 사본을 필터 없이 그린다)
shader_type canvas_item;

uniform mat3 m = mat3(1.0);
uniform bool white = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = white ? vec4(1.0, 1.0, 1.0, c.a) : vec4(clamp(m * c.rgb, 0.0, 1.0), c.a);
}
