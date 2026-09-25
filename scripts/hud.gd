extends Control
## HUD do jogador (estilo Hyper Light Drifter, paleta neon):
##   [emblema]  ◆ ◆ ◆ ◆ ◆     <- pips de vida (losangos)
##              ▰ ▰ ▰         <- alma em SEGMENTOS (1 segmento = 1 cura)
##   ─────────────────◆       <- traço de "circuito" (decoração)
## Tudo anima com tweens suaves, e os momentos importantes soltam neon bursts
## DENTRO da HUD (Juice.neon_burst_ui).
## O node inteiro é ampliado pelo `scale` (3x) no Inspector.


const PIP_TEXTURE := preload("res://assets/UI/hud_pip.png")
const SEGMENT_UNDER := preload("res://assets/UI/soul_segment_under.png")
const SEGMENT_PROGRESS := preload("res://assets/UI/soul_segment_progress.png")
const FRAME_FULL := 0
const FRAME_LOST := 1
const FRAME_EMPTY := 2

## Distância entre os pips (o pip tem 7 px).
@export var pip_step := 8
## Distância entre os segmentos de alma (12 px, inclinados: encaixam um no outro).
@export var segment_step := 10
@export var soul_color := Color("e6e6f0")
@export var soul_ready_color := Palette.CYAN
## Quão rápido a barra de alma "alcança" o valor real (maior = mais rápido).
@export var soul_smoothing := 10.0

var player: Player
var _pips: Array[Sprite2D] = []
var _segments: Array[TextureProgressBar] = []
var _health := 0
var _ghost := 0            # pips recém-perdidos ficam brancos um instante
var _ghost_timer := 0.0
var _soul_shown := 0.0     # valor DESENHADO: desliza até a alma real
var _full_segments := 0
var _soul_flash := 0.0     # brilho branco quando ganha alma
var _time := 0.0
var _base_position: Vector2

@onready var crest: TextureRect = $Crest
@onready var pips_root: Node2D = $Pips
@onready var soul_root: Control = $Soul
@onready var trace: ColorRect = $Trace
@onready var trace_dot: TextureRect = $TraceDot


func _ready() -> void:
	_base_position = position
	player = get_tree().get_first_node_in_group("player")
	_health = player.health.health
	_ghost = _health
	_soul_shown = player.soul

	_create_pips()
	_create_segments()
	_layout_trace()

	player.health.health_changed.connect(_on_health_changed)
	player.soul_changed.connect(_on_soul_changed)
	_intro()


# --- Montagem ------------------------------------------------------------------

func _create_pips() -> void:
	for i in player.health.max_health:
		var pip := Sprite2D.new()
		pip.texture = PIP_TEXTURE
		pip.hframes = 3
		# Centralizado (para os "pulos" de escala crescerem no lugar). O pip tem
		# 7 px: o centro fica no meio de um pixel (3.5).
		pip.position = Vector2(i * pip_step + 3.5, 3.5)
		pips_root.add_child(pip)
		_pips.append(pip)
	_refresh_pips()


## Um TextureProgressBar por segmento. Cada um enche de 0 até heal_cost.
func _create_segments() -> void:
	var count := ceili(float(player.max_soul) / player.heal_cost)
	for i in count:
		var segment := TextureProgressBar.new()
		segment.texture_under = SEGMENT_UNDER
		segment.texture_progress = SEGMENT_PROGRESS
		segment.max_value = player.heal_cost
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.position = Vector2(i * segment_step, 0)
		segment.size = Vector2(12, 4)
		segment.pivot_offset = segment.size / 2.0
		soul_root.add_child(segment)
		_segments.append(segment)


## Estica o traço até o fim do que for mais comprido (pips ou alma).
func _layout_trace() -> void:
	var pips_end := pips_root.position.x + _pips.size() * pip_step
	var soul_end := soul_root.position.x + (_segments.size() - 1) * segment_step + 12
	var end_x := maxf(pips_end, soul_end) + 2
	trace.size.x = end_x - trace.position.x
	trace_dot.position.x = end_x


