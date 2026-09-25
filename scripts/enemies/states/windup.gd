extends EnemyState
## AVISO (telegraph) antes de atacar, como em Hyper Light Drifter:
## o monstro freia, treme e os olhos vão acendendo. É a deixa do jogador para
## desviar (dash) ou preparar o parry. Um golpe sem aviso é um golpe injusto.
## No fim, faz a ação escolhida no Chase (enemy.next_action).


## Nos últimos X segundos ele para de seguir o jogador com o olhar: a direção
## fica TRAVADA e dá para desviar para o lado.
const LOCK_TIME := 0.12

var time_left := 0.0


func enter() -> void:
	time_left = enemy.windup_time
	enemy.sprite.play("walk")
	enemy.sprite.pause()   # congela a pose: parece que está "segurando" o golpe
	enemy.attack_direction = enemy.direction_to_target()
	enemy.face(enemy.attack_direction)
	# Anel laranja (perigo) no corpo: "vai atacar!".
	Juice.ring(enemy.hurtbox.global_position, Palette.WARM, 10.0, enemy.windup_time)
	Sound.play("windup")


func exit() -> void:
	enemy.sprite.offset = Vector2.ZERO
	enemy.set_eye_glow(0.0)


func physics_update(delta: float) -> void:
	# Freia até parar (sem separação: ele está concentrado no golpe).
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.acceleration * delta)
	enemy.move_and_slide()

	time_left -= delta
	var progress := 1.0 - time_left / enemy.windup_time
	enemy.set_eye_glow(progress)
	# Tremida de 1 pixel que aumenta com o tempo (pixel inteiro: fica nítido).
	var shake := roundf(progress * 1.5)
	enemy.sprite.offset = Vector2(randf_range(-shake, shake), 0).round()

	if time_left > LOCK_TIME:
		enemy.attack_direction = enemy.direction_to_target()
		enemy.face(enemy.attack_direction)
	if time_left <= 0.0:
		transitioned.emit(enemy.next_action)
