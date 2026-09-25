extends Node
## Troca o cursor do mouse por uma mira no estilo Drifter (assets/Cursor/cursor_drifter.png).
## O cursor antigo (Cursor.png) continua na pasta: é só trocar o caminho abaixo.


const CURSOR_TEXTURE := preload("res://assets/Cursor/cursor_drifter.png")

## A imagem tem 15x15 pixels: pequena demais numa tela grande, então ampliamos.
@export var cursor_scale := 3
## Pixel da imagem (antes de ampliar) que marca a "ponta" do cursor.
## Numa mira, a ponta é o CENTRO: (7, 7) numa imagem de 15x15.
@export var hotspot := Vector2(7, 7)


func _ready() -> void:
	var image := CURSOR_TEXTURE.get_image()
	# INTERPOLATE_NEAREST mantém os pixels "quadradinhos" (sem borrar).
	image.resize(image.get_width() * cursor_scale, image.get_height() * cursor_scale, Image.INTERPOLATE_NEAREST)
	var cursor := ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot * cursor_scale)
