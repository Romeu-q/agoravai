extends Node
## "Juice": pequenos efeitos que deixam cada golpe gostoso de sentir.
## Este script é um AUTOLOAD (Project Settings > Globals): o Godot cria uma
## única instância dele ao abrir o jogo, e qualquer script pode chamar `Juice.shake()`.


const RING := preload("res://resources/effects/ring.tres")

var _hitstops := 0


## Congela o jogo por um instante (quase parado). Dá "peso" ao impacto.
func hitstop(duration := 0.06, time_scale := 0.05) -> void:
	_hitstops += 1
	Engine.time_scale = time_scale
	# O último `true` (ignore_time_scale) faz o timer contar em tempo real;
	# senão ele também ficaria em câmera lenta e o congelamento duraria 20x mais.
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstops -= 1
	if _hitstops == 0:
		Engine.time_scale = 1.0


## Treme a câmera atual (se ela tiver o script shake_camera.gd).
func shake(amount := 0.3) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(amount)


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


## Toca um efeito (SpriteFrames com a animação "default") uma vez e apaga.
## Os efeitos em assets/Effects são BRANCOS: `color` pinta eles (via modulate).
func play_effect(frames: SpriteFrames, position: Vector2, color := Color.WHITE,
		effect_scale := 1.0, duration := 0.0) -> AnimatedSprite2D:
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.modulate = color
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
