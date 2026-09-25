extends PlayerState
## Morreu: explode em pedaços e a fase recomeça.


const RESTART_DELAY := 1.5


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.hurtbox.invincible = true
	player.sprite.visible = false
	player.get_node("Shadow").visible = false
	Juice.burst(player.hurtbox.global_position, Color("e8457a"), 30)
	Juice.shake(0.8)
	Sound.play("death", 0.0)

	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
