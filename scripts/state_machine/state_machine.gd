class_name StateMachine
extends Node
## Guarda qual estado está ativo e repassa o _physics_process para ele.
## Os estados são os nodes filhos deste node.


@export var initial_state: State

var current_state: State
var states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(transition_to)

	# Os filhos ficam prontos antes do pai. Esperamos o dono da cena (o Player)
	# terminar o _ready dele, senão as variáveis @onready dele ainda seriam null.
	await owner.ready
	current_state = initial_state
	current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## Troca de estado. Os estados chamam isto pelo sinal `transitioned`; o dono
## (Player, Enemy) chama direto quando algo EXTERNO acontece, como tomar dano.
func transition_to(new_state_name: StringName) -> void:
	var new_state: State = states.get(new_state_name.to_lower())
	if new_state == null or new_state == current_state or current_state == null:
		return

	current_state.exit()
	current_state = new_state
	current_state.enter()
