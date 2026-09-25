extends Control
## HUD do jogador, no estilo Hyper Light Drifter:
## - pips de vida: Sprite2D com a spritesheet assets/UI/hud_pip.png
##   (3 frames: 0 = cheio, 1 = perdido/branco, 2 = vazio);
## - medidor de ALMA: um TextureProgressBar (node pronto de barra com texturas).
## O node inteiro é ampliado pelo `scale` no Inspector.


const PIP_TEXTURE := preload("res://assets/UI/hud_pip.png")
const FRAME_FULL := 0
const FRAME_LOST := 1
const FRAME_EMPTY := 2

## 1 a menos que a largura do pip (8): as bordas pretas se sobrepõem.
@export var pip_step := 7
@export var soul_color := Color("e6e6f0")
@export var soul_ready_color := Color("7ff0ff")

var player: Player
var _pips: Array[Sprite2D] = []
var _health := 0
var _ghost := 0          # pips recém-perdidos ficam brancos um instante
var _ghost_timer := 0.0
var _soul_flash := 0.0   # brilho quando ganha alma
var _time := 0.0
var _base_scale: Vector2
var _base_position: Vector2

@onready var pips_root: Node2D = $Pips
@onready var soul_bar: TextureProgressBar = $SoulBar


func _ready() -> void:
	_base_scale = scale
	_base_position = position
	player = get_tree().get_first_node_in_group("player")
	_health = player.health.health
	_ghost = _health

	for i in player.health.max_health:
		var pip := Sprite2D.new()
		pip.texture = PIP_TEXTURE
		pip.hframes = 3
		pip.centered = false
		pip.position = Vector2(i * pip_step, 0)
		pips_root.add_child(pip)
		_pips.append(pip)
	_refresh_pips()

	soul_bar.max_value = player.max_soul
	soul_bar.value = player.soul

	player.health.health_changed.connect(_on_health_changed)
	player.soul_changed.connect(_on_soul_changed)


func _process(delta: float) -> void:
	_time += delta
	if _ghost_timer > 0.0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost = _health
			_refresh_pips()

	# Cor da alma: pulsa quando já dá para curar; fica branca ao ganhar alma.
	_soul_flash = maxf(_soul_flash - delta * 4.0, 0.0)
	var color := soul_color
	if soul_bar.value >= player.heal_cost:
		color = soul_color.lerp(soul_ready_color, 0.5 + 0.5 * sin(_time * 6.0))
	soul_bar.tint_progress = color.lerp(Color.WHITE, _soul_flash)


func _refresh_pips() -> void:
	for i in _pips.size():
		if i < _health:
			_pips[i].frame = FRAME_FULL
		elif i < _ghost:
			_pips[i].frame = FRAME_LOST
		else:
			_pips[i].frame = FRAME_EMPTY


func _on_health_changed(health: int, _max_health: int) -> void:
	var lost := health < _health
	_health = health
	if lost:
		_ghost_timer = 0.35
		_shake_hud()
	else:
		_ghost = health
		_pop()
	_refresh_pips()


func _on_soul_changed(soul: int, _max_soul: int) -> void:
	if soul > soul_bar.value:
		_soul_flash = 1.0
	soul_bar.value = soul


func _pop() -> void:
	scale = _base_scale * 1.15
	create_tween().tween_property(self, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_BACK)


func _shake_hud() -> void:
	var tween := create_tween()
	for _i in 4:
		tween.tween_property(self, "position", _base_position + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.03)
	tween.tween_property(self, "position", _base_position, 0.03)
