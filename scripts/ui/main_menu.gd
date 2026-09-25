extends Control
## TELA INICIAL (inspirada no pôster do Hyper Light Drifter):
## título grande brilhando no topo, faíscas neon subindo do chão e o menu no meio.
## Três painéis: Principal, Opções (cena reutilizável OptionsPanel) e Controles.
## ESC volta ao principal.


const GAME_SCENE := "res://scenes/game.tscn"
const DARK := Color(0.02, 0.05, 0.06)
## Tamanho do "pixel" do desenho do chão (o jogo usa zoom 4; aqui 3).
const PATTERN_SCALE := 3.0

var _time := 0.0
var _current_panel: Control
var _leaving := false

@onready var floor_pattern: TextureRect = $FloorPattern
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var line_left: ColorRect = $LineLeft
@onready var line_right: ColorRect = $LineRight
@onready var main_panel: Control = $Panels/Main
@onready var options_panel: OptionsPanel = $Panels/Options
@onready var controls_panel: Control = $Panels/Controls
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	Sound.play_music(Sound.MENU_MUSIC)
	# call_deferred: no _ready o tamanho da tela ainda pode não estar calculado.
	_fit_floor_pattern.call_deferred()
	get_viewport().size_changed.connect(_fit_floor_pattern)

	# Botões -> ações. bind() "prende" um argumento na chamada.
	$Panels/Main/Play.pressed.connect(_on_play)
	$Panels/Main/Options.pressed.connect(_show_panel.bind(options_panel))
	$Panels/Main/Controls.pressed.connect(_show_panel.bind(controls_panel))
	$Panels/Main/Quit.pressed.connect(get_tree().quit)
	$Panels/Controls/Back.pressed.connect(_back)
	# O painel de opções avisa quando quer voltar (botão VOLTAR ou ESC).
	options_panel.back_requested.connect(_show_panel.bind(main_panel))

	options_panel.visible = false
	controls_panel.visible = false
	_intro()


func _process(delta: float) -> void:
	_time += delta
	# Letreiro neon: brilha estável, mas às vezes "falha" por um instante.
	var flicker := 1.0
	if fmod(_time, 4.3) < 0.08 or fmod(_time + 1.7, 6.1) < 0.05:
		flicker = 0.55
	title.self_modulate = Color(1.5, 1.5, 1.5) * flicker


func _unhandled_input(event: InputEvent) -> void:
	# (O painel de opções cuida do próprio ESC.)
	if event.is_action_pressed("ui_cancel") and _current_panel == controls_panel:
		_back()
		get_viewport().set_input_as_handled()


# --- Intro e transições --------------------------------------------------------

func _intro() -> void:
	fade.color = Color(DARK, 1.0)
	title.visible_ratio = 0.0
	subtitle.modulate.a = 0.0
	line_left.scale.x = 0.0
	line_right.scale.x = 0.0
	main_panel.modulate.a = 0.0

	var tween := create_tween().set_parallel()
	tween.tween_property(fade, "color:a", 0.0, 1.2)
	# Título "digitado", depois as linhas abrem e o subtítulo aparece.
	tween.tween_property(title, "visible_ratio", 1.0, 0.8).set_delay(0.4)
	tween.tween_property(line_left, "scale:x", 1.0, 0.6).set_delay(1.1) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(line_right, "scale:x", 1.0, 0.6).set_delay(1.1) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.6).set_delay(1.3)
	tween.tween_callback(func(): Juice.neon_burst_ui(self, title.position + title.size / 2.0,
		18, Vector2.ZERO, 180.0, {}, 3.0)).set_delay(1.2)
	tween.chain().tween_callback(_show_panel.bind(main_panel, false))


## Troca de painel: o atual some descendo, o novo aparece subindo.
func _show_panel(panel: Control, animate_out := true) -> void:
	var old := _current_panel
	_current_panel = panel
	if old and animate_out:
		var out := create_tween().set_parallel()
		out.tween_property(old, "modulate:a", 0.0, 0.15)
		out.tween_property(old, "position:y", old.position.y + 12.0, 0.15)
		out.chain().tween_callback(func():
			old.visible = false
			old.position.y -= 12.0)
	panel.visible = true
	panel.modulate.a = 0.0
	var base_y := panel.position.y
	panel.position.y = base_y + 16.0
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_delay(0.12)
	tween.tween_property(panel, "position:y", base_y, 0.35).set_delay(0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Foco no primeiro controle: dá para jogar só com teclado/controle.
	if panel == options_panel:
		options_panel.focus_first()
	else:
		var first := _first_button(panel)
		if first:
			first.grab_focus.call_deferred()


func _back() -> void:
	Sound.play("ui_back", 0.0)
	_show_panel(main_panel)


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	# Tudo apaga para o escuro e o jogo começa (a música troca com fade).
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE))


# --- Utilidades ----------------------------------------------------------------

func _first_button(panel: Control) -> Button:
	for child in panel.get_children():
		if child is Button:
			return child
	return null


## O desenho do chão é ampliado 3x (pixel "gordo" como no jogo) e cobre a tela.
func _fit_floor_pattern() -> void:
	floor_pattern.scale = Vector2.ONE * PATTERN_SCALE
	floor_pattern.size = size / PATTERN_SCALE
