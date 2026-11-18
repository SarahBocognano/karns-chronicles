shader_type canvas_item;

// Sceau magique des Yrenn : un voile de lumière bleue tendu dans l'embrasure de la porte.
// Le haut est arrondi en arche ; des vagues montent doucement et des runes s'allument au hasard.
// Calculé par « pixels » de 1 px du monde, pour rester dans le style pixel art.

// Taille du voile en pixels (celle du ColorRect).
uniform vec2 size = vec2(30.0, 44.0);
// 1 : sceau intact, 0 : dissipé. `flash` éclaire tout le voile (au moment où il se brise).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * size);
	float r = size.x * 0.5;
	if (p.y < r && distance(p + 0.5, vec2(r, r)) > r) {
		discard;   // au-dessus de l'arche
	}
	float wave = sin(p.y * 0.38 + TIME * 2.2 + sin(p.x * 0.45 + TIME * 0.9) * 1.6) * 0.5 + 0.5;
	float rune = step(0.95, hash(floor(p / 3.0) + floor(TIME * 2.5)));
	// bord du voile un peu plus vif
	float d_side = min(p.x, size.x - 1.0 - p.x);
	float edge = 1.0 - smoothstep(0.0, 3.0, d_side);
	vec3 col = mix(vec3(0.22, 0.50, 0.92), vec3(0.72, 0.93, 1.0), clamp(wave * 0.55 + rune * 0.9 + edge * 0.4, 0.0, 1.0));
	col = mix(col, vec3(1.0), flash);
	float a = (0.38 + 0.22 * wave + rune * 0.4 + edge * 0.2) * strength;
	COLOR = vec4(col, clamp(a + flash * strength, 0.0, 1.0));
}
