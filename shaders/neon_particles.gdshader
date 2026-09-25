// Partículas NEON geométricas (losangos, quadrados, triângulos).
// É um shader do tipo "particles": ele NÃO desenha nada, ele decide onde cada
// partícula está, sua cor, tamanho e rotação. Quem desenha é o GPUParticles2D,
// usando a textura neon_shapes.png (6 quadros de 9x9 px, formas brancas).
//
// Regras do estilo:
// - tamanho sempre em pixels inteiros (1x, 2x, 3x) e posição presa à grade de pixels;
// - rotação só em passos de 45 graus (trocando de quadro) e 90 graus (girando);
// - nada de fade: a partícula pisca e some de uma vez.
shader_type particles;
// disable_velocity: nós mesmos movemos a partícula (para prender à grade de pixels).
render_mode disable_velocity, disable_force;

group_uniforms Cores;
// Paleta do jogo. Cada partícula sorteia UMA cor, com chance proporcional ao peso.
uniform vec4 color_black : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_green : source_color = vec4(0.224, 1.0, 0.078, 1.0);  // verde fluorescente
uniform vec4 color_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_pink : source_color = vec4(1.0, 0.039, 0.549, 1.0);   // rosa choque
uniform vec4 color_cyan : source_color = vec4(0.0, 0.941, 1.0, 1.0);
uniform vec4 color_purple : source_color = vec4(0.69, 0.149, 1.0, 1.0);
// Pesos: x/y/z = preto/verde/branco (principais) e rosa/ciano/roxo (especiais).
// 0 desliga a cor. Ex.: weights_special = (0,0,0) deixa o efeito só na paleta principal.
uniform vec3 weights_main = vec3(1.0, 1.5, 1.0);
uniform vec3 weights_special = vec3(1.0, 1.0, 1.0);
// Tempo (s) em que TODAS nascem brancas antes de ganhar cor: um "flash" de impacto.
uniform float white_time = 0.05;
// Se > 0, a partícula sorteia uma cor nova a cada X segundos (pisca entre cores).
uniform float color_cycle = 0.0;
// Brilho: multiplica a cor. Acima de 1 a cor passa do "branco" e o Glow do
// WorldEnvironment desenha um halo em volta (o preto continua preto: 0 x 1.8 = 0).
uniform float energy = 1.8;

group_uniforms Formas;
// Chance de cada forma: x = quadrado/losango cheio, y = vazado, z = triângulo.
uniform vec3 shape_weights = vec3(1.0, 1.0, 1.0);
// Tamanho em múltiplos do pixel da textura (inteiros: 1 = 9px, 2 = 18px...).
uniform int size_min = 1;
uniform int size_max = 1;
// Nos primeiros X segundos a partícula nasce 1 tamanho MAIOR (surge "estourando").
uniform float pop_time = 0.06;

group_uniforms Movimento;
// Direção: o ângulo do próprio nó GPUParticles2D (rotation). spread = abertura, em graus.
uniform float spread : hint_range(0.0, 180.0) = 180.0;
// Se > 0, as direções são "encaixadas" em múltiplos desse ângulo (45 = 8 direções).
uniform float direction_snap : hint_range(0.0, 90.0) = 45.0;
uniform float speed_min = 40.0;
uniform float speed_max = 140.0;
// Freio: quanto maior, mais rápido elas param (explodem e ficam paradas).
uniform float damping = 7.0;
// Raio (px) em volta do centro onde elas nascem.
uniform float emission_radius = 2.0;

group_uniforms Rotacao;
// A cada X segundos a partícula gira 45 graus (0 = não gira).
uniform float rotate_interval = 0.08;

group_uniforms Vida;
// Cada partícula vive entre (1 - life_randomness) e 100% do Lifetime do nó.
uniform float life_randomness : hint_range(0.0, 1.0) = 0.4;
// No último trecho da vida ela PISCA (some e volta) e então desaparece de vez.
uniform float blink_portion : hint_range(0.0, 1.0) = 0.3;
uniform float blink_interval = 0.04;


// --- Números aleatórios (a GPU não tem randf(); fazemos um "hash") ---
uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

float rand(inout uint seed) {
	seed = hash(seed);
	return float(seed % uint(65536)) / 65535.0;
}

vec4 palette(int index) {
	if (index == 0) return color_black;
	if (index == 1) return color_green;
	if (index == 2) return color_white;
	if (index == 3) return color_pink;
	if (index == 4) return color_cyan;
	return color_purple;
}

// Sorteio com pesos: `r` (0 a 1) cai numa "fatia" de tamanho proporcional ao peso.
int pick_color(float r) {
	float weights[6] = { weights_main.x, weights_main.y, weights_main.z,
			weights_special.x, weights_special.y, weights_special.z };
	float total = 0.0;
	for (int i = 0; i < 6; i++) {
		total += weights[i];
	}
	float pick = r * total;
	for (int i = 0; i < 6; i++) {
		if (pick < weights[i]) {
			return i;
		}
		pick -= weights[i];
	}
	return 2;
}


