extends Node
## OPÇÕES do jogador (AUTOLOAD "Settings"): volumes, tremor de tela e tela cheia.
## Ficam salvas em "user://settings.cfg": "user://" é uma pasta do Godot só
## para o jogo gravar dados do jogador (no Windows: %APPDATA%/Godot/app_userdata/<projeto>).
## Um ConfigFile é um arquivo de texto no formato:
##   [audio]
##   music=0.8


signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 1.0
var screen_shake := true
var fullscreen := false
## Recorde: a wave mais alta que o jogador já alcançou.
var best_wave := 0


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return   # primeira vez jogando: fica com os valores padrão
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	screen_shake = config.get_value("video", "screen_shake", screen_shake)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	best_wave = config.get_value("records", "best_wave", best_wave)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "screen_shake", screen_shake)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("records", "best_wave", best_wave)
	config.save(PATH)


## Registra a wave alcançada. Retorna true se for um NOVO recorde.
func submit_wave(wave: int) -> bool:
	if wave <= best_wave:
		return false
	best_wave = wave
	save_settings()
	return true


## Aplica tudo de uma vez (volumes nos buses, modo da janela) e salva.
func apply() -> void:
	Sound.set_music_volume(music_volume)
	Sound.set_sfx_volume(sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	save_settings()
	changed.emit()
