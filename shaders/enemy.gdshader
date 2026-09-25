shader_type canvas_item;

// Shader dos monstros: o corpo escuro some no cenário e só os pontos CLAROS
// (olhos, dentes) aparecem, brilhando como no Hyper Light Drifter.
// Também faz o flash branco ao levar dano (igual ao flash.gdshader).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// Pixels mais claros que isso contam como "olho/dente" (0 = preto, 1 = branco).
uniform float eye_threshold : hint_range(0.0, 1.0) = 0.5;
// Quanto os olhos brilham. Acima de 1 a cor passa do branco e o Glow do
// WorldEnvironment cria o halo de luz em volta.
uniform float eye_energy = 2.5;

void fragment() {
	vec4 color = COLOR;   // já vem com a cor da textura
	float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	if (brightness > eye_threshold) {
		color.rgb *= eye_energy;
	}
	color.rgb = mix(color.rgb, flash_color.rgb, flash);
	COLOR = color;
}
