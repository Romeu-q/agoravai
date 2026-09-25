shader_type canvas_item;

// Shader do Player: troca a cor do chifre (PALETTE SWAP) e faz o flash branco.

// Cor original do chifre nas sheets (#6FDF93) e a cor nova que vai no lugar.
uniform vec4 horn_source : source_color = vec4(0.435, 0.875, 0.576, 1.0);
uniform vec4 horn_color : source_color = vec4(0.435, 0.875, 0.576, 1.0);
// Quão parecida uma cor precisa ser com horn_source para ser trocada.
uniform float tolerance = 0.08;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (distance(tex.rgb, horn_source.rgb) < tolerance) {
		COLOR.rgb = horn_color.rgb;
	}
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
