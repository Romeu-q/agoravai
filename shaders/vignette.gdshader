shader_type canvas_item;

// Vinheta: escurece as bordas da tela e empurra o olhar para o centro.
// Vai num ColorRect que cobre a tela toda, dentro de um CanvasLayer.
//
// Versão suave: o escurecimento segue uma curva (smoothstep) e acompanha o
// formato da tela (oval, não um círculo), então fica quase imperceptível no
// meio e só "fecha" de verdade nos cantos.

uniform vec4 color : source_color = vec4(0.02, 0.06, 0.07, 1.0);
// Onde começa a escurecer (0 = centro, 1 = borda da tela).
uniform float inner : hint_range(0.0, 1.5) = 0.55;
// Onde chega no máximo (passe de 1.0 para os cantos ficarem mais escuros que as bordas).
uniform float outer : hint_range(0.0, 2.0) = 1.35;
// Opacidade máxima.
uniform float strength : hint_range(0.0, 1.0) = 0.6;
// 0 = segue a tela (oval), 1 = círculo perfeito.
uniform float roundness : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// De -1 a 1 nos dois eixos: a borda da tela vale 1 (oval que encaixa na tela).
	vec2 from_center = (UV - 0.5) * 2.0;
	// Corrige parcialmente para círculo usando a proporção da tela.
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	from_center.x *= mix(1.0, size.x / size.y, roundness);
	float distance = length(from_center);
	// smoothstep: começa e termina devagar (sem "degrau" visível).
	float amount = smoothstep(inner, outer, distance);
	COLOR = vec4(color.rgb, amount * strength);
}
