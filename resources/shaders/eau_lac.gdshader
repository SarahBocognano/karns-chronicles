shader_type canvas_item;

// Eau du lac (tileset lac_tileset, généré avec Copilot) peinte sur un Polygon2D : la tuile d'eau
// profonde est répétée en coordonnées du monde, avec ses 4 images d'animation. Sert au ruisseau
// et à l'étang de la cascade (trop étroits pour les tuiles de rivage). `flow` fait glisser l'eau
// dans le sens du courant.

uniform sampler2D tiles : filter_nearest, repeat_disable;
/// Coin haut-gauche de la première image de la tuile d'eau, en pixels de la planche.
uniform vec2 tile_origin = vec2(0.0, 0.0);
/// Décalage d'une image à la suivante, en pixels de la planche.
uniform vec2 frame_step = vec2(32.0, 0.0);
uniform float frames = 4.0;
uniform float fps = 3.0;
uniform float tile_size = 32.0;
/// Sens et vitesse du courant, en pixels par seconde (0,0 = eau dormante).
uniform vec2 flow = vec2(0.0, 0.0);
/// L'eau s'arrête sous cette ligne ondulée (pixels du monde) : le bord d'une chute d'eau, la même
/// ligne que dans chute_lac.gdshader. Très grand : pas de coupure.
uniform float cut_y = 1000000.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 wp = floor(world_pos);
	if (wp.y >= cut_y + floor(1.5 * sin(wp.x * 0.45 + TIME * 2.0) + 0.5)) {
		discard;
	}
	vec2 p = floor(world_pos - flow * TIME);
	vec2 local = mod(p, tile_size);
	float f = floor(mod(TIME * fps, frames));
	vec2 px = tile_origin + frame_step * f + local + 0.5;
	vec4 col = texture(tiles, px / vec2(textureSize(tiles, 0)));
	COLOR = vec4(col.rgb, col.a * COLOR.a);
}
