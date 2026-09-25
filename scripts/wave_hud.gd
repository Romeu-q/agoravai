extends Control
## Parte da HUD das waves (estilo Brotato + HLD):
##        ◆  WAVE 3  ◆
##             17
##     ━━━━━━━━━━━━━━━━━━        <- barra de tempo (esvazia durante a wave)
## e o BANNER de transição no meio da tela ("WAVE 2", "WAVE COMPLETA"):
## o texto é "digitado", duas linhas saem do centro e estouram em neon nas pontas.
## Escuta os sinais do WaveManager.


const WARNING_SECONDS := 5
const TIME_BAR_WIDTH := 180.0
const BANNER_LINE_LENGTH := 150.0
## Espaço entre o texto do banner e o começo das linhas.
const BANNER_GAP := 24.0
## Esta parte da HUD não tem scale: o neon aqui é ampliado 3x.
const UI_SCALE := 3.0
const MINT := Color(0.75, 0.96, 0.88, 1.0)

var waves: WaveManager
var _last_second := -1
var _duration := 1.0
var _bar_shown := 0.0   # desenhado: desliza até o valor real
var _time := 0.0
var _banner_tween: Tween

@onready var wave_label: Label = $WaveLabel
@onready var timer_label: Label = $TimerLabel
@onready var time_bar: ColorRect = $TimeBar
@onready var dot_left: TextureRect = $DotLeft
@onready var dot_right: TextureRect = $DotRight
@onready var banner: Label = $Banner
@onready var line_left: ColorRect = $BannerLineLeft
@onready var line_right: ColorRect = $BannerLineRight
@onready var flash: ColorRect = $Flash


func _ready() -> void:
	waves = get_tree().get_first_node_in_group("wave_manager")
	waves.wave_started.connect(_on_wave_started)
	waves.wave_ended.connect(_on_wave_ended)
	banner.visible = false
	timer_label.text = ""
	_set_bar(0.0)
	# Entrada da partida: começa escuro (como o menu terminou) e clareia.
	flash.color = Color(0.02, 0.05, 0.06, 1.0)
	create_tween().tween_property(flash, "color", Color(MINT, 0.0), 0.8) \
		.set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_time += delta
	# Barra de tempo: durante a wave segue o timer; no intervalo esvazia.
	# Como ela DESLIZA até o alvo, o começo da wave vira uma animação de "encher".
	var target := waves.time_left / _duration if waves.in_wave else 0.0
	_bar_shown = lerpf(_bar_shown, target, 1.0 - exp(-8.0 * delta))
	_set_bar(_bar_shown)

	# Ornamentos respirando devagar.
	var breath := 0.65 + 0.35 * sin(_time * 2.5)
	dot_left.modulate.a = breath
	dot_right.modulate.a = breath

	if waves.in_wave:
		_update_timer()


func _update_timer() -> void:
	var seconds := ceili(waves.time_left)
	if seconds == _last_second:
		return
	_last_second = seconds
	timer_label.text = str(seconds)

	# Contagem final: laranja (perigo), "pulo" e um estouro neon laranja a cada segundo.
	if seconds <= WARNING_SECONDS:
		timer_label.modulate = Palette.WARM
		time_bar.color = Palette.WARM
		_pop(timer_label, 1.5)
		Sound.play("tick", 0.0)
		Juice.neon_burst_ui(self, Vector2(size.x / 2.0, 60.0), 5, Vector2.ZERO, 180.0,
			{"color_pink": Palette.WARM, "weights_special": Vector3(2.0, 0.0, 0.0),
			"weights_main": Vector3(0.5, 0.0, 1.0)}, UI_SCALE)


## Barra centralizada: muda as duas bordas para ela encolher em direção ao meio.
func _set_bar(ratio: float) -> void:
	var width := TIME_BAR_WIDTH * clampf(ratio, 0.0, 1.0)
	time_bar.offset_left = -width / 2.0
	time_bar.offset_right = width / 2.0