## Entrada: o painel desliza da esquerda e os pips aparecem um por um.
func _intro() -> void:
	modulate.a = 0.0
	position = _base_position - Vector2(24, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "position", _base_position, 0.6) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in _pips.size():
		_pips[i].scale = Vector2.ZERO
		tween.tween_property(_pips[i], "scale", Vector2.ONE, 0.3) \
			.set_delay(0.25 + i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- A cada frame --------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _ghost_timer > 0.0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost = _health
			_refresh_pips()

	_update_soul(delta)
	_update_warnings()


func _update_soul(delta: float) -> void:
	# Suavização exponencial: anda uma FRAÇÃO da distância a cada frame
	# (rápido no começo, desacelerando). O exp() deixa igual em qualquer FPS.
	_soul_shown = lerpf(_soul_shown, player.soul, 1.0 - exp(-soul_smoothing * delta))
	_soul_flash = maxf(_soul_flash - delta * 3.0, 0.0)

	var full := 0
	for i in _segments.size():
		var segment := _segments[i]
		segment.value = clampf(_soul_shown - i * player.heal_cost, 0.0, player.heal_cost)
		var color := soul_color
		if segment.value >= player.heal_cost - 0.5:
			full += 1
			# Segmento cheio = uma cura disponível: pulsa suave entre branco e ciano.
			color = soul_color.lerp(soul_ready_color, 0.6 + 0.4 * sin(_time * 5.0 + i))
		segment.tint_progress = color.lerp(Color.WHITE, _soul_flash)

	# Um segmento acabou de encher (no DESENHO, sincronizado com a barra).
	if full > _full_segments:
		var segment := _segments[full - 1]
		_pop(segment, 1.5)
		Sound.play("soul_ready", 0.03)
		Juice.neon_burst_ui(soul_root, segment.position + Vector2(6, 2), 8, Vector2.ZERO, 180.0,
			{"weights_main": Vector3(0.5, 0.5, 1.5), "weights_special": Vector3(0.5, 2.0, 0.5)})
	_full_segments = full


func _update_warnings() -> void:
	# Emblema: brilha em ciano enquanto dá para curar.
	var can_heal := player.soul >= player.heal_cost
	var target := soul_ready_color if can_heal else Color.WHITE
	var pulse := 0.5 + 0.5 * sin(_time * 4.0) if can_heal else 0.0
	crest.modulate = Color.WHITE.lerp(target, pulse * 0.7)

	# Vida baixa: o último pip pisca em laranja (a cor de PERIGO).
	for i in _pips.size():
		_pips[i].modulate = Color.WHITE
	if _health == 1:
		_pips[0].modulate = Color.WHITE.lerp(Palette.WARM, 0.5 + 0.5 * sin(_time * 8.0))


func _refresh_pips() -> void:
	for i in _pips.size():
		if i < _health:
			_pips[i].frame = FRAME_FULL
		elif i < _ghost:
			_pips[i].frame = FRAME_LOST
		else:
			_pips[i].frame = FRAME_EMPTY


# --- Sinais do Player ----------------------------------------------------------

func _on_health_changed(health: int, _max_health: int) -> void:
	if health < _health:
		# Cada pip perdido estoura: branco, rosa e preto.
		for i in range(health, _health):
			_pop(_pips[i], 1.8)
			Juice.neon_burst_ui(pips_root, _pips[i].position, 7, Vector2.ZERO, 180.0,
				{"weights_main": Vector3(1.0, 0.0, 2.0), "weights_special": Vector3(1.5, 0.0, 0.5)})
		_ghost_timer = 0.4
		_shake()
	else:
		# Pips recuperados: verde e branco, e o emblema "pulsa".
		for i in range(_health, health):
			_pop(_pips[i], 1.8)
			Juice.neon_burst_ui(pips_root, _pips[i].position, 7, Vector2.ZERO, 180.0,
				{"weights_main": Vector3(0.5, 2.0, 1.0), "weights_special": Vector3.ZERO})
		_ghost = health
		_pop(crest, 1.3)
	_health = health
	_refresh_pips()


func _on_soul_changed(soul: int, _max_soul: int) -> void:
	if soul > _soul_shown:
		_soul_flash = 1.0


# --- Animações -----------------------------------------------------------------

## "Pulo": aumenta e volta ao normal com um quique (TRANS_BACK).
## `node` pode ser um Sprite2D ou um Control: os dois têm `scale`, mas não
## numa classe-mãe em comum, então usamos set() pelo nome da propriedade.
func _pop(node: CanvasItem, amount: float) -> void:
	node.set("scale", Vector2.ONE * amount)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tremida que vai DIMINUINDO (fica mais suave que uma tremida constante).
func _shake() -> void:
	var tween := create_tween()
	for i in 5:
		var strength := 4.0 * (1.0 - i / 5.0)
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.6)
		tween.tween_property(self, "position", _base_position + offset, 0.035)
	tween.tween_property(self, "position", _base_position, 0.06)
