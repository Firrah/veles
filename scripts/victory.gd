# res://scripts/victory.gd
extends Node2D

func _ready() -> void:
	var bg = TextureRect.new()
	bg.texture = load("res://assets/bg_victory.png")
	bg.custom_minimum_size = Vector2(1920, 1080)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	var panel = Panel.new()
	panel.size = Vector2(1000, 500)
	panel.position = Vector2(460, 290)
	add_child(panel)
	
	# Заголовок
	var label = Label.new()
	label.text = "СЛАВА СВЕТЛЫМ БОГАМ ПРАВИ!\nТРОПА ЧЕРНОЛЕСЬЯ ПРОЙДЕНА!"
	label.size = Vector2(1000, 120)
	label.position = Vector2(0, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)
	_apply_font(label, 48, Color(1.0, 0.84, 0.3)) # Золотой цвет
	
	# Статистика
	var info = Label.new()
	info.text = "ФИНАЛЬНЫЙ СЧЕТ: %d | Уровень знаний: %d" % [Global.final_score, Global.player_level]
	info.size = Vector2(1000, 60)
	info.position = Vector2(0, 240)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(info)
	_apply_font(info, 28, Color(0.9, 0.9, 0.9))
	
	# Кнопка меню
	var btn1 = Button.new()
	btn1.text = "ВЕРНУТЬСЯ В НАЧАЛО"
	btn1.size = Vector2(400, 60)
	btn1.position = Vector2(300, 340)
	btn1.pressed.connect(func(): 
		AudioManager.play_game_sfx("click") # Играем звук
		Global.change_scene("res://scenes/MainMenu.tscn")
		AudioManager.play_music(load("res://assets/sounds/Under-Pine-Shadows.ogg")))
		
	panel.add_child(btn1)
	_apply_font(btn1, 24, Color.WHITE)

func _apply_font(node: Control, size: int, color: Color) -> void:
	var font_res = load("res://assets/fonts/main_font.otf") 
	if font_res:
		node.add_theme_font_override("font", font_res)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)

func load_texture_safe(path: String, fallback_size: Vector2, fallback_color: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	
	var img := Image.create(int(fallback_size.x), int(fallback_size.y), false, Image.FORMAT_RGBA8)
	img.fill(fallback_color)
	return ImageTexture.create_from_image(img)
