shader_type canvas_item;

// Vent : le haut d'un arbre, d'un buisson ou d'une touffe d'herbe se balance doucement, le pied ne
// bouge pas. Chaque plante a son propre rythme (déphasage selon sa position dans la carte).
// Le sprite doit avoir son pied à l'origine (offset vers le haut), comme ceux des générateurs de cartes.

// Balancement au sommet, en pixels, pour 100 px de hauteur.
uniform float amplitude = 1.4;
// Vitesse du balancement.
uniform float speed = 1.3;
// Petites rafales (0 : balancement régulier).
uniform float gust = 0.45;

void vertex() {
	// 0 au pied, de plus en plus fort en montant (VERTEX.y est négatif au-dessus du pied)
	float height = clamp(-VERTEX.y / 100.0, 0.0, 3.0);
	float origin_x = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).x;
	float phase = origin_x * 0.045;
	float wave = sin(TIME * speed + phase) + gust * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += wave * amplitude * height;
}
