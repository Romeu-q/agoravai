class_name Enemy
extends CharacterBody2D
## Base de TODOS os inimigos: guarda dados e ações comuns (perseguir, virar,
## reagir a dano). Cada monstro é uma cena que usa este script e ajusta os
## @export no Inspector. Se um monstro precisar de comportamento próprio, criamos
## um script que herda daqui (`extends Enemy`).


@export var speed := 45.0
## Distância do alvo em que o inimigo começa o ataque.
@export var attack_range := 40.0
## Recarga do golpe. Enquanto recarrega, ele fica RODEANDO o jogador.
@export var attack_cooldown := 2.2
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

@export_group("AI")
## Desligue para um monstro que NÃO ataca corpo a corpo (ex.: atirador do tutorial).
@export var melee_enabled := true
## Desligue para um monstro PARADO (ex.: boneco de treino do tutorial).
@export var move_enabled := true
## Distância que ele gosta de manter do jogador enquanto o ataque corpo a corpo
## recarrega (fica rodeando). 0 = sempre vai para cima.
@export var preferred_distance := 80.0
## Folga em volta da distância preferida antes de se aproximar/afastar.
@export var distance_tolerance := 18.0
## Quão rápido muda de velocidade (maior = curvas mais secas).
@export var acceleration := 380.0
## Ao ir para cima, chega de lado (radianos): um "flanco" em vez de linha reta.
@export var flank_angle := 0.45
## Troca o sentido em que rodeia o jogador a cada X segundos (entre min e max).
@export var strafe_time_min := 1.2
@export var strafe_time_max := 2.6
## Empurra para longe de outros monstros mais perto que isso (não empilham).
@export var separation_radius := 22.0
@export var separation_weight := 1.2
## Aviso antes de atacar: para, treme e os olhos acendem.
@export var windup_time := 0.4
## Depois de atacar fica parado um instante: a janela para o jogador punir.
@export var recover_time := 0.45
## Velocidade da investida durante os frames ativos do ataque corpo a corpo.
@export var lunge_speed := 160.0
## Mira no FUTURO: 0 = onde o jogador está, 1 = onde ele vai estar.
@export var lead_factor := 0.6
@export var shots_per_volley := 1
@export var volley_spread_degrees := 14.0

@export_group("Flying")
## Para monstros voadores: o sprite sobe e desce (px). 0 = anda no chão.
@export var bob_amount := 0.0
@export var bob_speed := 4.0

## Quantos monstros podem estar atacando (aviso + golpe) AO MESMO TEMPO.
## `static` = uma variável só, compartilhada por TODOS os inimigos. Sem esse
## limite, 10 monstros atacariam juntos e seria impossível reagir.
const MAX_ATTACKERS := 2
static var attackers := 0

var target: Node2D
var being_extracted := false
## Próxima ação depois do aviso (Windup): &"attack" ou &"shoot".
var next_action: StringName = &"attack"
## Direção do golpe, TRAVADA no fim do aviso (o jogador pode sair da frente).
var attack_direction := Vector2.RIGHT
var _has_attack_slot := false
var _base_eye_energy := 2.5
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
	# Brilho normal dos olhos. Se o material não mudou o valor, ele vem null
	# (vale o padrão do shader, 2.5), então só troca quando existir.
	var eye_energy = (sprite.material as ShaderMaterial).get_shader_parameter("eye_energy")
	if eye_energy != null:
		_base_eye_energy = eye_energy
	# Começa em cooldown: não atira assim que nasce.
	start_shoot_cooldown()


## Saiu da cena (morreu, foi extraído, fim da wave): devolve a vaga de ataque.
func _exit_tree() -> void:
	release_attack()


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
	_register_kill()
	var state := state_machine.current_state
	if state.has_method("absorb_into"):
		state.absorb_into(extractor)


## Conta a morte na partida (se a cena atual for um Game).
## As mortes do FIM da wave não passam por aqui: não contam.
func _register_kill() -> void:
	var game := get_tree().current_scene as Game
	if game:
		game.register_kill()


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


## Atira uma rajada (shots_per_volley projéteis em leque) mirando ONDE O
## JOGADOR VAI ESTAR quando o tiro chegar.
func shoot() -> void:
	var from := hurtbox.global_position
	Sound.play("enemy_shoot")
	for i in shots_per_volley:
		var projectile: Projectile = projectile_scene.instantiate()
		var aim := from.direction_to(predict_target_position(from, projectile.speed))
		# Leque: o do meio vai reto, os outros abrem para os lados.
		var offset := deg_to_rad((i - (shots_per_volley - 1) / 2.0) * volley_spread_degrees)
		projectile.direction = aim.rotated(offset)
		projectile.shooter = self
		projectile.collision_mask = Projectile.MASK_HITS_PLAYER
		get_parent().add_child(projectile)
		projectile.global_position = from + projectile.direction * 8.0


## Onde o alvo vai estar quando um tiro de velocidade `speed` chegar nele.
## Conta simples: tempo de voo = distância / velocidade; posição futura =
## posição + velocidade do alvo x tempo. `lead_factor` dosa o quanto confia nisso.
func predict_target_position(from: Vector2, speed: float) -> Vector2:
	var aim_point := target.global_position + Vector2(0, -5)   # centro do corpo
	var body := target as CharacterBody2D
	if body == null or speed <= 0.0:
		return aim_point
	var flight_time := from.distance_to(aim_point) / speed
	# limit_length: no dash a velocidade é enorme; sem limite ele erraria longe.
	var lead := (body.velocity * flight_time * lead_factor).limit_length(50.0)
	return aim_point + lead


# --- Movimento da IA -----------------------------------------------------------

## Acelera suavemente até `desired` (velocidade desejada), somando o empurrão
## para longe dos outros monstros, e move.
func steer(desired: Vector2, delta: float) -> void:
	var wanted := desired + separation() * speed * separation_weight
	velocity = velocity.move_toward(wanted, acceleration * delta)
	move_and_slide()


## Vetor apontando para LONGE dos monstros vizinhos (mais forte quanto mais perto).
func separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Node2D
		if other == null or other == self:
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance > 0.0 and distance < separation_radius:
			push += offset / distance * (1.0 - distance / separation_radius)
	return push.limit_length(1.0)


# --- Vagas de ataque -----------------------------------------------------------

## Tenta pegar uma das vagas de ataque. false = já tem gente demais atacando.
func try_claim_attack() -> bool:
	if _has_attack_slot:
		return true
	if attackers >= MAX_ATTACKERS:
		return false
	attackers += 1
	_has_attack_slot = true
	return true


## Devolve a vaga (pode chamar mais de uma vez sem problema).
func release_attack() -> void:
	if _has_attack_slot:
		_has_attack_slot = false
		attackers -= 1


## Brilho extra dos olhos (0 = normal, 1 = máximo). Usado no aviso de ataque.
func set_eye_glow(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("eye_energy",
		_base_eye_energy * (1.0 + amount * 2.0))


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
	Sound.play("hit")
	Juice.burst(hurtbox.global_position, blood_color, 14,
		knockback.normalized(), 25.0, 1.0, 170.0)
	Juice.hitstop(0.05)
	Juice.shake(0.15)

	if health.is_dead():
		_register_kill()
		state_machine.transition_to(&"death")
	else:
		stun_time = hurt_stun_time
		state_machine.transition_to(&"hurt")
