extends PlayerState
## Extração (inspirada na ult do Viego / Bel'Veth): salta até um inimigo com
## 1 de vida, arranca a essência dele e absorve (ganha alma).
## Duas FASES dentro do mesmo estado: LEAP (salto) e ABSORB (absorção).


enum Phase { LEAP, ABSORB }

const EXTRACT_BURST := preload("res://resources/effects/extract_burst.tres")
const MAX_LEAP_TIME := 0.3
## Quanto o sprite sobe para flutuar acima do monstro (px).
const FLOAT_HEIGHT := 34.0

var phase := Phase.LEAP
var target: Enemy
var time_left := 0.0
var _sprite_base_y := 0.0
var _particles_base_y := 0.0
var _float_time := 0.0


func enter() -> void:
	target = player.extract_target
	phase = Phase.LEAP
	time_left = MAX_LEAP_TIME
	_sprite_base_y = player.sprite.position.y
	_particles_base_y = player.heal_particles.position.y
	_float_time = 0.0
	player.set_extracting(true)   # invencível durante toda a extração
	player.sprite.play("extract")
	player.update_facing(player.global_position.direction_to(target.global_position))

	# Sobe o SPRITE (não o corpo): a sombra fica no chão e parece que ele voa.
	var tween := player.create_tween()
	tween.tween_property(player.sprite, "position:y", _sprite_base_y - FLOAT_HEIGHT, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# O inimigo congela JÁ (antes do jogador chegar), para o salto não errar.
	target.start_extraction()
	player.set_trail(true)
	Juice.hitstop(0.1, 0.05)
	Juice.punch(0.08)
	Sound.play("extract_leap")


func exit() -> void:
	player.set_extracting(false)
	player.set_trail(false)
	player.heal_particles.emitting = false
	player.heal_particles.position.y = _particles_base_y
	player.set_glow(0.0)
	# Desce de volta ao chão.
	var tween := player.create_tween()
	tween.tween_property(player.sprite, "position:y", _sprite_base_y, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func physics_update(delta: float) -> void:
	match phase:
		Phase.LEAP:
			_leap(delta)
		Phase.ABSORB:
			_absorb(delta)


func _leap(delta: float) -> void:
	if not is_instance_valid(target):
		transitioned.emit(&"idle")
		return

	# Vai até EM CIMA do monstro (mesma posição no chão; o sprite está no alto).
	var to_target := target.global_position - player.global_position
	var step := player.extract_leap_speed * delta
	if to_target.length() <= step:
		player.global_position = target.global_position
	else:
		player.velocity = to_target.normalized() * player.extract_leap_speed
		player.move_and_slide()

	time_left -= delta
	if player.global_position.distance_to(target.global_position) < 2.0 or time_left <= 0.0:
		_start_absorb()


func _start_absorb() -> void:
	phase = Phase.ABSORB
	player.set_trail(false)
	time_left = player.extract_absorb_time
	player.velocity = Vector2.ZERO
	player.heal_particles.position.y = _particles_base_y - FLOAT_HEIGHT
	player.heal_particles.emitting = true
	target.extract(player)
	Sound.play("extract_absorb", 0.0)
	# Sheet já colorido (neon): modulate branco para manter as cores originais.
	Juice.play_effect(EXTRACT_BURST, target.hurtbox.global_position, Color.WHITE,
		1.0, player.extract_absorb_time)
	Juice.shake(0.4)
	Juice.punch(0.15)


func _absorb(delta: float) -> void:
	time_left -= delta
	player.set_glow(0.7 * (1.0 - time_left / player.extract_absorb_time))
	# Flutuando: sobe e desce devagar enquanto absorve.
	_float_time += delta
	player.sprite.position.y = _sprite_base_y - FLOAT_HEIGHT + sin(_float_time * 8.0) * 1.5
	if time_left <= 0.0:
		player.add_soul(player.extract_soul)
		player.health.heal(player.extract_heal)
		_explode()
		transitioned.emit(&"idle")


## Explosão em círculo: dano + knockback em todos os monstros em volta.
func _explode() -> void:
	var center := player.hurtbox.global_position
	Hitbox.spawn_blast(player.get_parent(), center, player.extract_blast_radius,
		player.extract_blast_damage, player.extract_blast_knockback, 16)   # 16 = enemy_hurtbox

	Juice.flash(player.sprite, 0.3)
	Sound.play("extract_blast")
	Juice.ring(center, player.horn_color, player.extract_blast_radius, 0.3)
	Juice.ring(center, Color.WHITE, player.extract_blast_radius * 0.6, 0.2)
	Juice.neon_burst(center, 22)
	Juice.hitstop(0.08)
	Juice.shake(0.45)
	Juice.punch(0.1)
