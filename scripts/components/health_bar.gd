extends Node2D
## Barra de vida em "pips" (quadradinhos), no estilo de Hyper Light Drifter.
## Cada pip é um Sprite2D usando a spritesheet assets/UI/enemy_pip.png,
## que tem 3 frames: 0 = cheio (laranja = perigo), 1 = perdido (branco), 2 = vazio.
## Fica escondida e aparece por alguns segundos quando o dono toma dano.


const PIP_TEXTURE := preload("res://assets/UI/enemy_pip.png")
const FRAME_FULL := 0
const FRAME_LOST := 1
const FRAME_EMPTY := 2

@export var health: HealthComponent
## Distância entre pips (o pip tem 4 px de largura: sobra 1 px de espaço).
@export var pip_step := 5
@export var visible_time := 2.5

var _pips: Array[Sprite2D] = []
var _current := 0
var _ghost := 0          # pips entre _current e _ghost ficam brancos um instante
var _ghost_timer := 0.0
var _hide_timer := 0.0


func _ready() -> void:
	_current = health.max_health
	_ghost = _current
	_create_pips()
	visible = false
	health.health_changed.connect(_on_health_changed)


func _create_pips() -> void:
	var count := health.max_health
	var start_x := -(count - 1) * pip_step / 2.0
	for i in count:
		var pip := Sprite2D.new()
		pip.texture = PIP_TEXTURE
		pip.hframes = 3   # a imagem tem 3 frames lado a lado
		pip.position = Vector2(roundf(start_x + i * pip_step), 0)
		add_child(pip)
		_pips.append(pip)
	_refresh()


func _refresh() -> void:
	for i in _pips.size():
		if i < _current:
			_pips[i].frame = FRAME_FULL
		elif i < _ghost:
			_pips[i].frame = FRAME_LOST
		else:
			_pips[i].frame = FRAME_EMPTY


func _process(delta: float) -> void:
	if _ghost_timer > 0.0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost = _current
			_refresh()

	if visible and _current > 0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			visible = false


func _on_health_changed(new_health: int, _max_health: int) -> void:
	if new_health > _current:
		_ghost = new_health
	_current = new_health
	_ghost_timer = 0.3
	_hide_timer = visible_time
	visible = true
	_refresh()

	# "Pulo" rápido de escala: chama atenção para a barra.
	scale = Vector2(1.4, 1.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)
