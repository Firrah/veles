extends Node

var sfx_players = []
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

func play_music(stream: AudioStream):
	if $MusicPlayer.stream == stream: return
	$MusicPlayer.stream = stream
	$MusicPlayer.play()

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
