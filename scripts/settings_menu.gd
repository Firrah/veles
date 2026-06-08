extends Node2D

const FONT_PATH = "res://assets/fonts/main_font.otf"

func _ready() -> void:
	build_settings_ui()

# Функция стиля, которую мы берем из твоего меню
func apply_retro_style(panel: Panel, label: Label = null, padding: float = 20.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.06, 0.92)
	style.border_width_left = 3; style.border_width_top = 3
	style.border_width_right = 3; style.border_width_bottom = 3
	style.border_color = Color(0.72, 0.58, 0.32)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding; style.content_margin_top = padding
	style.content_margin_right = padding; style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	
	if label:
		if ResourceLoader.exists(FONT_PATH):
			label.add_theme_font_override("font", load(FONT_PATH))
			label.add_theme_font_size_override("font_size", 21)

func build_settings_ui() -> void:
	# 1. ФОН
	var bg = TextureRect.new()
	bg.size = Vector2(1920, 1080)
	bg.texture = load("res://assets/bg_menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	# 2. ПАНЕЛЬ
	var panel = Panel.new()
	panel.position = Vector2(610, 140)
	panel.size = Vector2(700, 800)
	add_child(panel)
	apply_retro_style(panel)
	
	# Декор уголков (как в меню)
	for pos in [Vector2(10, 10), Vector2(665, 10), Vector2(10, 765), Vector2(665, 765)]:
		var corner = ColorRect.new()
		corner.position = pos; corner.size = Vector2(25, 25)
		corner.color = Color(0.72, 0.58, 0.32, 0.4)
		panel.add_child(corner)
	
	# ЗАГОЛОВОК
	var title = Label.new()
	title.text = "НАСТРОЙКИ"
	title.position = Vector2(0, 65); title.size = Vector2(700, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	if ResourceLoader.exists(FONT_PATH): title.add_theme_font_size_override("font_size", 46)
	panel.add_child(title)
	
	# 3. НАСТРОЙКИ ЗВУКА
	var font_res = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	
	var create_slider = func(lbl_text: String, bus_name: String, y: int):
		var lbl = Label.new()
		lbl.text = lbl_text; lbl.position = Vector2(150, y - 30)
		if font_res: lbl.add_theme_font_override("font", font_res)
		panel.add_child(lbl)
		
		var slider = HSlider.new()
		slider.position = Vector2(150, y); slider.size = Vector2(400, 30)
		slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.05
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name)))
		slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(v)))
		panel.add_child(slider)

	create_slider.call("ОБЩАЯ ГРОМКОСТЬ", "Master", 200)
	create_slider.call("ГРОМКОСТЬ МУЗЫКИ", "Music", 300)
	create_slider.call("ГРОМКОСТЬ ЭФФЕКТОВ", "SFX", 400)
	
	# 4. КНОПКИ
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.16, 0.11, 0.10); style_normal.border_width_bottom = 4
	style_normal.border_color = Color(0.55, 0.4, 0.25); style_normal.set_corner_radius_all(4)
	
	var setup_btn = func(text: String, pos: Vector2, cb: Callable):
		var btn = Button.new()
		btn.text = text; btn.position = pos; btn.size = Vector2(400, 65)
		btn.add_theme_stylebox_override("normal", style_normal)
		if font_res: btn.add_theme_font_override("font", font_res); btn.add_theme_font_size_override("font_size", 21)
		btn.pressed.connect(func():
			AudioManager.play_game_sfx("click") # Играем звук
			cb.call()                          # Выполняем то, что пришло в cb
			)
		panel.add_child(btn)
		
	setup_btn.call("ПЕРЕКЛЮЧИТЬ ЭКРАН", Vector2(150, 500), func():
		var mode = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode != DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	
	setup_btn.call("НАЗАД В МЕНЮ", Vector2(150, 600), func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	
