class_name Projectile
extends Hitbox
## Projétil genérico: voa em linha reta e explode ao acertar algo ou ao passar
## do alcance. Como HERDA de Hitbox, já sabe causar dano e empurrar.
## Quem ele acerta depende da Collision Mask; quem atira escolhe antes de adicionar à cena.


## Máscaras prontas (soma dos bits das camadas):
## world = 1, player_hurtbox = 8, enemy_hurtbox = 16.
const MASK_HITS_PLAYER := 1 + 8
const MASK_HITS_ENEMIES := 1 + 16

@export var speed := 160.0
@export var max_distance := 220.0
## O desenho do projétil aponta para baixo-direita (45°), então descontamos isso ao girar.
@export var sprite_angle_offset_degrees := 45.0
## Ao ser rebatido (parry): multiplica velocidade e dano.
@export var reflect_speed_multiplier := 1.8
@export var reflect_damage_multiplier := 2

var direction := Vector2.RIGHT
## Quem atirou (para onde o projétil volta ao ser rebatido).
var shooter: Node2D
var _traveled := 0.0
var _exploding := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()   # roda o _ready() da Hitbox (que conecta o area_entered)
	add_to_group("projectiles")   # o WaveManager limpa todos no fim da wave
	_set_direction(direction)
	sprite.play("fly")
	hit_landed.connect(func(_hurtbox: Hurtbox): _explode())
	body_entered.connect(func(_body: Node2D): _explode())   # paredes


func _physics_process(delta: float) -> void:
	if _exploding:
		return
	var step := direction * speed * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_distance:
		_explode()


## Chamado quando o jogador apara o projétil: volta para quem atirou,
## mais rápido, mais forte e na cor do jogador.
func reflect(color: Color) -> void:
	if is_instance_valid(shooter):
		_set_direction(global_position.direction_to(shooter.global_position + Vector2(0, -10)))
	else:
		_set_direction(-direction)
	speed *= reflect_speed_multiplier
	damage *= reflect_damage_multiplier
	_traveled = 0.0
	_already_hit.clear()
	# Agora ele acerta inimigos (e não mais o jogador).
	set_deferred("collision_mask", MASK_HITS_ENEMIES)

	# Pinta o projétil usando o shader de flash com a cor do chifre.
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)


func _set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	knockback_direction = direction
	sprite.rotation = direction.angle() - deg_to_rad(sprite_angle_offset_degrees)


func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	# set_deferred: não podemos desligar uma área no meio de um sinal de colisão.
	set_deferred("monitoring", false)
	sprite.rotation = 0.0
	sprite.play("hit")
	await sprite.animation_finished
	queue_free()
