shader_type canvas_item;

// Transition vers un combat : l'image de la carte tourbillonne, se pixelise
// puis plonge dans le noir. `progress` va de 0 à 1.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 screen_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv * vec2(screen_size.x / screen_size.y, 1.0));
	float angle = progress * 7.0 * max(0.0, 1.0 - r);
	float s = sin(angle);
	float c = cos(angle);
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
	uv *= 1.0 - progress * 0.55;
	float px = mix(1.0, 40.0, progress * progress);
	vec2 cells = screen_size / px;
	vec2 suv = (floor((uv + 0.5) * cells) + 0.5) / cells;
	vec4 col = texture(TEXTURE, suv);
	col.rgb *= 1.0 - smoothstep(0.45, 1.0, progress);
	COLOR = vec4(col.rgb, 1.0);
}
