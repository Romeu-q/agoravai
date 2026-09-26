extends CanvasLayer
## PAUSE: ESC durante a partida.
## `get_tree().paused = true` congela todos os nós com process_mode "Inherit"
## (o jogo inteiro). Este menu usa process_mode ALWAYS (no Inspector: Node >
## Process > Mode), então ele continua funcionando com o jogo parado.
## Enquanto pausado, a música fica abafada (o mesmo filtro da câmera lenta).


const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var _tween: Tween

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var title: Label = $Root/Title
@onready var main_panel: VBoxContainer = $Root/Main
@onready var options_panel: OptionsPanel = $Root/Options


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	$Root/Main/Resume.pressed.connect(close)
	$Root/Main/Options.pressed.connect(_show_options)
	$Root/Main/Menu.pressed.connect(_to_menu)
	options_panel.back_requested.connect(_show_main)


func _unhandled_input(event: InputEvent) -> void:
	# Abre/fecha com "pause" (ESC ou START). Com o menu aberto, "ui_cancel"
	# (o B do controle) também fecha. No jogo o B é EXTRAIR: ele não pode pausar.
	var toggle := event.is_action_pressed("pause")
	var back := root.visible and event.is_action_pressed("ui_cancel")
	if not (toggle or back):
		return
	# Já pausado por OUTRA coisa (fim de jogo, escolha de melhoria, tutorial):
	# o pause não abre por cima.
	if get_tree().paused and not root.visible:
		return
	# (Se as opções estiverem abertas, o próprio painel trata o ESC antes.)
	if root.visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	root.visible = true
	Sound.play("ui_back", 0.0)
	Sound.set_slow_motion(true)   # música abafada
	_show_main()

	# Entrada: escurece e o título desce um pouquinho.
	if _tween:
		_tween.kill()
	dim.modulate.a = 0.0
	title.modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	_tween.tween_property(title, "modulate:a", 1.0, 0.3)


func close() -> void:
	Sound.play("ui_select", 0.0)
	get_tree().paused = false
	root.visible = false
	# Volta a música ao normal (a não ser que o jogo esteja em câmera lenta).
	Sound.set_slow_motion(Engine.time_scale < 1.0)


func _show_main() -> void:
	options_panel.visible = false
	main_panel.visible = true
	$Root/Main/Resume.grab_focus.call_deferred()


func _show_options() -> void:
	main_panel.visible = false
	options_panel.visible = true
	options_panel.focus_first()


func _to_menu() -> void:
	get_tree().paused = false
	Juice.slow_motion(1.0)        # se pausou no meio da câmera lenta do parry
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)
