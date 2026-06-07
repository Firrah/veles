extends CanvasLayer

@onready var fade = $ColorRect

func fade_to_scene(target: String) -> void:
	# 1. Затемняем экран
	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	await tween.finished
	
	# 2. Логика перехода
	if target.begins_with("res://"):
		# Если это путь к файлу .tscn — меняем сцену
		get_tree().change_scene_to_file(target)
	else:
		# Если это просто имя локации (как "Древнее Капище")
		# Мы сообщаем текущей сцене, что пора обновиться
		var root = get_tree().current_scene
		if root.has_method("update_location_data"):
			root.update_location_data(target)
		else:
			print("ОШИБКА: У текущей сцены нет метода update_location_data")
	
	# 3. Светлеем после перехода/обновления
	await get_tree().create_timer(0.2).timeout
	var tween_in = create_tween()
	tween_in.tween_property(fade, "color:a", 0.0, 0.5)
