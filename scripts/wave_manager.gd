class_name WaveManager
extends Node
## Waves estilo Brotato:
## - cada wave tem um TIMER; sobreviva até ele zerar;
## - monstros nascem em GRUPOS, com um X de aviso no chão antes (telegraph);
## - a cada wave: mais tempo, spawns mais rápidos e grupos maiores;
## - ao fim da wave todos os monstros morrem, há um intervalo, e vem a próxima.
## A HUD escuta os sinais para mostrar wave e tempo.


signal wave_started(wave: int, duration: float)
signal wave_ended(wave: int)

const MARKER_FRAMES := preload("res://resources/effects/spawn_marker.tres")

@export var enemy_scenes: Array[PackedScene] = []
## A partir de qual wave cada inimigo aparece (mesma ordem de enemy_scenes).
## Faltou número? Vale a wave 1.
@export var enemy_min_waves: Array[int] = []
## Começa a wave 1 sozinho ao abrir a cena (o tutorial desliga isso).
@export var auto_start := true
## No intervalo, espera o jogador escolher uma melhoria (UpgradeScreen).
@export var upgrades_enabled := true

@export_group("Duration")
## Brotato: wave 1 = 20s, +5s por wave, até 60s.
@export var base_duration := 20.0
@export var duration_per_wave := 5.0
@export var max_duration := 60.0
## Intervalo entre uma wave e outra (sem melhorias: tempo todo; com: depois da escolha).
@export var break_time := 4.0
@export var break_after_upgrade := 1.5

@export_group("Spawning")
@export var base_spawn_interval := 3.0
## A cada wave o intervalo é multiplicado por isso (0.88 = 12% mais rápido).
@export var spawn_interval_multiplier := 0.88
@export var min_spawn_interval := 0.8
## Quanto tempo o X de aviso fica no chão antes do monstro aparecer.
@export var telegraph_time := 1.0
@export var base_max_enemies := 6
@export var max_enemies_per_wave := 2
## Monstros nunca nascem mais perto do jogador do que isso.
@export var min_spawn_distance := 70.0

var wave := 0
var time_left := 0.0
var in_wave := false

var _spawn_timer := 0.0
var _break_left := 0.0
var _markers: Array[Node2D] = []
## Intervalo parado esperando a escolha da melhoria.
var _awaiting_upgrade := false

@onready var game: Game = get_parent()


func _ready() -> void:
	# Espera o Game terminar o _ready (ele calcula os limites do mapa).
	await game.ready
	if auto_start:
		_start_wave(1)


func _process(delta: float) -> void:
	if in_wave:
		time_left -= delta
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = _spawn_interval()
			_spawn_group()
		if time_left <= 0.0:
			_end_wave()
	elif wave > 0 and not _awaiting_upgrade:
		_break_left -= delta
		if _break_left <= 0.0:
			_start_wave(wave + 1)


## A UpgradeScreen chama isto depois que o jogador escolhe: a próxima wave vem logo.
func finish_upgrade() -> void:
	_awaiting_upgrade = false
	_break_left = break_after_upgrade


func _start_wave(number: int) -> void:
	wave = number
	time_left = minf(base_duration + duration_per_wave * (wave - 1), max_duration)
	in_wave = true
	_spawn_timer = 0.5   # primeiro grupo logo no começo
	wave_started.emit(wave, time_left)


func _end_wave() -> void:
	in_wave = false
	_break_left = break_time
	_awaiting_upgrade = upgrades_enabled

	# Cancela os avisos que ainda não viraram monstro.
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()

	# Todos os monstros morrem (como no Brotato) e os projéteis somem.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as Enemy
		if e and not e.being_extracted:
			e.health.damage(e.health.health)
			e.state_machine.transition_to(&"death")
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()

	Juice.shake(0.3)
	Juice.punch(0.1)
	wave_ended.emit(wave)


func _spawn_interval() -> float:
	var interval := base_spawn_interval * pow(spawn_interval_multiplier, wave - 1)
	return maxf(interval, min_spawn_interval)


func _max_enemies() -> int:
	return base_max_enemies + max_enemies_per_wave * (wave - 1)


## Grupo: 1 monstro na wave 1, +1 a cada 2 waves.
func _spawn_group() -> void:
	var group_size := 1 + int((wave - 1) / 2.0)
	var alive := get_tree().get_nodes_in_group("enemies").size() + _markers.size()
	group_size = mini(group_size, _max_enemies() - alive)
	if group_size <= 0 or enemy_scenes.is_empty():
		return

	# O grupo nasce junto (e do MESMO tipo): um ponto central e os outros perto dele.
	var scene := _pick_enemy()
	var center := _random_spawn_point()
	for i in group_size:
		var offset := Vector2(randf_range(-20, 20), randf_range(-20, 20)) if i > 0 else Vector2.ZERO
		var point: Vector2 = (center + offset).clamp(game.bounds.position + Vector2(16, 30),
			game.bounds.end - Vector2(16, 8))
		_telegraph(point, scene)


## Sorteia um tipo de inimigo entre os já liberados nesta wave.
func _pick_enemy() -> PackedScene:
	var available: Array[PackedScene] = []
	for i in enemy_scenes.size():
		var min_wave := enemy_min_waves[i] if i < enemy_min_waves.size() else 1
		if wave >= min_wave:
			available.append(enemy_scenes[i])
	return available.pick_random() if not available.is_empty() else enemy_scenes[0]


func _random_spawn_point() -> Vector2:
	var bounds: Rect2 = game.bounds
	var point := Vector2.ZERO
	for _attempt in 10:
		point = Vector2(
			randf_range(bounds.position.x + 20, bounds.end.x - 20),
			randf_range(bounds.position.y + 40, bounds.end.y - 10))
		if point.distance_to(game.player.global_position) >= min_spawn_distance:
			break
	return point


## Mostra o X de aviso; depois de telegraph_time, troca pelo monstro.
func _telegraph(point: Vector2, scene: PackedScene) -> void:
	var marker := AnimatedSprite2D.new()
	marker.sprite_frames = MARKER_FRAMES
	marker.modulate = Color(Juice.GLOW, Juice.GLOW, Juice.GLOW)   # brilha (Glow)
	game.add_child(marker)
	marker.global_position = point
	marker.play("default")
	_markers.append(marker)

	await get_tree().create_timer(telegraph_time).timeout
	# A wave pode ter acabado durante a espera (o marcador foi apagado).
	if not is_instance_valid(marker):
		return
	_markers.erase(marker)
	marker.queue_free()

	var enemy: Node2D = scene.instantiate()
	game.add_child(enemy)
	enemy.global_position = point
