extends EnemyState
## Sendo extraído: primeiro TREME congelado (o jogador está saltando até ele),
## depois a essência é puxada para o jogador e o monstro some.


var extractor: Node2D
var absorb_time := 0.0
var absorb_left := 0.0
var _start_position := Vector2.ZERO
var _base_scale := Vector2.ONE


func enter() -> void:
	enemy.hurtbox.invincible = true
	enemy.hitbox.deactivate()
	enemy.set_deferred("collision_layer", 0)
	enemy.velocity = Vector2.ZERO
	enemy.sprite.pause()
	_base_scale = enemy.sprite.scale
	enemy.extract_mark.visible = false
	extractor = null
	# Branco "preso" no sprite enquanto é extraído.
	(enemy.sprite.material as ShaderMaterial).set_shader_parameter("flash", 0.6)


func physics_update(delta: float) -> void:
	if extractor == null:
		# Fase 1: tremendo no lugar.
		enemy.sprite.offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		return

	# Fase 2: encolhe e é puxado na direção do jogador, soltando pedaços.
	absorb_left -= delta
	var t := 1.0 - absorb_left / absorb_time
	var pull := _start_position.lerp(extractor.global_position, t * 0.6)
	enemy.global_position = pull
	enemy.sprite.scale = _base_scale * (1.0 - t)
	enemy.shadow.scale = Vector2.ONE * (1.0 - t)

	if randf() < 0.5:
		var toward := enemy.hurtbox.global_position.direction_to(extractor.global_position)
		Juice.burst(enemy.hurtbox.global_position, enemy.blood_color, 3, toward, 20.0, 2.0, 140.0)

	if absorb_left <= 0.0:
		enemy.queue_free()


## Chamado pelo Enemy.extract() quando o jogador chega.
func absorb_into(by: Node2D) -> void:
	extractor = by
	var player := by as Player
	absorb_time = player.extract_absorb_time if player else 0.5
	absorb_left = absorb_time
	_start_position = enemy.global_position
	enemy.sprite.offset = Vector2.ZERO
	Juice.burst(enemy.hurtbox.global_position, enemy.blood_color, 24, Vector2.ZERO, 180.0, 2.0, 120.0)
