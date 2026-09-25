class_name Player
extends CharacterBody2D
## O Player guarda os DADOS e as AÇÕES básicas do personagem.
## QUANDO usar cada ação quem decide são os estados (scripts/player/states/).


## Emitido quando a alma muda (a HUD escuta para desenhar o medidor).
signal soul_changed(soul: int, max_soul: int)

@export var speed := 100.0
## Cor do chifre do capacete. O slash e os projéteis rebatidos usam a mesma cor.
## O bloco `set(value):` é um SETTER: roda sempre que a variável muda,
## inclusive quando você mexe no Inspector com o jogo rodando.
@export var horn_color := Color("6fdf93"):
	set(value):
		horn_color = value
		if is_node_ready():
			_apply_horn_color()

@export_group("Dash")
@export var dash_speed := 300.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.3

@export_group("Attack")
@export var attack_lunge_speed := 45.0
@export var attack_cooldown := 0.05
## Depois de um golpe, quanto tempo um novo clique ainda conta como combo (golpe de volta).
@export var attack_combo_window := 0.3
## A partir de que fração da animação dá para emendar o próximo golpe (0 a 1).
@export var attack_chain_ratio := 0.55

@export_group("Parry")
## Janela (em segundos) em que um golpe recebido é aparado.
@export var parry_window := 0.18
## Duração total do parry (janela + tempo vulnerável depois).
@export var parry_duration := 0.4
@export var parry_cooldown := 0.2
@export var parry_soul := 22
## Depois de um parry certo, a guarda fica ativa pelo menos este tempo
## (é o que permite rebater vários projéteis com 1 parry).
@export var parry_extend_window := 0.3

@export_group("Extract")
## Inimigos com 1 de vida podem ser "extraídos" (como a ult do Viego / Bel'Veth).
@export var extract_range := 110.0
@export var extract_leap_speed := 420.0
@export var extract_absorb_time := 0.5
@export var extract_soul := 33
@export var extract_heal := 1
@export var extract_blast_radius := 40.0
@export var extract_blast_damage := 1
@export var extract_blast_knockback := 240.0

@export_group("Heal")
## Como no Hollow Knight: acertar inimigos enche a alma; alma cura.
@export var max_soul := 99
@export var soul_per_hit := 11
@export var heal_cost := 33
## Tempo segurando o botão para curar.
@export var heal_time := 0.9

@export_group("Damage")
## Tempo invencível (piscando) depois de tomar dano.
@export var invincibility_time := 0.8
@export var friction := 900.0

## Última direção em que o jogador andou (usada pelo dash quando está parado).
var facing := Vector2.RIGHT
var can_dash := true
var can_attack := true
var can_parry := true
var knockback := Vector2.ZERO
var soul := 0
## Combo do slash: o segundo golpe vai no sentido contrário.
var slash_flipped := false
var combo_time_left := 0.0

# Duas fontes de invencibilidade: o dash e o "tempo de graça" após tomar dano.
var _dashing := false
var _recovering := false
var _extracting := false
## Alvo escolhido para a extração (preenchido por wants_to_extract).
var extract_target: Enemy

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_area: Hitbox = $AttackPivot/AttackArea
@onready var slash_effect: AnimatedSprite2D = $AttackPivot/SlashEffect
@onready var heal_particles: CPUParticles2D = $HealParticles
@onready var parry_stance: AnimatedSprite2D = $ParryStance
@onready var state_machine: StateMachine = $StateMachine


## INPUT BUFFER: cada botão apertado fica "guardado" por BUFFER_TIME segundos.
## Se você aperta ataque no fim de um dash, o ataque sai assim que o dash acaba,
## em vez de o aperto ser perdido. É isso que deixa o controle "macio".
const BUFFER_TIME := 0.15
const TRAIL_TEXTURE := preload("res://assets/Effects/dash_particle.png")
const TRAIL_INTERVAL := 0.02
const BUFFERED_ACTIONS: Array[StringName] = [&"dash", &"attack", &"parry", &"heal", &"extract"]

var _buffer := {}   # ação -> tempo restante


## Roda ANTES dos estados: o pai processa antes dos filhos (a StateMachine).
func _physics_process(delta: float) -> void:
	for action in _buffer.keys():
		_buffer[action] -= delta
		if _buffer[action] <= 0.0:
			_buffer.erase(action)
	for action in BUFFERED_ACTIONS:
		if Input.is_action_just_pressed(action):
			_buffer[action] = BUFFER_TIME
	if combo_time_left > 0.0:
		combo_time_left -= delta


## Usa o aperto guardado (se houver) e apaga, para não disparar duas vezes.
func _consume(action: StringName) -> bool:
	if _buffer.has(action):
		_buffer.erase(action)
		return true
	return false


func _ready() -> void:
	hurtbox.hurt.connect(_on_hurt)
	attack_area.hit_landed.connect(_on_attack_landed)
	_apply_horn_color()


