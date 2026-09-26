class_name UpgradeCard
extends Button
## Um card de melhoria (criado por código pela UpgradeScreen).
##   ▬▬▬▬▬▬▬▬▬▬▬   <- faixa na cor da melhoria
##   LAMINA AFIADA
##   NIVEL 2/3
##   +1 DE DANO NO ATAQUE.
## Borda fina (sem preto) que acende na cor da melhoria quando selecionado.


const CARD_SIZE := Vector2(250, 190)
const MINT := Color(0.75, 0.96, 0.88)

var upgrade: Upgrade

var _normal_style := StyleBoxFlat.new()
var _focus_style := StyleBoxFlat.new()


func setup(new_upgrade: Upgrade, level: int) -> void:
	upgrade = new_upgrade
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	pivot_offset = CARD_SIZE / 2.0

	# Fundo escuro + borda fina. Selecionado: borda mais grossa na cor da melhoria.
	_normal_style.bg_color = Color(0.02, 0.07, 0.08, 0.92)
	_normal_style.border_color = Color(MINT, 0.35)
	_normal_style.set_border_width_all(1)
	_focus_style.bg_color = Color(0.03, 0.1, 0.11, 0.95)
	_focus_style.border_color = upgrade.color * 1.4   # acima de 1: brilha
	_focus_style.set_border_width_all(2)
	for state in ["normal", "disabled"]:
		add_theme_stylebox_override(state, _normal_style)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, _focus_style)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(0, 4)
	stripe.color = upgrade.color * 1.3
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stripe)

	box.add_child(_label(upgrade.title, 24, upgrade.color * 1.2))
	# Nível que vai ficar / máximo (a fonte não tem ">", então nada de "1 -> 2").
	box.add_child(_label("NIVEL %d/%d" % [level + 1, upgrade.max_level], 16, Color(MINT, 0.55)))
	var description := _label(upgrade.description, 16, MINT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(description)

	mouse_entered.connect(grab_focus)
	focus_entered.connect(_on_focus_entered)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_focus_entered() -> void:
	Sound.play("ui_move", 0.04)
	scale = Vector2.ONE * 1.06
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
