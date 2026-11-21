shader_type canvas_item;

// La chute d'eau de la cascade, dans le style de l'eau du lac (tileset lac_tileset) : même tuile
// d'eau profonde, étirée en hauteur et qui tombe vite, éclaircie, avec des filets d'écume
// verticaux. Au-dessus de `top` (le bord de la falaise), l'eau est dessinée exactement comme le
// ruisseau (eau_lac.gdshader, même courant) pour que les deux se raccordent sans couture ; au
// bord, une lèvre claire et ondulée montre l'eau qui bascule. Le ruisseau, lui, s'arrête sur
// la même ligne ondulée (son paramètre `cut_y`).

uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform vec2 tile_origin = vec2(0.0, 0.0);
uniform vec2 frame_step = vec2(32.0, 0.0);
uniform float frames = 4.0;
uniform float fps = 3.0;
uniform float tile_size = 32.0;
/// Courant du ruisseau juste au-dessus de la chute (le même que celui du ruisseau).
uniform vec2 stream_flow = vec2(0.0, 16.0);
/// Bord de la falaise, en pixels du monde : la chute commence ici.
uniform float top = 208.0;
/// Bords gauche et droit de la chute (un peu assombris), en pixels du monde.
uniform float left = 290.0;
uniform float right = 350.0;
/// Vitesse de chute, en pixels par seconde.
uniform float fall_speed = 80.0;
/// Étirement vertical de la tuile d'eau dans la chute.
uniform float stretch = 0.35;
uniform vec4 foam : source_color = vec4(0.86, 0.95, 0.93, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

vec4 water(vec2 p) {
	vec2 local = mod(p, tile_size);
	float f = floor(mod(TIME * fps, frames));
	vec2 px = tile_origin + frame_step * f + local + 0.5;
	return texture(tiles, px / vec2(textureSize(tiles, 0)));
}

/// Ligne du bord, qui ondule doucement (la même dans eau_lac.gdshader).
float brink(float x) {
	return top + floor(1.5 * sin(x * 0.45 + TIME * 2.0) + 0.5);
}

void fragment() {
	vec2 wp = floor(world_pos);
	float d = wp.y - brink(wp.x);
	vec3 col;
	if (d < 0.0) {
		// au-dessus du bord : le ruisseau, à l'identique
		col = water(floor(world_pos - stream_flow * TIME)).rgb;
	} else {
		col = water(vec2(wp.x, floor((wp.y - fall_speed * TIME) * stretch))).rgb;
		col = mix(col, foam.rgb, 0.16);
		// filets d'écume : certaines colonnes de 2 px portent des traits qui tombent plus vite
		float h = hash(floor(wp.x / 2.0) + 3.0);
		float s = fract((wp.y - fall_speed * 1.4 * TIME) / (36.0 + 70.0 * h) + h * 7.0);
		float streak = step(s, 0.28) * step(0.5, h);
		col = mix(col, foam.rgb, streak * 0.5);
		// la lèvre : l'eau qui bascule, très claire sur 2 px puis plus douce sur 4 px
		if (d < 2.0) {
			col = mix(col, foam.rgb, 0.75);
		} else if (d < 6.0) {
			col = mix(col, foam.rgb, 0.32);
		}
		// bords de la chute plus sombres
		float side = min(wp.x - left, right - 1.0 - wp.x);
		if (side < 3.0) {
			col *= 0.78;
		}
	}
	COLOR = vec4(col, COLOR.a);
}