// Roda UMA vez, quando a partícula nasce.
// Dados guardados por partícula:
//   CUSTOM    = (forma, idade em s, quadro da textura, cor inicial)
//   USERDATA1 = (posição x, posição y, tamanho, duração da vida em s)
//   USERDATA2 = (passo de rotação inicial, sentido do giro, -, -)
void start() {
	uint seed = hash(NUMBER + uint(1) + RANDOM_SEED);

	// Forma, sorteada pelos pesos.
	float total = shape_weights.x + shape_weights.y + shape_weights.z;
	float pick = rand(seed) * total;
	float shape = pick < shape_weights.x ? 0.0 : (pick < shape_weights.x + shape_weights.y ? 1.0 : 2.0);

	float color_index = float(pick_color(rand(seed)));
	float size = float(size_min) + floor(rand(seed) * float(size_max - size_min + 1) * 0.999);
	float life = LIFETIME * (1.0 - life_randomness * rand(seed));

	// Direção: ângulo do nó + sorteio dentro do spread, encaixado na grade de ângulos.
	float base_angle = atan(EMISSION_TRANSFORM[0].y, EMISSION_TRANSFORM[0].x);
	float angle = base_angle + (rand(seed) * 2.0 - 1.0) * radians(spread);
	if (direction_snap > 0.0) {
		float step_size = radians(direction_snap);
		angle = round(angle / step_size) * step_size;
	}
	float speed = mix(speed_min, speed_max, rand(seed));
	VELOCITY = vec3(cos(angle), sin(angle), 0.0) * speed;

	// Posição inicial: um ponto aleatório dentro do círculo de emissão.
	float emit_angle = rand(seed) * TAU;
	vec2 position = EMISSION_TRANSFORM[3].xy
			+ vec2(cos(emit_angle), sin(emit_angle)) * emission_radius * sqrt(rand(seed));

	CUSTOM = vec4(shape, 0.0, 0.0, color_index);
	USERDATA1 = vec4(position, size, life);
	// z guarda uma "semente" própria da partícula, para sortear cores novas depois.
	USERDATA2 = vec4(floor(rand(seed) * 7.999), rand(seed) < 0.5 ? -1.0 : 1.0,
			float(seed % uint(65536)), 0.0);
	COLOR = color_white;
}


// Roda TODO quadro, para cada partícula viva.
void process() {
	float age = CUSTOM.y + DELTA;
	CUSTOM.y = age;
	float life = USERDATA1.w;
	if (age >= life) {
		ACTIVE = false;   // some de uma vez, sem fade
	}
	float t = age / life;   // 0 = nasceu, 1 = morreu

	// Movimento: freia com o tempo e a posição desenhada fica presa na grade de pixels.
	VELOCITY *= exp(-damping * DELTA);
	vec2 position = USERDATA1.xy + VELOCITY.xy * DELTA;
	USERDATA1.xy = position;

	// Tamanho em passos inteiros: nasce maior, depois normal, e encolhe no fim.
	float size = USERDATA1.z;
	if (age < pop_time) {
		size += 1.0;
	} else if (t > 0.75) {
		size = max(size - 1.0, 1.0);
	}

	// Rotação em passos de 45 graus: passos ímpares usam o quadro "a 45 graus"
	// (quadrado vira losango), e cada 2 passos gira o sprite 90 graus.
	int rotation_step = int(USERDATA2.x);
	if (rotate_interval > 0.0) {
		rotation_step += int(USERDATA2.y) * int(floor(age / rotate_interval));
	}
	rotation_step = ((rotation_step % 8) + 8) % 8;
	int frame = int(CUSTOM.x) * 2 + rotation_step % 2;
	CUSTOM.z = (float(frame) + 0.5) / 6.0;   // o CanvasItemMaterial lê o quadro daqui

	// Eixos do sprite girados em 90 * n graus (valores exatos: 0, 1 ou -1).
	int quarter = rotation_step / 2;
	vec2 x_axis = vec2(1.0, 0.0);
	if (quarter == 1) x_axis = vec2(0.0, 1.0);
	if (quarter == 2) x_axis = vec2(-1.0, 0.0);
	if (quarter == 3) x_axis = vec2(0.0, -1.0);
	x_axis *= size;
	vec2 y_axis = vec2(-x_axis.y, x_axis.x);

	// O sprite tem 9 px: com tamanho ímpar o centro fica no MEIO de um pixel.
	float pixel_offset = mod(size, 2.0) == 1.0 ? 0.5 : 0.0;
	vec2 snapped = floor(position) + pixel_offset;

	TRANSFORM = mat4(
		vec4(x_axis, 0.0, 0.0),
		vec4(y_axis, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(snapped, 0.0, 1.0));

	// Cor: flash branco no nascimento, depois a cor da paleta (sem misturar tons).
	int color_index = int(CUSTOM.w);
	if (color_cycle > 0.0) {
		uint cycle_seed = uint(USERDATA2.z) + uint(floor(age / color_cycle)) * uint(7919);
		color_index = pick_color(rand(cycle_seed));
	}
	COLOR = age < white_time ? color_white : palette(color_index);
	COLOR.rgb *= energy;

	// Pisca no fim: alterna visível / invisível.
	if (t > 1.0 - blink_portion && int(floor(age / blink_interval)) % 2 == 1) {
		COLOR.a = 0.0;
	}
}
