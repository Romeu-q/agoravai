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
## Parry em PROJÉTIL: o tempo fica lento e você mira com o mouse para onde devolver.
## Velocidade do jogo durante a mira (0.15 = 15%).
@export var parry_slow_scale := 0.15
## Tempo máximo de mira (segundos REAIS). Depois disso, o projétil EXPLODE em você.
@export var parry_aim_time := 2.5
## Distância (px) do jogador em que o projétil fica "na mão" durante a mira.
@export var parry_hold_distance := 14.0

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
## Projéteis pegos no parry, esperando a mira (estado ParryThrow).
var caught_projectiles: Array[Projectile] = []
## Multiplicador do raio da explosão dos projéteis devolvidos (melhoria ESTILHACO).
var throw_blast_scale := 1.0
## Nível de cada melhoria pega nesta partida (Upgrade -> nível).
var upgrade_levels := {}


## (Tipado como Resource, e não Upgrade: o Upgrade já usa o tipo Player,
## e dois scripts dependendo um do outro confundem o editor.)
func get_upgrade_level(upgrade: Resource) -> int:
	return upgrade_levels.get(upgrade, 0)


func apply_upgrade(upgrade: Resource) -> void:
	upgrade_levels[upgrade] = get_upgrade_level(upgrade) + 1
	upgrade.apply(self)

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
@onready var neon_trail: GPUParticles2D = $NeonTrail
@onready var aim_line: Line2D = $AimLine
@onready var state_machine: StateMachine = $StateMachine


## INPUT BUFFER: cada botão apertado fica "guardado" por BUFFER_TIME segundos.
## Se você aperta ataque no fim de um dash, o ataque sai assim que o dash acaba,
## em vez de o aperto ser perdido. É isso que deixa o controle "macio".
const BUFFER_TIME := 0.15
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
	# O rastro sai de onde o sprite está (na extração ele flutua acima do chão).
	neon_trail.position = sprite.position


## Usa o aperto guardado (se houver) e apaga, para não disparar duas vezes.
## Esquece todos os apertos guardados. Usado quando um estado novo NÃO deve
## reagir a cliques feitos antes dele começar (ex.: a mira do parry).
func clear_input_buffer() -> void:
	_buffer.clear()


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
## Para onde o jogador está mirando.
## Mouse: do jogador até o cursor. Controle: o analógico direito; solto, mira
## para onde está andando; parado, para onde está virado.
func get_aim_direction() -> Vector2:
	if InputMode.using_gamepad:
		var stick := InputMode.aim_vector()
		if stick.length() > 0.3:
			return stick.normalized()
		var move := get_input_direction()
		return move.normalized() if move != Vector2.ZERO else facing
	return attack_pivot.global_position.direction_to(get_global_mouse_position())


## Ponto "mirado" no mundo: o cursor, ou (no controle) um ponto à frente na mira.
func get_aim_point() -> Vector2:
	if InputMode.using_gamepad:
		return global_position + get_aim_direction() * 60.0
	return get_global_mouse_position()


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


## Liga/desliga o rastro neon (dash, salto da extração).
## As partículas ficam no MUNDO (local_coords desligado), então elas ficam
## para trás enquanto o jogador anda: isso é o rastro.
func set_trail(active: bool) -> void:
	neon_trail.emitting = active


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
	var mouse := get_aim_point()
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
	Sound.play("hurt")

	# O jogador tomando dano merece MAIS juice que um inimigo: tem que ser sentido.
	Juice.flash(sprite, 0.2)
	Juice.hitstop(0.12)
	Juice.shake(0.5)

	if health.is_dead():
		state_machine.transition_to(&"dead")
	else:
		state_machine.transition_to(&"hurt")
