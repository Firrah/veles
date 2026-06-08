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
var xp_to_next_level: int = 100
var max_hp: float = 100.0
var max_mp: float = 100.0
var max_stamina: float = 100.0
var final_score: int = 0
var current_hp: float = 100.0
var current_mp: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_speed: float = 30.0

func reset_game_data() -> void:
	player_level = 1
	player_xp = 0
	max_hp = 100.0
	max_mp = 100.0
	max_stamina = 100.0
	final_score = 0
	
	current_hp = max_hp
	current_mp = max_mp
	current_stamina = max_stamina
	
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
	# Создаем временный слой, который НЕ удалится при смене сцены
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)
	
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade)
	
	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
		canvas.queue_free() # Удаляем затемнение после загрузки новой сцены
	)
	
func add_xp(amount: int) -> void:
	player_xp += amount
	if player_xp >= xp_to_next_level:
		level_up()

func level_up() -> void:
	player_level += 1
	player_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5) # Каждый уровень сложнее предыдущего
	# Тут можно добавить прирост статов (например, Global.max_hp += 10)
