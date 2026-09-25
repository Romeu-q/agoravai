extends EnemyState
## Aparece "teleportando". Invencível e inofensivo até a animação acabar:
## isso avisa o jogador (telegraph) antes do monstro virar uma ameaça.


func enter() -> void:
	enemy.hurtbox.invincible = true
	enemy.sprite.play("spawn")
	Sound.play("spawn")


func exit() -> void:
	enemy.hurtbox.invincible = false


func physics_update(_delta: float) -> void:
	if not enemy.sprite.is_playing():
		transitioned.emit(&"chase")
