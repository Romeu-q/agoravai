extends PlayerState
## CHEGADA (estado inicial): o jogador ainda não está no mapa. Um laser
## geométrico desce do céu até o ponto de spawn; quando ele some, o jogador
## aparece fazendo a animação "attack" (sem o slash) e aí o jogo é dele.
## Enquanto isso fica invisível, invencível e ignora os controles.


const LASER_SCENE := preload("res://scenes/effects/laser_beam.tscn")

var landed := false


func enter() -> void:
	landed = false
	player.velocity = Vector2.ZERO
	player.sprite.visible = false
	player.get_node("Shadow").visible = false
	player.hurtbox.invincible = true
	# call_deferred: este é o estado INICIAL, e ele começa enquanto a cena Game
	# ainda está montando os filhos; nessa hora o Godot recusa add_child nela.
	_spawn_laser.call_deferred()


func _spawn_laser() -> void:
	var laser: LaserBeam = LASER_SCENE.instantiate()
	# Filho do MUNDO (não do Player), na altura do corpo do sprite.
	player.get_parent().add_child(laser)
	laser.global_position = player.sprite.global_position
	laser.finished.connect(_on_laser_finished)


func exit() -> void:
	player.sprite.visible = true
	player.get_node("Shadow").visible = true
	player.hurtbox.invincible = false
	player.clear_input_buffer()   # cliques feitos durante a chegada não contam


func physics_update(_delta: float) -> void:
	# Depois de aparecer, espera a animação de ataque terminar.
	if landed and not player.sprite.is_playing():
		transitioned.emit(&"idle")


func _on_laser_finished() -> void:
	landed = true
	player.sprite.visible = true
	player.get_node("Shadow").visible = true
	# Só a animação do CORPO: o SlashEffect (o arco) continua escondido.
	player.sprite.stop()
	player.sprite.play("attack")

	var center := player.hurtbox.global_position
	Sound.play("arrive", 0.0)
	Juice.flash(player.sprite, 0.35)
	Juice.ring(center, Color.WHITE, 16.0, 0.3)
	Juice.ring(center, Palette.GREEN, 9.0, 0.2)
	Juice.neon_burst(center, 16, Vector2.ZERO, 180.0,
		{"weights_main": Vector3(1.0, 2.0, 1.5), "weights_special": Vector3(0.5, 1.0, 0.3)})
	Juice.hitstop(0.06)
	Juice.shake(0.35)
	Juice.punch(0.1)
