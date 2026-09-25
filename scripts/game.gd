class_name Game
extends Node2D


## Retângulo do mapa em pixels (o WaveManager usa para sortear onde nascer).
var bounds: Rect2

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var floor_pattern: Sprite2D = $TileMapLayer/FloorPattern


func _ready() -> void:
	Sound.play_music(Sound.GAME_MUSIC)   # vindo do menu, troca de trilha com fade
	bounds = _get_map_bounds()
	_limit_camera(bounds)
	_create_walls(bounds)
	_cover_floor(bounds)


# Estica o desenho geométrico do chão pelo mapa inteiro.
# Com Region ligada e Texture Repeat = Enabled, uma região MAIOR que a textura
# faz ela se repetir (como um papel de parede). A opacidade baixa vem do modulate.
func _cover_floor(map_bounds: Rect2) -> void:
	floor_pattern.global_position = map_bounds.position
	floor_pattern.region_rect = Rect2(Vector2.ZERO, map_bounds.size)


# Retorna o retângulo (em pixels, coordenadas globais) ocupado pelos tiles pintados.
func _get_map_bounds() -> Rect2:
	var used := tile_map.get_used_rect()          # em células: posição e tamanho
	var tile_size := Vector2(tile_map.tile_set.tile_size)

	var top_left := tile_map.to_global(Vector2(used.position) * tile_size)
	var bottom_right := tile_map.to_global(Vector2(used.end) * tile_size)
	return Rect2(top_left, bottom_right - top_left)


# A câmera continua seguindo o jogador, mas para de andar ao chegar na borda do mapa.
func _limit_camera(map_bounds: Rect2) -> void:
	camera.limit_left = int(map_bounds.position.x)
	camera.limit_top = int(map_bounds.position.y)
	camera.limit_right = int(map_bounds.end.x)
	camera.limit_bottom = int(map_bounds.end.y)


# Cria 4 paredes invisíveis (uma em cada lado do mapa) para o jogador não sair.
func _create_walls(map_bounds: Rect2) -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)

	# Cada parede é uma "linha infinita". O normal aponta para DENTRO do mapa
	# e distance é a posição da linha medida ao longo desse normal.
	_add_wall(walls, Vector2.RIGHT, map_bounds.position.x)   # esquerda
	_add_wall(walls, Vector2.LEFT, -map_bounds.end.x)        # direita
	_add_wall(walls, Vector2.DOWN, map_bounds.position.y)    # topo
	_add_wall(walls, Vector2.UP, -map_bounds.end.y)          # base


func _add_wall(body: StaticBody2D, normal: Vector2, distance: float) -> void:
	var shape := WorldBoundaryShape2D.new()
	shape.normal = normal
	shape.distance = distance

	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
