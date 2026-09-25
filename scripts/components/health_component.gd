class_name HealthComponent
extends Node
## Guarda a vida de quem o usa (Player, inimigos...). Só cuida dos NÚMEROS:
## o que acontece ao tomar dano ou morrer é decidido pelo dono, ouvindo os sinais.


signal health_changed(health: int, max_health: int)
signal died

@export var max_health := 3

var health: int


func _ready() -> void:
	health = max_health


func is_dead() -> bool:
	return health <= 0


func is_full() -> bool:
	return health >= max_health


func heal(amount: int) -> void:
	if is_dead():
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func damage(amount: int) -> void:
	if is_dead():
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if is_dead():
		died.emit()
