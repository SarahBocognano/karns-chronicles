shader_type canvas_item;

// Vent pour les arbres peints en tuiles (le village) : même balancement que vent.gdshader, mais
// une tuile ne sait pas où est le pied de son arbre. Chaque tuile d'arbre reçoit donc un matériau
// qui connaît la rangée du pied de son arbre dans la planche (`foot_row`, posé par scripts/vent.gd) :
// la hauteur au-dessus du pied se lit dans les UV. Deux tuiles voisines d'un même arbre bougent
// ensemble à leur coin commun, sans couture.

uniform float amplitude = 1.3;
uniform float speed = 0.8;
uniform float gust = 0.45;
/// Rangée (dans la planche) de la tuile du pied de l'arbre.
uniform float foot_row = 0.0;
/// Pas d'une tuile dans la texture de rendu : 32 px, ou 34 avec la marge anti-bavure de Godot.
uniform float cell_px = 34.0;
/// Marge en haut de chaque tuile dans cette texture (1 px avec la marge, 0 sans).
uniform float pad_px = 1.0;

void vertex() {
	float y = UV.y / TEXTURE_PIXEL_SIZE.y - pad_px;
	// rangée de la tuile, et position dans la tuile (0 en haut, 32 en bas) ; un coin du bas
	// (y = rangée * cell + 32) reste bien dans sa rangée même avec la marge
	float row = floor((y + 0.5) / cell_px);
	float local = clamp(y - row * cell_px, 0.0, 32.0);
	float above_foot = (foot_row + 1.0 - row) * 32.0 - local;
	float height = clamp(above_foot / 100.0, 0.0, 3.0);
	float world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	float phase = world_x * 0.008;
	float wave = sin(TIME * speed + phase) + gust * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += wave * amplitude * height;
}
