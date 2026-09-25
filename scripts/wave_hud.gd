extends Control
## Parte da HUD que mostra as waves (estilo Brotato):
## número da wave e contagem regressiva no topo, e um BANNER no meio da tela
## ("WAVE 2", "WAVE COMPLETA"). Escuta os sinais do WaveManager.


const WARNING_COLOR := Color("ff4d6d")
## Nos últimos segundos o timer fica vermelho e "pula" a cada segundo.
const WARNING_SECONDS := 5

var waves: WaveManager
var _last_second := -1
var _banner_tween: Tween

@onready var wave_label: Label = $WaveLabel
@onready var timer_label: Label = $TimerLabel
@onready var banner: Label = $Banner


func _ready() -> void:
	waves = get_tree().get_first_node_in_group("wave_manager")
	waves.wave_started.connect(_on_wave_started)
	waves.wave_ended.connect(_on_wave_ended)
	banner.visible = false
	timer_label.text = ""


func _process(_delta: float) -> void:
	if not waves.in_wave:
		return
	var seconds := ceili(waves.time_left)
	if seconds == _last_second:
		return
	_last_second = seconds
	timer_label.text = str(seconds)

	# Juice: contagem final em vermelho, com "pulo" a cada segundo.
	if seconds <= WARNING_SECONDS:
		timer_label.modulate = WARNING_COLOR
		_pop(timer_label, 1.5)


func _on_wave_started(wave: int, _duration: float) -> void:
	wave_label.text = "WAVE %d" % wave
	timer_label.modulate = Color.WHITE
	_pop(wave_label, 1.3)
	_show_banner("WAVE %d" % wave)


func _on_wave_ended(_wave: int) -> void:
	timer_label.text = ""
	_last_second = -1
	_show_banner("WAVE COMPLETA")


## Aumenta o label e volta ao normal (pivot no centro para crescer "no lugar").
func _pop(label: Label, amount: float) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * amount
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ONE * 1.8

	# Tween em sequência: entra com "quique", espera, some.
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.0)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(banner.hide)
