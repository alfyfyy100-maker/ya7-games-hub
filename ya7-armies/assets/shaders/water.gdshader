// water.gdshader — ماء كرتوني شبه شفاف مع تموّج خفيف جدًا (رخيص).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.22, 0.58, 0.92, 0.72);
uniform vec4 foam_color : source_color = vec4(0.75, 0.9, 1.0, 0.9);

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.6 + TIME * 1.2) * 0.04 + cos(VERTEX.z * 0.5 + TIME * 0.9) * 0.04;
}

void fragment() {
	vec2 uv = UV * 40.0;
	float w = sin(uv.x * 1.3 + TIME * 0.8) * sin(uv.y * 1.1 - TIME * 0.6);
	float foam = smoothstep(0.75, 0.95, w);
	ALBEDO = mix(color.rgb, foam_color.rgb, foam * 0.6);
	ALPHA = color.a;
}
