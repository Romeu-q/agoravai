class_name Enemy
extends CharacterBody2D
## Base de TODOS os inimigos: guarda dados e ações comuns (perseguir, virar,
## reagir a dano). Cada monstro é uma cena que usa este script e ajusta os
## @export no Inspector. Se um monstro precisar de comportamento próprio, criamos
## um script que herda daqui (`extends Enemy`).


@export var speed := 45.0
## Distância do alvo em que o inimigo começa o ataque.
@export var attack_range := 40.0
@export var attack_cooldown := 1.2
## Frames da animação "attack" em que a Hitbox fica ligada (o momento do golpe).
@export var attack_active_frames: Array[int] = [4, 5, 6]
## Quão rápido o empurrão (knockback) freia.
@export var friction := 900.0
## Cor das partículas que saem quando ele é acertado.
@export var blood_color := Color("0b0911")
## Tempo atordoado ao tomar dano normal / ao ter o ataque aparado (parry).
@export var hurt_stun_time := 0.25
@export var parry_stun_time := 1.0

@export_group("Shoot")
## Cena do projétil. Deixe vazio para o inimigo não atirar.
@export var projectile_scene: PackedScene
## Só atira se o alvo estiver entre essas distâncias (nem colado, nem longe demais).
@export var shoot_min_range := 45.0
@export var shoot_max_range := 140.0
@export var shoot_cooldown := 3.0
## Frame da animação "attack" em que o projétil sai.
@export var shoot_frame := 4

@export_group("Flying")
## Para monstros voadores: o sprite sobe e desce (px). 0 = anda no chão.
@export var bob_amount := 0.0
@export var bob_speed := 4.0

var target: Node2D
var being_extracted := false
var _time := randf() * TAU      # cada monstro balança num tempo diferente
var _sprite_base_y := 0.0
var can_attack := true
var can_shoot := false
var knockback := Vector2.ZERO
## Quanto tempo o estado Hurt vai durar (depende do que causou).
var stun_time := 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var state_machine: StateMachine = $StateMachine
@onready var shadow: Sprite2D = $Shadow
@onready var extract_mark: AnimatedSprite2D = $ExtractMark


func _ready() -> void:
	# Grupos são "etiquetas": o Player está no grupo "player".
	target = get_tree().get_first_node_in_group("player")
	hurtbox.hurt.connect(_on_hurt)
	_sprite_base_y = sprite.position.y
	extract_mark.visible = false
	# Começa em cooldown: não atira assim que nasce.
	start_shoot_cooldown()


func _process(delta: float) -> void:
	# Voo: o sprite balança; a sombra (no chão) encolhe quando ele sobe.
	if bob_amount > 0.0 and not being_extracted:
		_time += delta * bob_speed
		var wave := sin(_time)
		sprite.position.y = _sprite_base_y + wave * bob_amount
		shadow.scale = Vector2.ONE * (1.0 + wave * 0.08)

	var show_mark := is_extractable()
	if show_mark and not extract_mark.visible:
		extract_mark.play("default")
		# Juice: a marca "aparece" com um anel, avisando que dá para extrair.
		Juice.ring(extract_mark.global_position, Color.WHITE, 8.0, 0.2)
	extract_mark.visible = show_mark


## Com 1 de vida (e não nascendo/morrendo), pode ser extraído pelo jogador.
func is_extractable() -> bool:
	if being_extracted or health.health != 1 or state_machine.current_state == null:
		return false
	return not (state_machine.current_state.name in [&"Spawn", &"Death"])


## Primeira parte da extração: congela o monstro (o jogador está saltando até ele).
func start_extraction() -> void:
	being_extracted = true
	state_machine.transition_to(&"extracted")


## Segunda parte: a essência é arrancada em direção a `extractor`.
func extract(extractor: Node2D) -> void:
	var state := state_machine.current_state
	if state.has_method("absorb_into"):
		state.absorb_into(extractor)


func has_target() -> bool:
	return is_instance_valid(target)


func direction_to_target() -> Vector2:
	return global_position.direction_to(target.global_position) if has_target() else Vector2.ZERO


func distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if has_target() else INF


## Vira o sprite e o "braço" de ataque para o lado da direção.
func face(direction: Vector2) -> void:
	if direction.x == 0:
		return
	sprite.flip_h = direction.x < 0
	attack_pivot.scale.x = -1 if direction.x < 0 else 1


## Desacelera o empurrão e move. Usado pelos estados Hurt e Death.
func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func wants_to_shoot() -> bool:
	if projectile_scene == null or not can_shoot:
		return false
	var distance := distance_to_target()
	return distance >= shoot_min_range and distance <= shoot_max_range


## Cria um projétil mirando no centro do corpo do alvo.
func shoot() -> void:
	var from := hurtbox.global_position
	var direction := from.direction_to(target.global_position + Vector2(0, -5))
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.direction = direction
	projectile.shooter = self
	projectile.collision_mask = Projectile.MASK_HITS_PLAYER
	get_parent().add_child(projectile)
	projectile.global_position = from + direction * 8.0


func start_shoot_cooldown() -> void:
	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true


func start_attack_cooldown() -> void:
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


## Chamado pelo Player quando ele apara (parry) um ataque deste inimigo.
func get_parried(from_position: Vector2) -> void:
	knockback = from_position.direction_to(global_position) * 220.0
	stun_time = parry_stun_time
	state_machine.transition_to(&"hurt")


func _on_hurt(hitbox_that_hit: Hitbox) -> void:
	knockback = hitbox_that_hit.get_knockback(global_position)
	health.damage(hitbox_that_hit.damage)

	# Flash branco + esguicho de partículas finas saindo do lado oposto ao golpe.
	Juice.flash(sprite)
	Juice.burst(hurtbox.global_position, blood_color, 14,
		knockback.normalized(), 25.0, 1.0, 170.0)
	Juice.hitstop(0.05)
	Juice.shake(0.15)

	if health.is_dead():
		state_machine.transition_to(&"death")
	else:
		stun_time = hurt_stun_time
		state_machine.transition_to(&"hurt")