func _apply_horn_color() -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("horn_color", horn_color)
	(slash_effect.material as ShaderMaterial).set_shader_parameter("fill_color", horn_color)
	parry_stance.modulate = horn_color


# --- Input -------------------------------------------------------------------

func get_input_direction() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")


func wants_to_dash() -> bool:
	return can_dash and _consume("dash")


func wants_to_attack() -> bool:
	return can_attack and _consume("attack")


func wants_to_parry() -> bool:
	return can_parry and _consume("parry")


func wants_to_heal() -> bool:
	return can_heal() and _consume("heal")


## Se apertou "extract" e existe alvo, guarda o alvo em extract_target.
func wants_to_extract() -> bool:
	if not _buffer.has("extract"):
		return false
	extract_target = find_extract_target()
	if extract_target == null:
		return false
	return _consume("extract")


func can_heal() -> bool:
	return soul >= heal_cost and not health.is_full()


# --- Ações -------------------------------------------------------------------

## Duração total (em segundos) de uma animação do SpriteFrames do corpo.
## Funciona para qualquer AnimatedSprite2D (se nenhum for passado, usa o do corpo).
func get_animation_length(animation: StringName, target: AnimatedSprite2D = null) -> float:
	if target == null:
		target = sprite
	var frames := target.sprite_frames
	var total := 0.0
	for i in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, i)
	return total / frames.get_animation_speed(animation)


## Direção (tamanho 1) do centro do corpo até o mouse.
func get_aim_direction() -> Vector2:
	return attack_pivot.global_position.direction_to(get_global_mouse_position())


func update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	facing = direction
	if direction.x != 0:
		sprite.flip_h = direction.x < 0


func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func add_soul(amount: int) -> void:
	soul = clampi(soul + amount, 0, max_soul)
	soul_changed.emit(soul, max_soul)


## Gasta alma e recupera 1 de vida.
func heal() -> void:
	add_soul(-heal_cost)
	health.heal(1)


## Deixa o sprite um pouco branco (0 a 1). Usado para "carregar" a cura e o parry.
func set_glow(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", amount)


## Solta um pedaço do rastro (dash, salto da extração), girado para `direction`.
## É um Sprite2D comum: controlamos rotação, tamanho e fade um por um.
func spawn_trail(direction: Vector2) -> void:
	var piece := Sprite2D.new()
	piece.texture = TRAIL_TEXTURE
	# O desenho aponta para baixo-direita (45°): descontamos para alinhar com a direção.
	piece.rotation = direction.angle() - deg_to_rad(45.0)
	piece.scale = Vector2.ONE * randf_range(0.6, 0.9)
	# Adicionado na cena (não no Player), senão o rastro andaria junto com ele.
	get_parent().add_child(piece)
	piece.global_position = sprite.global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3))

	var tween := piece.create_tween().set_parallel()
	tween.tween_property(piece, "scale", Vector2.ZERO, 0.3)
	tween.tween_property(piece, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(piece.queue_free)


func set_dashing(value: bool) -> void:
	_dashing = value
	_update_invincibility()


func set_extracting(value: bool) -> void:
	_extracting = value
	_update_invincibility()


## O inimigo "extraível" (com 1 de vida) mais perto do MOUSE, dentro do alcance.
## Retorna null se não houver nenhum.
func find_extract_target() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	var mouse := get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_extractable():
			continue
		if global_position.distance_to(enemy.global_position) > extract_range:
			continue
		var distance := mouse.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Fica invencível por um tempo, piscando.
func start_recovery() -> void:
	_recovering = true
	_update_invincibility()
	var blink := create_tween().set_loops()
	blink.tween_property(sprite, "modulate:a", 0.2, 0.06)
	blink.tween_property(sprite, "modulate:a", 1.0, 0.06)

	await get_tree().create_timer(invincibility_time).timeout
	blink.kill()
	sprite.modulate.a = 1.0
	_recovering = false
	_update_invincibility()


func start_dash_cooldown() -> void:
	can_dash = false
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true


func start_attack_cooldown() -> void:
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func start_parry_cooldown() -> void:
	can_parry = false
	await get_tree().create_timer(parry_cooldown).timeout
	can_parry = true


# --- Reações -----------------------------------------------------------------

func _update_invincibility() -> void:
	hurtbox.invincible = _dashing or _recovering or _extracting


func _on_attack_landed(_target: Hurtbox) -> void:
	add_soul(soul_per_hit)


func _on_hurt(hitbox: Hitbox) -> void:
	knockback = hitbox.get_knockback(global_position)
	health.damage(hitbox.damage)

	# O jogador tomando dano merece MAIS juice que um inimigo: tem que ser sentido.
	Juice.flash(sprite, 0.2)
	Juice.hitstop(0.12)
	Juice.shake(0.5)

	if health.is_dead():
		state_machine.transition_to(&"dead")
	else:
		state_machine.transition_to(&"hurt")
