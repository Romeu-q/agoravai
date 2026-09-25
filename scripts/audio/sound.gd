extends Node
## SOM do jogo. É um AUTOLOAD (Project Settings > Globals), como o Juice:
## qualquer script chama `Sound.play("slash")`.
##
## - Trilhas: assets/Audio/Music/, em loop, no bus "Music". Cada cena escolhe a
##   sua com `Sound.play_music(Sound.MENU_MUSIC)` (troca com fade).
## - Efeitos: assets/Audio/SFX/<nome>.wav, no bus "SFX".
## Os BUSES são como canais de uma mesa de som: dá para mudar o volume de toda
## a música ou de todos os efeitos de uma vez (veja a aba "Audio" embaixo no editor).
## Em câmera lenta a música fica abafada e mais grave.


const GAME_MUSIC := preload("res://assets/Audio/Music/soundtrack.wav")
const MENU_MUSIC := preload("res://assets/Audio/Music/menu.wav")
const SFX_DIR := "res://assets/Audio/SFX/"

## Volume de cada efeito em dB (0 = como o arquivo; -6 = mais ou menos a metade).
const SFX_VOLUMES := {
	"slash": -8.0, "hit": -5.0, "dash": -9.0,
	"parry_open": -9.0, "parry": -3.0, "slowmo": -6.0, "throw": -6.0,
	"explosion": -4.0,
	"extract_leap": -8.0, "extract_absorb": -8.0, "extract_blast": -3.0,
	"heal_charge": -9.0, "heal": -5.0, "hurt": -4.0, "death": -2.0,
	"windup": -12.0, "enemy_shoot": -10.0, "enemy_death": -8.0, "spawn": -14.0,
	"wave_start": -6.0, "wave_complete": -4.0, "tick": -8.0, "soul_ready": -8.0,
	"ui_move": -12.0, "ui_select": -7.0, "ui_back": -10.0,
	"laser": -8.0, "arrive": -4.0,
}

## Volume "de fábrica" de cada bus. As opções do jogador (0 a 1) somam em cima.
const MUSIC_BASE_DB := -10.0
const SFX_BASE_DB := 0.0
## Abaixo disso o bus é desligado (volume 0 nas opções = silêncio total).
const SILENCE_DB := -60.0

var _players := {}   # nome do efeito -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_filter: AudioEffectLowPassFilter
var _slow_tween: Tween
var _music_tween: Tween


func _ready() -> void:
	# ALWAYS: o som continua mesmo se o jogo for pausado no futuro.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	for sfx_name in SFX_VOLUMES:
		var player := AudioStreamPlayer.new()
		player.stream = load(SFX_DIR + sfx_name + ".wav")
		player.bus = &"SFX"
		player.volume_db = SFX_VOLUMES[sfx_name]
		# Até 6 cópias do mesmo som tocando juntas (ex.: vários monstros morrendo).
		player.max_polyphony = 6
		add_child(player)
		_players[sfx_name] = player

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)


## Toca um efeito. `pitch_variation` muda um pouco o tom a cada vez: o mesmo
## som repetido 20 vezes não fica "robótico".
func play(sfx_name: String, pitch_variation := 0.06) -> void:
	var player: AudioStreamPlayer = _players.get(sfx_name)
	if player == null:
		push_warning("Som não encontrado: " + sfx_name)
		return
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


## Para um efeito que está tocando (ex.: soltou o botão no meio da carga).
func stop(sfx_name: String) -> void:
	var player: AudioStreamPlayer = _players.get(sfx_name)
	if player:
		player.stop()


## Troca a trilha: a atual abaixa até sumir e a nova entra subindo.
## Se já for a mesma trilha, não faz nada (ela continua de onde estava).
func play_music(stream: AudioStreamWAV, fade := 0.8) -> void:
	if _music.stream == stream and _music.playing:
		return
	_make_loop(stream)
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_ignore_time_scale()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", SILENCE_DB, fade * 0.5)
	_music_tween.tween_callback(func():
		_music.stream = stream
		_music.volume_db = SILENCE_DB
		_music.play())
	_music_tween.tween_property(_music, "volume_db", 0.0, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Volumes das opções, de 0.0 (mudo) a 1.0 (máximo).
## linear_to_db converte "metade do volume" (0.5) para decibéis (-6 dB).
func set_music_volume(value: float) -> void:
	_set_bus_volume("Music", MUSIC_BASE_DB, value)


func set_sfx_volume(value: float) -> void:
	_set_bus_volume("SFX", SFX_BASE_DB, value)


## Câmera lenta: a música fica abafada (filtro passa-baixa) e mais grave.
func set_slow_motion(active: bool) -> void:
	if _slow_tween:
		_slow_tween.kill()
	# set_ignore_time_scale: o Tween conta em tempo REAL, senão ele também
	# ficaria em câmera lenta.
	_slow_tween = create_tween().set_parallel().set_ignore_time_scale()
	_slow_tween.tween_property(_music_filter, "cutoff_hz", 700.0 if active else 20000.0,
		0.25 if active else 0.4)
	_slow_tween.tween_property(_music, "pitch_scale", 0.85 if active else 1.0,
		0.25 if active else 0.4)


func _set_bus_volume(bus_name: String, base_db: float, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, base_db + linear_to_db(maxf(value, 0.001)))


func _create_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
	set_music_volume(1.0)
	set_sfx_volume(1.0)

	# Filtro da câmera lenta. Em 20000 Hz ele não muda nada (ouvido humano ~20 kHz).
	_music_filter = AudioEffectLowPassFilter.new()
	_music_filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _music_filter)


## Liga o loop por código: volta ao começo ao chegar no último sample.
## (As trilhas foram geradas para emendar sem corte.)
func _make_loop(stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
