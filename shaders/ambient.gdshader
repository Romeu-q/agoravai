shader_type canvas_item;

// "Iluminação" do cenário: tira a cor e escurece o chão, puxando para um tom
// frio (verde-petróleo), como a noite do Hyper Light Drifter.
// Fica SÓ no TileMapLayer: personagens e efeitos continuam claros,
// e é isso que faz o neon saltar do fundo (sem precisar de contorno).

// Cor que multiplica tudo (escura e fria).
uniform vec4 tint : source_color = vec4(0.30, 0.45, 0.48, 1.0);
// 0 = cinza total, 1 = cores originais do tileset.
uniform float saturation : hint_range(0.0, 1.0) = 0.35;
// Multiplicador geral de brilho (1 = só o tint).
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// Luminância: quanto "claro" o pixel é para o olho humano.
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(gray), color.rgb, saturation);
	color.rgb *= tint.rgb * brightness;
	COLOR = color;
}
