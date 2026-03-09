shader_type canvas_item;

uniform float scroll_offset = 0.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + scroll_offset);
	vec4 color = texture(TEXTURE, uv);
	COLOR = vec4(color.rgb * brightness, color.a);
}
