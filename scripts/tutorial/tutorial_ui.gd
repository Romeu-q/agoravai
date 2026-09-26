class_name TutorialUI
extends CanvasLayer
## Interface do TUTORIAL (o TutorialDirector decide o que mostrar):
## - Prompt: painel embaixo com o passo, a explicação e a TECLA (em "tecla de teclado");
## - Freeze: o jogo CONGELA e aparece a tecla grande no meio ("APARE!" + CLIQUE DIR.);
## - Success: "BOA!" pulando no topo;
## - Final: tela de conclusão com JOGAR / MENU PRINCIPAL.
## process_mode ALWAYS: funciona com o jogo congelado (pausado).


signal play_pressed
signal menu_pressed

var _pulse: Tween

@onready var prompt: PanelContainer = $Prompt
@onready var step_label: Label = $Prompt/Box/Step
@onready var text_label: Label = $Prompt/Box/Text
@onready var key_label: Label = $Prompt/Box/Key
@onready var freeze_root: Control = $Freeze
@onready var freeze_title: Label = $Freeze/Title
@onready var freeze_hint: Label = $Freeze/Hint
@onready var freeze_key: Label = $Freeze/Key
@onready var success_label: Label = $Success
@onready var final_root: Control = $Final


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt.visible = false
	freeze_root.visible = false
	success_label.visible = false
	final_root.visible = false
	$Final/Buttons/Play.pressed.connect(play_pressed.emit)
	$Final/Buttons/Menu.pressed.connect(menu_pressed.emit)


## Painel de instrução (o jogo continua rodando).
func show_prompt(step: String, text: String, key: String) -> void:
	var changed := text_label.text != text
	step_label.text = step
	text_label.text = text
	key_label.text = key
	key_label.visible = key != ""
	if not prompt.visible or changed:
		prompt.visible = true
		# Entrada: sobe um pouquinho e aparece; o texto é "digitado".
		prompt.modulate.a = 0.0
		text_label.visible_ratio = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(prompt, "modulate:a", 1.0, 0.2)
		tween.tween_property(text_label, "visible_ratio", 1.0, 0.5)
		Sound.play("ui_move", 0.0)


func hide_prompt() -> void:
	prompt.visible = false


## CONGELA o jogo e mostra a tecla grande. Quem descongela é o Director
## (quando o jogador aperta a tecla certa).
func freeze(title: String, hint: String, key: String) -> void:
	get_tree().paused = true
	Sound.set_slow_motion(true)
	Sound.play("windup", 0.0)
	freeze_title.text = title
	freeze_hint.text = hint
	freeze_key.text = key
	freeze_root.visible = true
	freeze_root.modulate.a = 0.0
	create_tween().tween_property(freeze_root, "modulate:a", 1.0, 0.15)
	Juice.neon_burst_ui(freeze_root, freeze_key.position + freeze_key.size / 2.0, 12,
		Vector2.ZERO, 180.0, {}, 3.0)
	# A tecla "respira" (aumenta e diminui) em loop até apertarem.
	freeze_key.pivot_offset = freeze_key.size / 2.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(freeze_key, "scale", Vector2.ONE * 1.12, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(freeze_key, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func unfreeze() -> void:
	if _pulse:
		_pulse.kill()
	freeze_key.scale = Vector2.ONE
	freeze_root.visible = false
	Sound.play("ui_select", 0.0)
	Sound.set_slow_motion(false)
	get_tree().paused = false


## "BOA!" no topo: pula e some.
func success(text: String) -> void:
	success_label.text = text
	success_label.visible = true
	success_label.modulate.a = 1.0
	success_label.pivot_offset = success_label.size / 2.0
	success_label.scale = Vector2.ONE * 1.5
	Sound.play("soul_ready", 0.0)
	Juice.neon_burst_ui(self, success_label.position + success_label.size / 2.0, 14,
		Vector2.ZERO, 180.0, {"weights_main": Vector3(0.5, 2.0, 1.0)}, 3.0)
	var tween := create_tween()
	tween.tween_property(success_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.6)
	tween.tween_property(success_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(success_label.hide)


## Tela final (pausa o jogo).
func show_final() -> void:
	get_tree().paused = true
	hide_prompt()
	final_root.visible = true
	final_root.modulate.a = 0.0
	create_tween().tween_property(final_root, "modulate:a", 1.0, 0.4)
	Sound.play("wave_complete", 0.0)
	$Final/Buttons/Play.grab_focus.call_deferred()
