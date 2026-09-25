class_name LaserBeam
extends Node2D
## Laser geométrico que DESCE do céu até a posição deste nó (o chão).
## Três fases, controladas pelo tempo em _process:
##   1. DESCIDA: a ponta sai do alto e chega ao chão (fino);
##   2. PULSO: engrossa e pulsa em degraus de pixel, soltando faíscas no chão;
##   3. COLAPSO: afina degrau por degrau até sumir.
## Ao terminar emite `finished` e se apaga.
## A largura muda em DEGRAUS inteiros (9, 7, 5...) para parecer pixel art,
## e a cor passa de 1.0: brilha com o Glow.


signal finished

## Altura de onde o laser vem (px acima deste nó). Passa do topo da tela.
@export var height := 260.0
@export var descend_time := 0.12
@export var hold_time := 0.5
@export var collapse_time := 0.12
## Larguras do pulso (alterna entre elas) e do colapso (em ordem).
@export var pulse_widths: Array[float] = [9.0, 7.0]
@export var collapse_widths: Array[float] = [9.0, 5.0, 3.0, 1.0]

var _time := 0.0
var _hit := false

@onready var beam: Line2D = $Beam


func _ready() -> void:
	beam.width = 3.0
	beam.points = PackedVector2Array([Vector2(0, -height), Vector2(0, -height)])
	Sound.play("laser", 0.0)


func _process(delta: float) -> void:
	_time += delta

	if _time < descend_time:
		# 1) Descida: EXPO_IN = começa devagar e cai cada vez mais rápido.
		var t := ease(_time / descend_time, 3.0)
		beam.points = PackedVector2Array([Vector2(0, -height), Vector2(0, lerpf(-height, 0.0, t))])
		return

	if not _hit:
		_hit = true
		beam.points = PackedVector2Array([Vector2(0, -height), Vector2.ZERO])
		_on_hit_ground()

	var hold_end := descend_time + hold_time
	if _time < hold_end:
		# 2) Pulso: troca de largura a cada 0.05 s (degraus, sem suavizar).
		var step := int((_time - descend_time) / 0.05)
		beam.width = pulse_widths[step % pulse_widths.size()]
		return

	var collapse := (_time - hold_end) / collapse_time
	if collapse < 1.0:
		# 3) Colapso: cada degrau da lista por uma fração igual do tempo.
		var index := mini(int(collapse * collapse_widths.size()), collapse_widths.size() - 1)
		beam.width = collapse_widths[index]
		return

	finished.emit()
	queue_free()


## O raio tocou o chão: anel, faíscas neon e tremida.
func _on_hit_ground() -> void:
	Juice.ring(global_position, Palette.GREEN, 12.0, 0.25)
	Juice.neon_burst(global_position, 10, Vector2.UP, 70.0,
		{"weights_main": Vector3(0.5, 2.0, 1.5), "weights_special": Vector3(0.3, 1.5, 0.3),
		"speed_max": 90.0})
	Juice.shake(0.25)
