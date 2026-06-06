# res://scripts/global.gd
extends Node

# Настройки игрока
var player_class: String = "Кудесник"
var difficulty: String = "Волхв (Норма)"
var enemy_damage_mod: float = 1.0
var enemy_speed_mod: float = 1.0

# Игровые настройки (Пауза/Меню)
var master_volume: float = 80.0
var is_fullscreen: bool = true

# Игровой прогресс
var player_level: int = 1
var player_xp: int = 0
var max_hp: float = 100.0
var max_mp: float = 100.0
var final_score: int = 0


func reset_game_data() -> void:
	player_level = 1
	player_xp = 0
	max_hp = 100.0
	max_mp = 100.0
	final_score = 0
	if difficulty == "Послушник (Легко)":
		enemy_damage_mod = 0.7
		enemy_speed_mod = 0.8
	elif difficulty == "Волхв (Норма)":
		enemy_damage_mod = 1.0
		enemy_speed_mod = 1.0
	else:
		enemy_damage_mod = 1.6
		enemy_speed_mod = 1.3

func change_scene(scene_path: String) -> void:
	# Используем call_deferred, чтобы смена сцены произошла после завершения физического шага
	get_tree().call_deferred("change_scene_to_file", scene_path)
