extends PlayerState
## Cura estilo Hollow Knight: segure o botão parado por `heal_time` segundos.
## Soltar antes cancela; tomar dano interrompe (o Player troca para Hurt).
## Juice: enquanto segura, a câmera aproxima (focus) e treme cada vez mais (rumble).


## Quanto a câmera aproxima no fim da carga (0.25 = 25% mais perto).
const MAX_FOCUS := 0.25
const MAX_RUMBLE := 0.3

var time_left := 0.0


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.sprite.play("idle")
	player.heal_particles.emitting = true   # partículas sendo "puxadas" para o corpo
	time_left = player.heal_time


func exit() -> void:
	player.heal_particles.emitting = false
	player.set_glow(0.0)
	Juice.focus(0.0)    # câmera volta ao zoom normal (suavemente)
	Juice.rumble(0.0)


func physics_update(delta: float) -> void:
	if not Input.is_action_pressed("heal"):
		transitioned.emit(&"idle")   # soltou: cancela sem gastar alma
		return

	time_left -= delta
	var progress := 1.0 - time_left / player.heal_time
	player.set_glow(progress * 0.7)          # vai ficando branco enquanto carrega
	Juice.focus(progress * MAX_FOCUS)        # câmera vai aproximando
	Juice.rumble(progress * MAX_RUMBLE)      # e tremendo cada vez mais

	if time_left <= 0.0:
		player.heal()
		var center := player.hurtbox.global_position
		Juice.flash(player.sprite, 0.3)
		Juice.ring(center, player.horn_color, 18.0, 0.3)
		Juice.ring(center, Color.WHITE, 10.0, 0.2)
		Juice.burst(center, Color.WHITE, 18, Vector2.UP, 70.0, 2.0, 110.0)
		Juice.shake(0.45)   # a cura "estoura"
		Juice.punch(0.08)

		# Segurando ainda e com alma sobrando? Cura de novo em sequência.
		if player.can_heal():
			time_left = player.heal_time
		else:
			transitioned.emit(&"idle")
