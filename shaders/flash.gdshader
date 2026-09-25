shader_type canvas_item;

// Pinta o sprite de uma cor sólida (branco), mantendo o formato (alpha).
// flash = 0: sprite normal | flash = 1: totalmente branco.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
	// Aqui COLOR já vem com a cor da textura; só misturamos com a cor do flash.
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
