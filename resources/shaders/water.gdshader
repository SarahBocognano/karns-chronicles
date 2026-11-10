shader_type canvas_item;

// Eau animée, dessinée sur un Polygon2D (étang, ruisseau, cascade).
// Les couleurs reprennent la palette sombre des tiles Szadi art, et l'eau est
// pixelisée (pixel_size) pour rester dans le style pixel art.

uniform vec4 deep_color : source_color = vec4(0.11, 0.22, 0.24, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.30, 0.31, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.70, 0.86, 0.82, 1.0);
/// Sens et vitesse du courant, en pixels par seconde (0,0 = eau dormante).
uniform vec2 flow = vec2(0.0, 0.0);
/// Étirement des motifs : (1,1) pour un étang, (1,6) pour une cascade.
uniform vec2 stretch = vec2(1.0, 1.0);
/// Quantité de reflets clairs (0 = aucun).
uniform float sparkle = 0.55;
/// Taille d'un « pixel » d'eau, en pixels du monde.
uniform float pixel_size = 2.0;
uniform sampler2D noise_a : repeat_enable, filter_linear;
uniform sampler2D noise_b : repeat_enable, filter_linear;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(world_pos / pixel_size) * pixel_size;
	vec2 uv1 = (p - flow * TIME) / (vec2(260.0, 260.0) * stretch) + vec2(TIME * 0.004, TIME * 0.002);
	vec2 uv2 = (p - flow * TIME * 1.2) / (vec2(120.0, 120.0) * stretch) - vec2(TIME * 0.006, 0.0);
	float n = texture(noise_a, uv1).r;
	float m = texture(noise_b, uv2).r;

	// Fond : quelques paliers de teinte (pas de dégradé lisse, pour rester pixel art).
	float tone = smoothstep(0.35, 0.75, n);
	tone = floor(tone * 3.0 + 0.5) / 3.0;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, tone);

	// Reflets : fines lignes qui suivent les courbes de niveau d'un second bruit.
	float c = abs(fract(m * 3.0 + TIME * 0.05) - 0.5);
	float ripple = step(c, 0.055) * step(0.42, n);
	col = mix(col, highlight_color.rgb, ripple * sparkle * 0.6);

	COLOR = vec4(col, COLOR.a);
}
