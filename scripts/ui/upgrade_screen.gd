class_name UpgradeScreen
extends CanvasLayer
## ESCOLHA DE MELHORIA entre as waves (versão mínima da loja do Brotato).
## Escuta o `wave_ended` do WaveManager; depois do banner "WAVE COMPLETA",
## pausa o jogo e mostra 3 melhorias sorteadas. Escolheu -> aplica no jogador,
## despausa e avisa o WaveManager (finish_upgrade) para a próxima wave vir.


## Espera o banner "WAVE COMPLETA" terminar antes de abrir (segundos).
const OPEN_DELAY := 2.0

var waves: WaveManager
var player: Player
var _cards: Array[UpgradeCard] = []
var _choosing := false

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var title: Label = $Root/Title
@onready var cards_box: HBoxContainer = $Root/Cards


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	waves = get_tree().get_first_node_in_group("wave_manager")
	player = get_tree().get_first_node_in_group("player")
	waves.wave_ended.connect(_on_wave_ended)


func _on_wave_ended(_wave: int) -> void:
	if not waves.upgrades_enabled:
		return
	await get_tree().create_timer(OPEN_DELAY).timeout
	if player.health.is_dead():
		return   # morreu no fim da wave: a tela de fim de jogo cuida
	var options := UpgradeLibrary.pick(player)
	if options.is_empty():
		waves.finish_upgrade()   # já pegou tudo no nível máximo
		return
	open(options)


func open(options: Array[Upgrade]) -> void:
	_choosing = true
	get_tree().paused = true
	root.visible = true
	for card in _cards:
		card.queue_free()
	_cards.clear()

	for upgrade in options:
		var card := UpgradeCard.new()
		card.setup(upgrade, player.get_upgrade_level(upgrade))
		card.pressed.connect(_choose.bind(card))
		cards_box.add_child(card)
		_cards.append(card)

	# Entrada: escurece, título digitado, cards sobem um por um.
	dim.modulate.a = 0.0
	title.visible_ratio = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.25)
	tween.tween_property(title, "visible_ratio", 1.0, 0.4)
	for i in _cards.size():
		var card := _cards[i]
		card.modulate.a = 0.0
		tween.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(0.2 + i * 0.1)
	Sound.play("wave_start", 0.0)
	tween.chain().tween_callback(_cards[0].grab_focus)


func _choose(card: UpgradeCard) -> void:
	if not _choosing:
		return
	_choosing = false
	player.apply_upgrade(card.upgrade)
	Sound.play("ui_select", 0.0)
	Juice.neon_burst_ui(root, card.global_position + card.size / 2.0, 20, Vector2.ZERO,
		180.0, {"color_pink": card.upgrade.color}, 3.0)

	# O escolhido "pula"; os outros somem; depois a tela inteira some.
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE * 1.12, 0.12)
	for other in _cards:
		if other != card:
			tween.tween_property(other, "modulate:a", 0.0, 0.2)
	tween.chain().tween_interval(0.35)
	tween.chain().tween_property(root, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(_close)


func _close() -> void:
	root.visible = false
	root.modulate.a = 1.0
	get_tree().paused = false
	waves.finish_upgrade()
