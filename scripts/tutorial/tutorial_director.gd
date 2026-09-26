extends Node
## DIRETOR DO TUTORIAL: ensina uma mecânica por vez, em sequência.
## Cada passo usa `await` para ESPERAR o jogador fazer a ação; por isso o
## código lê de cima para baixo como um roteiro (_run).
## Nos momentos de reflexo (extrair, parry, pegar o tiro) o jogo CONGELA e
## mostra a tecla; ao apertar, o jogo volta e a ação acontece na hora certa.
## process_mode ALWAYS: continua funcionando com o jogo congelado.


const SHRINKER := preload("res://scenes/enemies/shrinker.tscn")
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var game: Game
var player: Player
var ui: TutorialUI

var _moved := 0.0
var _dashes := 0
var _last_state: StringName = &""
var _parried := false
## Tecla que o congelamento está esperando (vazio = não está esperando nada).
var _waiting_action: StringName = &""

signal _key_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	await game.ready
	player = game.player
	ui = game.get_node("TutorialUI")
	game.get_node("HUD/WaveInfo").visible = false   # sem waves no tutorial
	player.parry_aim_time = 6.0                      # mais tempo para ler e mirar
	player.health.health_changed.connect(_keep_alive)
	player.hurtbox.parried.connect(func(_hitbox: Hitbox): _parried = true)
	ui.play_pressed.connect(_leave.bind(GAME_SCENE))
	ui.menu_pressed.connect(_leave.bind(MENU_SCENE))
	_run()


func _physics_process(delta: float) -> void:
	if get_tree().paused or player == null or player.state_machine.current_state == null:
		return
	var state := _state()
	if state == &"Walk":
		_moved += player.velocity.length() * delta
	if state == &"Dash" and _last_state != &"Dash":
		_dashes += 1
	_last_state = state


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != &"" and event.is_action_pressed(_waiting_action):
		get_viewport().set_input_as_handled()
		_waiting_action = &""
		_key_pressed.emit()


# =============================================================================
# O ROTEIRO
# =============================================================================

func _run() -> void:
	# Espera o laser de chegada terminar.
	await _until(func(): return _state() == &"Idle" or _state() == &"Walk")
	await _step_move()
	await _step_dash()
	await _step_attack_and_extract()
	await _step_parry()
	await _step_throw()
	await _step_heal()
	ui.show_final()


func _step_move() -> void:
	ui.show_prompt("1/6  MOVIMENTO", "ANDE PELA ARENA.", InputMode.label("move"))
	_moved = 0.0
	await _until(func(): return _moved > 140.0)
	await _success("BOA!")


func _step_dash() -> void:
	ui.show_prompt("2/6  DASH",
		"DASH: UM IMPULSO RAPIDO NA DIRECAO QUE VOCE ANDA. DURANTE O DASH NADA TE ACERTA. DE 2 DASHES.",
		InputMode.label("dash"))
	_dashes = 0
	await _until(func(): return _dashes >= 2)
	await _success("RAPIDO!")


func _step_attack_and_extract() -> void:
	ui.show_prompt("3/6  ATAQUE",
		"MIRE (%s) E ATAQUE O BONECO. APERTE DE NOVO LOGO EM SEGUIDA: O GOLPE VOLTA EM COMBO." % InputMode.label("aim"),
		InputMode.label("attack"))
	while true:
		var dummy := _spawn(Vector2(60, 0), func(enemy: Enemy):
			enemy.move_enabled = false
			enemy.melee_enabled = false
			enemy.projectile_scene = null)
		await _until(func(): return not is_instance_valid(dummy) or dummy.health.health <= 1)
		if not is_instance_valid(dummy) or dummy.health.is_dead():
			continue   # passou do ponto: outro boneco
		# CONGELA: inimigo com 1 de vida -> extração.
		await _freeze_for(&"extract", "EXTRAIA!",
			"INIMIGOS COM 1 DE VIDA MOSTRAM UM LOSANGO. EXTRAIR CURA 1 E ENCHE A ALMA.",
			InputMode.label("extract"))
		if is_instance_valid(dummy) and dummy.is_extractable():
			player.extract_target = dummy
			player.state_machine.transition_to(&"extract")
		await _until(func(): return not is_instance_valid(dummy))
		break
	await _success("EXTRAIDO!")


func _step_parry() -> void:
	ui.show_prompt("4/6  PARRY",
		"QUANDO UM INIMIGO PARA, TREME E OS OLHOS ACENDEM, ELE VAI ATACAR. FIQUE PERTO E ESPERE.",
		"")
	_parried = false
	var foe := _spawn(Vector2(80, 0), func(enemy: Enemy): enemy.projectile_scene = null)
	while not _parried:
		# Espera o golpe estar a UM quadro de acertar.
		await _until(func(): return not is_instance_valid(foe) or (_enemy_state(foe) == &"Attack" \
			and foe.sprite.frame >= foe.attack_active_frames[0] - 1))
		if not is_instance_valid(foe):
			foe = _spawn(Vector2(80, 0), func(enemy: Enemy): enemy.projectile_scene = null)
			continue
		await _freeze_for(&"parry", "APARE!",
			"APERTE BEM NA HORA DO GOLPE. O PARRY CERTO NAO TIRA VIDA E ATORDOA O INIMIGO.",
			InputMode.label("parry"))
		player.state_machine.transition_to(&"parry")
		await _until(func(): return _parried or not is_instance_valid(foe) \
			or _enemy_state(foe) != &"Attack")
		if not _parried:
			ui.show_prompt("4/6  PARRY", "QUASE! ESPERE O PROXIMO GOLPE.", "")
	await _success("PARRY!")
	ui.show_prompt("4/6  PARRY", "AGORA DERROTE-O.", InputMode.label("attack"))
	await _until(func(): return not is_instance_valid(foe) or foe.health.is_dead())


