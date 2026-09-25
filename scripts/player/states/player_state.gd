class_name PlayerState
extends State
## Base dos estados do Player: só adiciona o atalho `player`.


## `owner` é o node raiz da cena onde este node foi salvo (o Player).
@onready var player: Player = owner
