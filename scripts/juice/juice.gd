extends Node
## "Juice": pequenos efeitos que deixam cada golpe gostoso de sentir.
## Este script é um AUTOLOAD (Project Settings > Globals): o Godot cria uma
## única instância dele ao abrir o jogo, e qualquer script pode chamar `Juice.shake()`.


const RING := preload("res://resources/effects/ring.tres")
const NEON_BURST := preload("res://scenes/effects/neon_burst.tscn")
## Brilho dos efeitos: multiplica a cor para passar de 1.0 ("mais branco que o
## branco"). Só o que passa de 1.0 ganha o halo do Glow (WorldEnvironment).
const GLOW := 1.8

var _hitstops := 0
## Velocidade "normal" do jogo: 1.0, ou menos durante a câmera lenta.
## O hitstop sempre volta para ela (e não direto para 1.0).
var _base_time_scale := 1.0


## Congela o jogo por um instante (quase parado). Dá "peso" ao impacto.
func hitstop(duration := 0.06, time_scale := 0.05) -> void:
	_hitstops += 1
	Engine.time_scale = time_scale
	# O último `true` (ignore_time_scale) faz o timer contar em tempo real;
	# senão ele também ficaria em câmera lenta e o congelamento duraria 20x mais.
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstops -= 1
	if _hitstops == 0:
		Engine.time_scale = _base_time_scale


## Câmera lenta até ser desligada (1.0 = volta ao normal).
## Ex.: slow_motion(0.15) deixa tudo a 15% da velocidade.
func slow_motion(time_scale: float) -> void:
	_base_time_scale = time_scale
	if _hitstops == 0:   # se um hitstop estiver rolando, ele aplica quando acabar
		Engine.time_scale = time_scale
	Sound.set_slow_motion(time_scale < 1.0)   # música abafada na câmera lenta


## Treme a câmera atual (se ela tiver o script shake_camera.gd).
func shake(amount := 0.3) -> void:
	if not Settings.screen_shake:
		return   # o jogador desligou nas opções
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(amount)
	# No controle, a tremida também VIBRA (motor fraco + forte, proporcional).
	InputMode.vibrate(amount * 0.8, amount, 0.1 + amount * 0.25)


## Zoom rápido para dentro que volta ao normal: destaca um momento importante.
func punch(amount := 0.08) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("punch"):
		camera.punch(amount)


