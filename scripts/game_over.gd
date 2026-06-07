# res://scripts/game_over.gd
extends Node2D

func _ready() -> void:
	var panel = Panel.new()
	panel.size = Vector2(1000, 500)
	panel.position = Vector2(460, 290)
	add_child(panel)
	
	# Заголовок
	var label = Label.new()
	label.text = "ДУША ПОГРУЗИЛАСЬ В НАВЬ ВЕЧНУЮ...\nВЫ ПОГИБЛИ"
	label.size = Vector2(1000, 120)
	label.position = Vector2(0, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)
	_apply_font(label, 48, Color(0.8, 0, 0))
	
	# Статистика
	var info = Label.new()
	info.text = "Класс: %s | Сложность: %s" % [Global.player_class, Global.difficulty]
	info.size = Vector2(1000, 60)
	info.position = Vector2(0, 240)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(info)
	_apply_font(info, 28, Color(0.8, 0.8, 0.8))
	
	# Кнопки
	var btn1 = Button.new()
	btn1.text = "ВОЗРОДИТЬСЯ"
	btn1.size = Vector2(400, 60)
	btn1.position = Vector2(300, 300)
	btn1.pressed.connect(func(): 
		Global.reset_game_data()
		Global.change_scene("res://scenes/GameWorld.tscn")
	)
	panel.add_child(btn1)
	_apply_font(btn1, 24, Color.WHITE)
	
	var btn2 = Button.new()
	btn2.text = "ГЛАВНОЕ МЕНЮ"
	btn2.size = Vector2(400, 60)
	btn2.position = Vector2(300, 380)
	btn2.pressed.connect(func(): Global.change_scene("res://scenes/MainMenu.tscn"))
	panel.add_child(btn2)
	_apply_font(btn2, 24, Color.WHITE)

func _apply_font(node: Control, size: int, color: Color) -> void:
	var font_res = load("res://assets/fonts/main_font.otf") 
	if font_res:
		node.add_theme_font_override("font", font_res)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
