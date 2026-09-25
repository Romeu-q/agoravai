class_name NeonButton
extends Button
## Botão de menu no estilo neon/Drifter: só o texto, sem caixa.
## Selecionado (mouse OU teclado/controle) ele:
##   - fica verde e brilhando (cor acima de 1.0 = Glow do WorldEnvironment);
##   - ganha um losango de cada lado, que "abre" a partir do texto;
##   - dá um pulinho, toca "ui_move" e solta um mini neon burst.
## Mouse e teclado usam o MESMO caminho: passar o mouse dá foco (grab_focus),
## então só existe um botão selecionado por vez.


const DOT := preload("res://assets/UI/hud_dot.png")
const IDLE_COLOR := Color(0.75, 0.96, 0.88, 0.55)
const FOCUS_COLOR := Color(0.224, 1.0, 0.078)
## Brilho do texto selecionado (acima de 1 = halo de luz).
const GLOW := 1.6
## Distância dos losangos até a borda do texto (px).
const DOT_GAP := 16.0

var _dots: Array[TextureRect] = []
var _tween: Tween


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	# Tira as caixas padrão do Godot (inclusive o retângulo de foco).
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(color, IDLE_COLOR)
	add_theme_color_override("font_focus_color", FOCUS_COLOR)

	for i in 2:
		var dot := TextureRect.new()
		dot.texture = DOT
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.size = Vector2(9, 9)   # 3x3 px ampliado 3x
		dot.pivot_offset = dot.size / 2.0
		dot.modulate = Color(FOCUS_COLOR * GLOW, 0.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)

	mouse_entered.connect(grab_focus)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)


## Muda o texto sem perder a animação (usado pelas opções: "MUSICA - 80% +").
func set_label(new_text: String) -> void:
	text = new_text
	if has_focus():
		_place_dots(1.0)


func _on_focus_entered() -> void:
	Sound.play("ui_move", 0.04)
	self_modulate = Color(GLOW, GLOW, GLOW)
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 1.12
	_animate_dots(true)
	Juice.neon_burst_ui(self, size / 2.0, 5, Vector2.ZERO, 180.0,
		{"weights_special": Vector3(0.5, 1.0, 0.3), "speed_max": 40.0}, 2.0)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_focus_exited() -> void:
	self_modulate = Color.WHITE
	_animate_dots(false)


func _on_pressed() -> void:
	Sound.play("ui_select", 0.0)
	Juice.neon_burst_ui(self, size / 2.0, 12, Vector2.ZERO, 180.0, {}, 2.5)


## Losangos saem do texto para fora (aparecendo) ou voltam (sumindo).
func _animate_dots(show: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_place_dots, 0.0 if show else 1.0, 1.0 if show else 0.0, 0.2) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for dot in _dots:
		_tween.tween_property(dot, "modulate:a", 1.0 if show else 0.0, 0.15)


## `amount` 0 = losangos colados no centro, 1 = na posição final.
func _place_dots(amount: float) -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var half := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	var center := size / 2.0 - _dots[0].size / 2.0
	var reach := (half + DOT_GAP) * amount
	_dots[0].position = center + Vector2(-reach, 0)
	_dots[1].position = center + Vector2(reach, 0)
