class_name Hitbox
extends Area2D
## Área que CAUSA dano. Quando encosta numa Hurtbox, entrega o golpe para ela.
## Quais Hurtboxes ela enxerga é definido pela Collision > Mask no Inspector.
##
## Cada ativação (activate) acerta cada alvo UMA vez só, mesmo que o alvo
## saia e entre de novo na área durante o golpe.


## Emitido quando o golpe foi aceito (a Hurtbox não estava invencível nem aparando).
signal hit_landed(hurtbox: Hurtbox)

@export var damage := 1
@export var knockback_force := 150.0

## Se ficar zero, o empurrão vai do dono da Hitbox em direção ao alvo.
## Projéteis preenchem com a direção em que estão voando.
var knockback_direction := Vector2.ZERO

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Liga a Hitbox para um novo golpe (e esquece quem foi acertado no golpe anterior).
func activate() -> void:
	_already_hit.clear()
	# set_deferred: liga no fim do frame. O Godot proíbe ligar/desligar áreas
	# no meio de um sinal de colisão (ex.: tomar dano no meio do golpe).
	# Desliga e religa: assim quem JÁ estava dentro da área é detectado de novo
	# (importante no combo, quando o segundo golpe começa com a área ligada).
	set_deferred("monitoring", false)
	set_deferred("monitoring", true)


func deactivate() -> void:
	set_deferred("monitoring", false)


func get_knockback(target_position: Vector2) -> Vector2:
	var direction := knockback_direction
	if direction == Vector2.ZERO:
		var origin: Node2D = owner if owner is Node2D else self
		direction = origin.global_position.direction_to(target_position)
	return direction * knockback_force


func _on_area_entered(area: Area2D) -> void:
	if not area is Hurtbox or area in _already_hit:
		return
	_already_hit.append(area)
	if area.receive_hit(self):
		hit_landed.emit(area)
