extends Node
## MODO DE CONTROLE (AUTOLOAD "InputMode"): sabe se o jogador está usando
## CONTROLE ou TECLADO/MOUSE, pelo último botão/eixo que ele mexeu.
## - No controle, o cursor do mouse some e a mira vem do analógico direito.
## - `label("parry")` devolve o nome certo da tecla ("RB" ou "CLIQUE DIR.")
##   para os textos do tutorial e do menu.


signal changed(using_gamepad: bool)

## Nome de cada ação: [teclado/mouse, controle].
const LABELS := {
	"move": ["WASD", "ANALOGICO ESQ."],
	"aim": ["MOUSE", "ANALOGICO DIR."],
	"attack": ["CLIQUE ESQ.", "X"],
	"dash": ["ESPACO", "A"],
	"parry": ["CLIQUE DIR.", "RB"],
	"heal": ["F", "Y"],
	"extract": ["E", "B"],
	"pause": ["ESC", "START"],
}
## Mexer o analógico menos que isso não conta (evita trocar de modo à toa).
const STICK_THRESHOLD := 0.4

var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Já tem controle conectado ao abrir? Começa no modo controle.
	if not Input.get_connected_joypads().is_empty():
		_set_gamepad(true)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_gamepad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_THRESHOLD:
		_set_gamepad(true)
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		_set_gamepad(false)
	elif event is InputEventMouseButton or event is InputEventKey:
		_set_gamepad(false)


## Direção do analógico direito (Vector2.ZERO se estiver solto).
func aim_vector() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")


func label(action: String) -> String:
	return LABELS[action][1 if using_gamepad else 0]


## Vibração do controle (fraco/forte de 0 a 1). Só no modo controle.
func vibrate(weak: float, strong: float, duration: float) -> void:
	if not using_gamepad or not Settings.screen_shake:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


func _set_gamepad(value: bool) -> void:
	if value == using_gamepad:
		return
	using_gamepad = value
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	changed.emit(value)
