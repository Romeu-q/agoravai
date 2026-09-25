class_name OptionsPanel
extends VBoxContainer
## Painel de OPÇÕES reutilizável: usado no menu inicial E no pause.
## (Uma cena só, instanciada nos dois lugares: mudou aqui, muda nos dois.)
## - Volumes: HSlider (arraste, clique na barra ou use as setas ←/→).
## - Tremor de tela e tela cheia: botões que alternam SIM/NAO.
## Tudo vai para o autoload Settings, que aplica e salva na hora.


signal back_requested

const IDLE_COLOR := Color(0.75, 0.96, 0.88, 0.55)
const FOCUS_COLOR := Color(0.34, 1.5, 0.12)   # verde acima de 1.0: brilha

@onready var music_slider: HSlider = $Music/Slider
@onready var music_value: Label = $Music/Value
@onready var sfx_slider: HSlider = $Sfx/Slider
@onready var sfx_value: Label = $Sfx/Value
@onready var shake_button: NeonButton = $Shake
@onready var fullscreen_button: NeonButton = $Fullscreen


func _ready() -> void:
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	# value_changed só depois de colocar o valor inicial (senão tocaria som à toa).
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	for slider in [music_slider, sfx_slider]:
		var row: Control = slider.get_parent()
		slider.mouse_entered.connect(slider.grab_focus)
		slider.focus_entered.connect(_highlight_row.bind(row, true))
		slider.focus_exited.connect(_highlight_row.bind(row, false))
		_highlight_row(row, false)

	shake_button.pressed.connect(_toggle_shake)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	$Back.pressed.connect(_on_back)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


## Foco no primeiro controle (para funcionar só com teclado/controle).
func focus_first() -> void:
	music_slider.grab_focus.call_deferred()


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	Settings.apply()
	Sound.play("ui_move", 0.0)
	_refresh()


func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	Settings.apply()
	Sound.play("soul_ready", 0.0)   # amostra: dá para ouvir o volume dos efeitos
	_refresh()


func _toggle_shake() -> void:
	Settings.screen_shake = not Settings.screen_shake
	Settings.apply()
	_refresh()


func _toggle_fullscreen() -> void:
	Settings.fullscreen = not Settings.fullscreen
	Settings.apply()
	_refresh()


func _on_back() -> void:
	Sound.play("ui_back", 0.0)
	back_requested.emit()


func _refresh() -> void:
	music_value.text = "%d%%" % roundi(Settings.music_volume * 100)
	sfx_value.text = "%d%%" % roundi(Settings.sfx_volume * 100)
	shake_button.set_label("TREMOR DE TELA: " + ("SIM" if Settings.screen_shake else "NAO"))
	fullscreen_button.set_label("TELA CHEIA: " + ("SIM" if Settings.fullscreen else "NAO"))


## Linha selecionada: nome e porcentagem ficam verdes e brilhando.
func _highlight_row(row: Control, active: bool) -> void:
	for child in row.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", FOCUS_COLOR if active else IDLE_COLOR)
	if active:
		Sound.play("ui_move", 0.04)
