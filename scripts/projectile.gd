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
@export_group("Parry")
## Ao ser devolvido pelo jogador: multiplica velocidade e dano.
@export var reflect_speed_multiplier := 1.8
@export var reflect_damage_multiplier := 2
## Devolvido, ele EXPLODE ao acertar: dano em área em volta do impacto.
@export var blast_radius := 22.0
@export var blast_damage := 1
@export var blast_knockback := 160.0

var direction := Vector2.RIGHT
## Quem atirou.
var shooter: Node2D
var _traveled := 0.0
var _exploding := false
## Parado na mão do jogador (durante a mira em câmera lenta).
var _held := false
## Foi devolvido pelo jogador: explode em área ao acertar.
var _explosive := false
## Quem a explosão acerta: 16 = enemy_hurtbox (devolvido), 8 = player_hurtbox (detonado).
var _blast_mask := 16

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	super()   # roda o _ready() da Hitbox (que conecta o area_entered)
	add_to_group("projectiles")   # o WaveManager limpa todos no fim da wave
	_set_direction(direction)
	sprite.play("fly")
	hit_landed.connect(func(_hurtbox: Hurtbox): _explode())
	body_entered.connect(func(_body: Node2D): _explode())   # paredes


func _physics_process(delta: float) -> void:
	if _exploding or _held:
		return
	var step := direction * speed * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_distance:
		_explode()


## PARRY, passo 1: o jogador "pega" o projétil. Ele para no ar, não acerta
## ninguém e fica na cor do jogador (brilhando), esperando a mira.
func catch(color: Color) -> void:
	_held = true
	set_deferred("monitoring", false)
	paint(color)


## Pinta o projétil inteiro de uma cor (shader de flash). Acima de 1.0 = brilha.
func paint(color: Color) -> void:
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("flash_color", Color(color.r * Juice.GLOW,
		color.g * Juice.GLOW, color.b * Juice.GLOW))
	material.set_shader_parameter("flash", 1.0)


## PARRY, passo 2 (a cada frame da mira): fica em `point`, apontando para `aim`.
func hold(point: Vector2, aim: Vector2) -> void:
	global_position = point
	_set_direction(aim)


## PARRY, passo 3: lançado na direção escolhida, mais rápido, mais forte,
## e agora acerta INIMIGOS e explode ao impacto.
func launch(new_direction: Vector2) -> void:
	_held = false
	_explosive = true
	_set_direction(new_direction)
	speed *= reflect_speed_multiplier
	damage *= reflect_damage_multiplier
	_traveled = 0.0
	collision_mask = MASK_HITS_ENEMIES
	activate()   # religa a área (e esquece quem já foi acertado)


## PARRY que deu errado: o jogador demorou para mirar e o projétil explode
## NA MÃO dele. A explosão acerta o JOGADOR (e não os inimigos).
func detonate() -> void:
	_held = false
	_explosive = true
	_blast_mask = 8   # player_hurtbox
	_explode()


func _set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	knockback_direction = direction
	sprite.rotation = direction.angle() - deg_to_rad(sprite_angle_offset_degrees)
	# A colisão tem o formato EXATO do desenho (1:1), então gira junto com ele.
	collision.rotation = sprite.rotation


func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	# set_deferred: não podemos desligar uma área no meio de um sinal de colisão.
	set_deferred("monitoring", false)
	if _explosive:
		_blast()
	sprite.rotation = 0.0
	sprite.play("hit")
	await sprite.animation_finished
	queue_free()


## Explosão: dano em área (em quem `_blast_mask` manda) + efeitos neon.
func _blast() -> void:
	var center := global_position
	# call_deferred: estamos dentro de um sinal de colisão; criar uma área nova
	# agora é proibido pelo Godot, então ela nasce no fim do frame.
	Hitbox.spawn_blast.call_deferred(get_parent(), center, blast_radius, blast_damage,
		blast_knockback, _blast_mask)
	Juice.ring(center, Palette.PINK, blast_radius, 0.25)
	Sound.play("explosion")
	Juice.ring(center, Color.WHITE, blast_radius * 0.5, 0.15)
	Juice.neon_burst(center, 14, Vector2.ZERO, 180.0,
		{"weights_main": Vector3(1.0, 0.5, 1.5), "weights_special": Vector3(2.0, 1.5, 1.0)})
	Juice.hitstop(0.06)
	Juice.shake(0.35)
