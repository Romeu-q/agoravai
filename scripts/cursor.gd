extends Node
## Troca o cursor do mouse pela imagem assets/Cursor/Cursor.png.


const CURSOR_TEXTURE := preload("res://assets/Cursor/Cursor.png")

## A imagem tem 16x16 pixels: pequena demais numa tela grande, então ampliamos.
@export var cursor_scale := 3
## Pixel da imagem (antes de ampliar) que marca a "ponta" do cursor.
@export var hotspot := Vector2(1, 1)


func _ready() -> void:
	var image := CURSOR_TEXTURE.get_image()
	# INTERPOLATE_NEAREST mantém os pixels "quadradinhos" (sem borrar).
	image.resize(image.get_width() * cursor_scale, image.get_height() * cursor_scale, Image.INTERPOLATE_NEAREST)
	var cursor := ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot * cursor_scale)
