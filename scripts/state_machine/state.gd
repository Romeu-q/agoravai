class_name State
extends Node
## Classe base de um estado. Cada estado (Idle, Walk, Dash...) herda desta
## e sobrescreve só as funções de que precisa.


## Emitido quando o estado quer trocar para outro. A StateMachine escuta
## este sinal e faz a troca; o estado não precisa conhecer os outros estados.
signal transitioned(new_state_name: StringName)


## Chamado quando a máquina ENTRA neste estado.
func enter() -> void:
	pass


## Chamado quando a máquina SAI deste estado.
func exit() -> void:
	pass


## Chamado a cada frame de física enquanto este é o estado atual.
func physics_update(_delta: float) -> void:
	pass
