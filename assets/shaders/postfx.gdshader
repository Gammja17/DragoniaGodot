shader_type canvas_item;
// 2D판 render/postfx.js. 다 그린 세상 화면을 한 번 더 통과시킨다.
//   번짐(bloom)   밝은 픽셀만 뽑아 흐릿하게 퍼뜨려 도로 더한다 (2D판은 1/4 해상도 두 번 흐림. 여기선 고리 표본 한 번)
//   일렁임(warp)  맞은 순간 한가운데서 퍼져 나가는 물결 (Feedback.flash_amount)
//   색 어긋남      가장자리로 갈수록 R/B 가 살짝 벌어진다
//   가장자리 어둠 · 밝기 · 대비 · 채도 (2D판 조명의 비네트와, 화면 효과 판의 색 보정)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float bloom = 0.85;
uniform float threshold = 0.62;
uniform float knee = 0.28;
uniform float aberration = 1.0;
uniform float warp = 0.0;
uniform float time = 0.0;
uniform float vignette = 1.0;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;

vec3 bright(vec2 u) {
	vec3 c = texture(screen_tex, u).rgb;
	float l = max(c.r, max(c.g, c.b));
	float k = clamp((l - threshold) / knee, 0.0, 1.0);
	return c * k * k;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = length(d);
	vec2 u = uv;

	// 화면 복판은 건드리지 않아야 조준이 안 흔들린다
	if (warp > 0.002) {
		float w = sin(r * 26.0 - time * 9.0) * warp * 0.012 * smoothstep(0.0, 0.3, r);
		u += d / max(r, 0.001) * w;
	}

	float ab = (0.0010 + r * 0.0030) * (1.0 + warp * 2.0) * aberration;
	vec3 c;
	c.r = texture(screen_tex, u + d * ab).r;
	c.g = texture(screen_tex, u).g;
	c.b = texture(screen_tex, u - d * ab).b;

	if (bloom > 0.001) {
		// 반지름 5 · 11 · 21 px 고리마다 8방향. 가우스 무게 (시그마 ≈ 9px)
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 b = bright(u) * 0.16;
		float total = 0.16;
		for (int ring = 1; ring <= 3; ring++) {
			float rad = float(ring * ring) * 2.0 + 3.0;   // 5 · 11 · 21 px
			float wgt = exp(-rad * rad / 162.0) * 0.16;
			for (int i = 0; i < 8; i++) {
				float a = float(i) * 0.785398 + float(ring) * 0.39;
				b += bright(u + vec2(cos(a), sin(a)) * rad * px) * wgt;
				total += wgt;
			}
		}
		c += b / total * bloom;
	}

	// 가장자리를 살짝 어둡게 (2D판: 짧은 변의 0.35 에서 시작해 대각선 반의 0.55 까지, 최대 0.42)
	if (vignette > 0.001) {
		vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
		float dist = length((uv - 0.5) * size);
		float inner = min(size.x, size.y) * 0.35;
		float outer = length(size) * 0.55;
		float k = clamp((dist - inner) / (outer - inner), 0.0, 1.0);
		c = mix(c, vec3(8.0, 10.0, 25.0) / 255.0, clamp(k * 0.42 * vignette, 0.0, 1.0));
	}

	c *= brightness;
	c = (c - 0.5) * contrast + 0.5;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturation);
	COLOR = vec4(c, 1.0);
}
