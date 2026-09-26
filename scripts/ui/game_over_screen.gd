class_name GameOverScreen
extends CanvasLayer
## Tela de FIM DE JOGO: "VOCE CAIU", a wave alcançada (grande), inimigos
## derrotados, tempo e recorde. O jogo fica pausado por trás.
## process_mode ALWAYS: funciona com o jogo pausado.


const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var title: Label = $Root/Title
@onready var wave_label: Label = $Root/Wave
@onready var kills_label: Label = $Root/Stats/Kills
@onready var time_label: Label = $Root/Stats/Time
@onready var record_label: Label = $Root/Stats/Record
@onready var buttons: VBoxContainer = $Root/Buttons

var _new_record := false
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	$Root/Buttons/Retry.pressed.connect(_retry)
	$Root/Buttons/Menu.pressed.connect(_to_menu)


func _process(delta: float) -> void:
	if not root.visible:
		return
	_time += delta
	# "NOVO RECORDE!" pulsa entre ciano e branco (brilhando).
	if _new_record:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		record_label.modulate = Color(0.0, 1.4, 1.5).lerp(Color(1.6, 1.6, 1.6), pulse)


func open(wave: int, kills: int, seconds: float, best_wave: int, new_record: bool) -> void:
	_new_record = new_record
	get_tree().paused = true
	Sound.set_slow_motion(true)   # música abafada por trás
	root.visible = true

	# Estado inicial de tudo (invisível), depois entra em sequência.
	dim.modulate.a = 0.0
	title.visible_ratio = 0.0
	wave_label.modulate.a = 0.0
	wave_label.text = "WAVE 0"
	for label in [kills_label, time_label, record_label]:
		label.modulate.a = 0.0
	buttons.modulate.a = 0.0
	record_label.text = "NOVO RECORDE!" if new_record else "RECORDE: WAVE %d" % best_wave

	var tween := create_tween()
	tween.tween_property(dim, "modulate:a", 1.0, 0.4)
	tween.tween_property(title, "visible_ratio", 1.0, 0.5)
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.2)
	# Conta de 0 até a wave alcançada (tween_method chama a função a cada frame).
	tween.tween_method(func(value: float): wave_label.text = "WAVE %d" % roundi(value),
		0.0, float(wave), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		Sound.play("wave_start", 0.0)
		Juice.neon_burst_ui(root, wave_label.position + wave_label.size / 2.0, 14,
			Vector2.ZERO, 180.0, {}, 3.0))
	tween.tween_property(kills_label, "modulate:a", 1.0, 0.2)
	tween.tween_method(func(value: float): kills_label.text = "INIMIGOS DERROTADOS: %d" % roundi(value),
		0.0, float(kills), 0.4)
	tween.tween_callback(func(): time_label.text = "TEMPO: " + _format_time(seconds))
	tween.tween_property(time_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(record_label, "modulate:a", 1.0, 0.25)
	if new_record:
		tween.tween_callback(func():
			Sound.play("wave_complete", 0.0)
			Juice.neon_burst_ui(root, record_label.global_position + record_label.size / 2.0,
				18, Vector2.ZERO, 180.0, {"weights_special": Vector3(1.0, 2.0, 1.0)}, 3.0))
	tween.tween_property(buttons, "modulate:a", 1.0, 0.3)
	tween.tween_callback($Root/Buttons/Retry.grab_focus)


## 125.3 segundos -> "2:05".
func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _retry() -> void:
	_leave()
	get_tree().reload_current_scene()


func _to_menu() -> void:
	_leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _leave() -> void:
	get_tree().paused = false
	Juice.slow_motion(1.0)
	Engine.time_scale = 1.0
