// toon.gdshader — إضاءة كرتونية مسطحة (بدون ظلال ديناميكية). خفيف على الموبايل.
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.08;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
