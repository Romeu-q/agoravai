extends Camera2D
## Câmera com "juice":
## - SHAKE por trauma: cada impacto soma trauma (0 a 1), que vai diminuindo sozinho.
##   O tremor usa trauma², então impactos pequenos tremem pouco e os grandes, muito.
## - RUMBLE: tremor contínuo enquanto algo pedir (ex.: carregando a cura).
## - PUNCH: zoom rápido que volta sozinho.
## - FOCUS: zoom que se mantém enquanto algo pedir (ex.: segurando F).


@export var max_offset := Vector2(6, 4)
@export var decay := 2.5   # quanto trauma some por segundo

var trauma := 0.0
var _rumble := 0.0
var _base_zoom: Vector2
var _punch := 0.0
var _focus_target := 0.0
var _focus := 0.0


func _ready() -> void:
	_base_zoom = zoom


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Tremor contínuo (0 = desliga). Não diminui sozinho.
func set_rumble(amount: float) -> void:
	_rumble = amount


func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


## Zoom mantido (0 = normal, 0.2 = 20% mais perto). Chega nele suavemente.
func set_focus(amount: float) -> void:
	_focus_target = amount


func _process(delta: float) -> void:
	trauma = maxf(trauma - decay * delta, 0.0)
	var power := maxf(trauma * trauma, _rumble * _rumble)
	offset = Vector2(
		randf_range(-1.0, 1.0) * max_offset.x * power,
		randf_range(-1.0, 1.0) * max_offset.y * power)

	# lerp com 1 - exp(-k * delta): suaviza igual em qualquer FPS.
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-10.0 * delta))
	_focus = lerpf(_focus, _focus_target, 1.0 - exp(-6.0 * delta))
	zoom = _base_zoom * (1.0 + _focus + _punch)
