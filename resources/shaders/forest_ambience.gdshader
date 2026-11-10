shader_type canvas_item;

// Ambiance de forêt : nappes de brume qui dérivent et rayons de lumière obliques.
// À poser sur un ColorRect qui couvre toute la carte, au-dessus des arbres.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.86, 0.92, 0.86, 1.0);
/// Opacité maximale de la brume.
uniform float fog_density = 0.16;
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.72, 1.0);
/// Intensité des rayons de lumière.
uniform float ray_strength = 0.10;
/// Largeur moyenne entre deux rayons, en pixels du monde.
uniform float ray_spacing = 150.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Brume : deux couches de bruit qui glissent lentement.
	float n1 = texture(noise, world_pos / 720.0 + vec2(TIME * 0.006, TIME * 0.003)).r;
	float n2 = texture(noise, world_pos / 340.0 - vec2(TIME * 0.010, -TIME * 0.004)).r;
	float fog = smoothstep(0.42, 0.85, n1 * 0.65 + n2 * 0.35) * fog_density;

	// Rayons : bandes obliques, qui s'allument et s'éteignent doucement.
	float d = (world_pos.x + world_pos.y * 0.55) / ray_spacing;
	float band = pow(max(0.0, sin(d * 3.14159 + sin(d * 0.9) * 1.5)), 10.0);
	float pulse = texture(noise, vec2(floor(d) * 0.137, TIME * 0.015)).r;
	float rays = band * smoothstep(0.45, 0.75, pulse) * ray_strength;

	float a = clamp(fog + rays, 0.0, 1.0);
	vec3 col = mix(fog_color.rgb, ray_color.rgb, rays / max(a, 0.0001));
	COLOR = vec4(col, a);
}
