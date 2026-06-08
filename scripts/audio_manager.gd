extends Node

var sfx_players = []
const SOUNDS = {
	"pickup": "res://assets/sounds/pickup.wav",
	"text": "res://assets/sounds/text.wav",
	"portal": "res://assets/sounds/portal.wav",
	"click": "res://assets/sounds/click.wav",
	"win": "res://assets/sounds/win.wav",
	"lose": "res://assets/sounds/lose.wav",
	"boss_dead": "res://assets/sounds/boss_dead.wav",
	"spell": "res://assets/sounds/spell.wav",
	"damage": "res://assets/sounds/damage.wav"
}
const MAX_SFX_PLAYERS = 16 # С запасом для активных битв
const SETTINGS_FILE = "user://settings.cfg"

func _ready():
	load_settings()
	# Создаем пул SFX плееров
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
	# Добавляем плеер для музыки
	var music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

func play_sfx(stream: AudioStream):
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
			
func play_game_sfx(key: String):
	if SOUNDS.has(key):
		play_sfx(load(SOUNDS[key]))

func play_music(stream: AudioStream):
	var music_player = $MusicPlayer
	
	# Если это тот же самый трек, просто продолжаем играть
	if music_player.stream == stream and music_player.playing:
		return
		
	# Если это новый трек или плеер стоит:
	music_player.stop()       # Останавливаем старый
	music_player.stream = stream # Меняем на новый
	music_player.play()       # Запускаем

func set_bus_volume(bus_name: String, value: float):
	var idx = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))
	save_settings()
	
func save_settings():
	var config = ConfigFile.new()
	# Сохраняем громкость каждой шины
	config.set_value("audio", "master", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	config.set_value("audio", "music", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	config.set_value("audio", "sfx", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	config.save(SETTINGS_FILE)

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		# Загружаем и применяем громкость
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), config.get_value("audio", "master", 0.0))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), config.get_value("audio", "music", 0.0))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), config.get_value("audio", "sfx", 0.0))

func fade_music_to(stream: AudioStream, duration: float = 1.0):
	var music_player = $MusicPlayer
	var tween = create_tween()
	
	# Плавное затухание текущей
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	tween.tween_callback(func():
		music_player.stream = stream
		music_player.play()
		# Плавное появление новой
		create_tween().tween_property(music_player, "volume_db", 0.0, duration)
	)
	
func stop_music_faded(duration: float = 1.0):
	var music_player = $MusicPlayer
	if not music_player.playing: return
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	tween.tween_callback(func():
		music_player.stop()
		music_player.volume_db = 0.0 # Сбрасываем громкость для следующего раза
	)