func _step_throw() -> void:
	ui.show_prompt("5/6  DEVOLVER TIROS",
		"ESTE INIMIGO ATIRA. DA PARA PEGAR O TIRO COM O PARRY E DEVOLVER.", "")
	var setup := func(enemy: Enemy):
		enemy.melee_enabled = false
		enemy.shoot_cooldown = 2.0
	var foe := _spawn(Vector2(110, -20), setup)
	while true:
		if not is_instance_valid(foe) or foe.health.is_dead():
			foe = _spawn(Vector2(110, -20), setup)
		var start_health := foe.health.health
		await _until(func(): return _incoming_projectile() != null)
		await _freeze_for(&"parry", "SEGURE!",
			"SEGURE %s PARA PEGAR O TIRO. NAO SOLTE AINDA!" % InputMode.label("parry"),
			"SEGURE " + InputMode.label("parry"))
		player.state_machine.transition_to(&"parry")
		await _until_or_timeout(func(): return _state() == &"ParryThrow", 0.6)
		if _state() != &"ParryThrow":
			ui.show_prompt("5/6  DEVOLVER TIROS", "QUASE! ESPERE O PROXIMO TIRO.", "")
			continue
		ui.show_prompt("5/6  DEVOLVER TIROS",
			"O TEMPO FICOU LENTO. MIRE NO INIMIGO (%s) E SOLTE %s. SE DEMORAR, EXPLODE EM VOCE!" \
				% [InputMode.label("aim"), InputMode.label("parry")],
			"SOLTE " + InputMode.label("parry"))
		await _until(func(): return _state() != &"ParryThrow")
		await _wait(0.8)   # tempo do tiro voar
		if not is_instance_valid(foe) or foe.health.health < start_health:
			break
		ui.show_prompt("5/6  DEVOLVER TIROS", "ERROU! ESPERE O PROXIMO TIRO.", "")
	await _success("NA MOSCA!")
	_clear_enemies()


func _step_heal() -> void:
	player.add_soul(player.max_soul)
	# Enche e tira 2: assim nunca chega a zero (com 2 de vida, tirar 2 mataria).
	player.health.heal(player.health.max_health)
	player.health.damage(2)
	ui.show_prompt("6/6  CURA",
		"A BARRA EMBAIXO DA VIDA E A ALMA. ACERTAR, APARAR E EXTRAIR ENCHEM A ALMA. PARADO, SEGURE %s PARA CURAR." \
			% InputMode.label("heal"),
		"SEGURE " + InputMode.label("heal"))
	var start_health := player.health.health
	await _until(func(): return player.health.health > start_health)
	await _success("CURADO!")


# =============================================================================
# FERRAMENTAS
# =============================================================================

## Espera (quadro a quadro) até a condição ser verdadeira.
## physics_frame é emitido mesmo com o jogo pausado.
func _until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().physics_frame


## Igual ao _until, mas desiste depois de `seconds` (tempo real).
func _until_or_timeout(condition: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().physics_frame


## create_timer conta mesmo com o jogo pausado (process_always vem ligado).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _success(text: String) -> void:
	ui.success(text)
	await _wait(1.1)


## Congela o jogo mostrando a tecla e espera o jogador apertar `action`.
func _freeze_for(action: StringName, title: String, hint: String, key: String) -> void:
	ui.freeze(title, hint, key)
	_waiting_action = action
	await _key_pressed
	ui.unfreeze()


## Cria um Shrinker perto do jogador. `setup` ajusta ele ANTES de entrar na cena.
func _spawn(offset: Vector2, setup: Callable) -> Enemy:
	var enemy: Enemy = SHRINKER.instantiate()
	setup.call(enemy)
	var point := (player.global_position + offset).clamp(game.bounds.position + Vector2(20, 30),
		game.bounds.end - Vector2(20, 10))
	game.add_child(enemy)
	enemy.global_position = point
	return enemy


func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()


## Um tiro inimigo prestes a acertar o jogador (perto e vindo na direção dele).
func _incoming_projectile() -> Projectile:
	var body := player.hurtbox.global_position
	for node in get_tree().get_nodes_in_group("projectiles"):
		var projectile := node as Projectile
		if projectile == null or projectile.collision_mask != Projectile.MASK_HITS_PLAYER:
			continue
		var to_player := projectile.global_position.direction_to(body)
		if projectile.global_position.distance_to(body) < 24.0 and projectile.direction.dot(to_player) > 0.5:
			return projectile
	return null


func _state() -> StringName:
	var current := player.state_machine.current_state
	return current.name if current else &""


func _enemy_state(enemy: Enemy) -> StringName:
	var current := enemy.state_machine.current_state
	return current.name if current else &""


## No tutorial ninguém morre: se a vida cair demais, enche de novo.
func _keep_alive(health: int, max_health: int) -> void:
	if health <= 1:
		player.health.heal.call_deferred(max_health)


func _leave(scene: String) -> void:
	get_tree().paused = false
	Juice.slow_motion(1.0)
	get_tree().change_scene_to_file(scene)