func _on_wave_started(wave: int, duration: float) -> void:
	_duration = duration
	_last_second = -1
	wave_label.text = "WAVE %d" % wave
	_place_dots()
	_pop(wave_label, 1.4)
	timer_label.modulate = Color.WHITE
	time_bar.color = Color(MINT, 0.9)
	if wave > 1:   # na wave 1 quem está na tela é o fade de entrada
		_flash_screen(0.12)
	_show_banner("WAVE %d" % wave, Palette.GREEN)
	Sound.play("wave_start", 0.0)


func _on_wave_ended(_wave: int) -> void:
	timer_label.text = ""
	_flash_screen(0.2)
	_show_banner("WAVE COMPLETA", Palette.CYAN)
	Sound.play("wave_complete", 0.0)
	# Comemoração: estouro neon no centro do banner.
	Juice.neon_burst_ui(self, _banner_center(), 16, Vector2.ZERO, 180.0, {}, UI_SCALE)


## Coloca os losangos logo antes e depois do texto (a largura muda com o número).
func _place_dots() -> void:
	var font := wave_label.get_theme_font("font")
	var font_size := wave_label.get_theme_font_size("font_size")
	var half := font.get_string_size(wave_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	dot_left.offset_left = -half - 21.0
	dot_left.offset_right = -half - 12.0
	dot_right.offset_left = half + 12.0
	dot_right.offset_right = half + 21.0


# --- Banner --------------------------------------------------------------------

## Centro do banner em coordenadas deste Control (âncora vertical em 35% da tela).
func _banner_center() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.35)


func _show_banner(text: String, line_color: Color) -> void:
	if _banner_tween:
		_banner_tween.kill()

	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	banner.visible_ratio = 0.0   # 0 = nenhuma letra aparece ainda
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ONE * 1.25

	# As linhas começam com largura zero, encostadas no texto.
	var font := banner.get_theme_font("font")
	var font_size := banner.get_theme_font_size("font_size")
	var gap := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0 + BANNER_GAP
	for line in [line_left, line_right]:
		line.visible = true
		line.color = line_color
		line.modulate.a = 1.0
	line_left.offset_left = -gap
	line_left.offset_right = -gap
	line_right.offset_left = gap
	line_right.offset_right = gap

	_banner_tween = create_tween()
	# 1) ENTRADA (tudo junto): letras digitadas, texto assenta, linhas saem do centro.
	_banner_tween.set_parallel()
	_banner_tween.tween_property(banner, "visible_ratio", 1.0, 0.35)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(line_left, "offset_left", -gap - BANNER_LINE_LENGTH, 0.45) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(line_right, "offset_right", gap + BANNER_LINE_LENGTH, 0.45) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 2) As pontas das linhas estouram em neon (chain = espera a entrada acabar).
	_banner_tween.chain().tween_callback(_burst_line_ends.bind(gap))
	# 3) Segura na tela.
	_banner_tween.chain().tween_interval(0.9)
	# 4) SAÍDA: texto some e as linhas recolhem de volta para o centro.
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_property(line_left, "offset_left", -gap, 0.35) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_banner_tween.tween_property(line_right, "offset_right", gap, 0.35) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_banner_tween.chain().tween_callback(_hide_banner)


func _burst_line_ends(gap: float) -> void:
	var center := _banner_center()
	var reach := gap + BANNER_LINE_LENGTH
	Juice.neon_burst_ui(self, center + Vector2(-reach, 0), 6, Vector2.LEFT, 70.0, {}, UI_SCALE)
	Juice.neon_burst_ui(self, center + Vector2(reach, 0), 6, Vector2.RIGHT, 70.0, {}, UI_SCALE)


func _hide_banner() -> void:
	banner.visible = false
	line_left.visible = false
	line_right.visible = false


# --- Pequenas animações --------------------------------------------------------

## Clarão na tela inteira que some rápido (transição entre waves).
func _flash_screen(alpha: float) -> void:
	flash.color.a = alpha
	create_tween().tween_property(flash, "color:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Aumenta o label e volta ao normal (pivot no centro para crescer "no lugar").
func _pop(label: Label, amount: float) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * amount
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
