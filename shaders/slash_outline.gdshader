shader_type canvas_item;

// Recolore o slash: o desenho vira preto e ganha um contorno branco de 1 pixel.
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0);

void fragment() {
	float alpha = texture(TEXTURE, UV).a;

	// TEXTURE_PIXEL_SIZE = tamanho de 1 pixel da textura em coordenadas UV.
	// Somamos o alpha dos 4 vizinhos: se algum vizinho tem desenho, estamos na borda.
	vec2 px = TEXTURE_PIXEL_SIZE;
	float neighbors = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;

	if (alpha > 0.1) {
		COLOR = fill_color;
	} else if (neighbors > 0.1) {
		COLOR = outline_color;
	} else {
		COLOR = vec4(0.0);
	}
}