## Zoom mantido enquanto for pedido (0 = volta ao normal).
func focus(amount: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("set_focus"):
		camera.set_focus(amount)


## Tremor contínuo enquanto for pedido (0 = para).
func rumble(amount: float) -> void:
	if not Settings.screen_shake:
		amount = 0.0
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("set_rumble"):
		camera.set_rumble(amount)


## Deixa o sprite branco e volta ao normal. O sprite precisa usar flash.gdshader.
func flash(sprite: CanvasItem, duration := 0.15) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	var tween := sprite.create_tween()
	tween.tween_method(
		func(value: float): material.set_shader_parameter("flash", value),
		1.0, 0.0, duration)


## Explosão de pedacinhos (partículas) numa posição do mundo.
## Com `direction`, os pedaços saem num cone (`spread` graus) naquela direção.
func burst(position: Vector2, color := Color.BLACK, amount := 16,
		direction := Vector2.ZERO, spread := 180.0, max_size := 3.0, max_speed := 120.0) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0        # todas saem ao mesmo tempo
	particles.amount = amount
	particles.lifetime = 0.5
	particles.gravity = Vector2.ZERO
	if direction != Vector2.ZERO:
		particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = max_speed * 0.35
	particles.initial_velocity_max = max_speed
	particles.damping_min = max_speed * 1.2   # freiam até parar
	particles.damping_max = max_speed * 1.8
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = max_size    # quadradinhos de 1 a max_size pixels
	particles.color = color
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Explosão NEON de losangos, quadrados e triângulos pixelados.
## O visual padrão está em scenes/effects/neon_burst.tscn (Process Material >
## Shader Parameters). Com `direction`, os pedaços saem num cone de `spread` graus.
## `settings` troca parâmetros do shader SÓ nesta explosão, pelo nome. Ex.:
##   Juice.neon_burst(pos, 10, Vector2.ZERO, 180.0, {"speed_max": 80.0,
##       "weights_special": Vector3.ZERO})   # lenta e só preto/verde/branco
func neon_burst(position: Vector2, amount := 24, direction := Vector2.ZERO,
		spread := 180.0, settings := {}) -> GPUParticles2D:
	var particles := _make_neon(amount, direction, spread, settings)
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	_fire(particles)
	return particles


## Mesma explosão neon, mas DENTRO da HUD (ou de qualquer nó de interface).
## - `parent`: o nó da HUD onde ela aparece; `position` é na coordenada dele.
## - `ui_scale`: amplia a explosão (a HUD não tem o zoom da câmera).
## Usa Local Coords: as partículas herdam a posição e a escala do `parent`,
## em vez de ficarem soltas no mundo do jogo.
func neon_burst_ui(parent: Node, position: Vector2, amount := 10, direction := Vector2.ZERO,
		spread := 180.0, settings := {}, ui_scale := 1.0) -> GPUParticles2D:
	# Na HUD elas voam mais devagar: o espaço é pequeno.
	var particles := _make_neon(amount, direction, spread,
		{"speed_min": 15.0, "speed_max": 55.0}.merged(settings, true))
	particles.local_coords = true
	particles.scale = Vector2.ONE * ui_scale
	particles.position = position
	parent.add_child(particles)
	_fire(particles)
	return particles


## Cria o nó de partículas neon já configurado (sem colocar na cena).
func _make_neon(amount: int, direction: Vector2, spread: float,
		settings: Dictionary) -> GPUParticles2D:
	var particles: GPUParticles2D = NEON_BURST.instantiate()
	particles.amount = amount
	# O shader usa o ângulo do nó como direção central.
	particles.rotation = direction.angle()
	if direction != Vector2.ZERO:
		settings = settings.merged({"spread": spread})
	if not settings.is_empty():
		# Cópia do material só desta explosão, para não mudar todas as outras.
		var material := particles.process_material.duplicate() as ShaderMaterial
		for key in settings:
			material.set_shader_parameter(key, settings[key])
		particles.process_material = material
	return particles


## Dispara e apaga o nó quando todas as partículas somem.
func _fire(particles: GPUParticles2D) -> void:
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Toca um efeito (SpriteFrames com a animação "default") uma vez e apaga.
## `color` multiplica o sheet (via modulate): nos sheets já coloridos (parry,
## extração) use BRANCO; no ring.png, que é branco, `color` dá a cor.
func play_effect(frames: SpriteFrames, position: Vector2, color := Color.WHITE,
		effect_scale := 1.0, duration := 0.0) -> AnimatedSprite2D:
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	# Multiplica só o RGB (o alpha fica igual) para o efeito brilhar.
	effect.modulate = Color(color.r * GLOW, color.g * GLOW, color.b * GLOW, color.a)
	effect.scale = Vector2.ONE * effect_scale
	effect.z_index = 10
	get_tree().current_scene.add_child(effect)
	effect.global_position = position
	if duration > 0.0:
		# Ajusta a velocidade para a animação durar exatamente `duration` segundos.
		var length := frames.get_frame_count("default") / frames.get_animation_speed("default")
		effect.speed_scale = length / duration
	effect.play("default")
	effect.animation_finished.connect(effect.queue_free)
	return effect


## Anel que cresce e some (spritesheet assets/Effects/ring.png, raio final 15 px).
func ring(position: Vector2, color := Color.WHITE, max_radius := 15.0, duration := 0.25) -> void:
	play_effect(RING, position, color, max_radius / 15.0, duration)
