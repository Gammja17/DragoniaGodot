// 2D판 systems/cutscene.js 의 어둠. 화면을 어둡게 깔고, 무대 위의 이들(나·말하는 쪽·가리키는 것·곁에 선 이들)에게만 빛 구멍을 뚫는다.
// 구멍 하나는 가운데 r·0.2 까지 온전히, 0.5 에서 85%, 1 에서 0 으로 사라지는 원 (destination-out 을 차례로 건다)
shader_type canvas_item;

uniform float dim = 0.0;
uniform vec2 centers[6];
uniform float radii[6];
uniform int count = 0;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float a = dim;
	for (int i = 0; i < count; i++) {
		float r = radii[i];
		if (r <= 0.0) continue;
		float d = distance(p, centers[i]) / r;
		float cut = d < 0.2 ? 1.0 : d < 0.5 ? mix(1.0, 0.85, (d - 0.2) / 0.3) : d < 1.0 ? mix(0.85, 0.0, (d - 0.5) / 0.5) : 0.0;
		a *= 1.0 - cut;
	}
	COLOR = vec4(6.0 / 255.0, 5.0 / 255.0, 12.0 / 255.0, a);
}
