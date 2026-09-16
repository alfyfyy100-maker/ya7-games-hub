// terrain.gdshader — أرض مستمرة بألوان رؤوس (vertex colors) وانتقال تدريجي، بدون بلاطات.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// تنويع لوني ناعم وواسع كي لا يبدو السطح مسطحًا بلا حياة
	float v = sin(world_pos.x * 0.31 + world_pos.z * 0.17) * sin(world_pos.z * 0.27 - world_pos.x * 0.11);
	ALBEDO = COLOR.rgb * (1.0 + 0.05 * v);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
