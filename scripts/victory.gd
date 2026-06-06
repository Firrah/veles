# res://scripts/victory.gd
extends Node2D

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0.02, 0.15, 0.04, 0.95) # Изумрудный фон
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
	btn1.pressed.connect(func(): Global.change_scene("res://scenes/MainMenu.tscn"))
	panel.add_child(btn1)
	_apply_font(btn1, 24, Color.WHITE)

func _apply_font(node: Control, size: int, color: Color) -> void:
	var font_res = load("res://assets/fonts/main_font.otf") 
	if font_res:
		node.add_theme_font_override("font", font_res)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
