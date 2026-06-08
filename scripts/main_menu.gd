extends Node

var main_menu_canvas: CanvasLayer
const FONT_PATH = "res://assets/fonts/main_font.otf"
var btn_start: Button

func _ready() -> void:
	var music_stream = load("res://assets/sounds/Under-Pine-Shadows.ogg") 
	
	AudioManager.play_music(music_stream)
	build_main_menu_ui()
	get_tree().paused = false

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
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)

func build_main_menu_ui() -> void:
	main_menu_canvas = CanvasLayer.new()
	main_menu_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(main_menu_canvas)
	
	# ФОН
	var bg = TextureRect.new()
	bg.size = Vector2(1920, 1080)
	bg.texture = load("res://assets/bg_menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	main_menu_canvas.add_child(bg)
	
	# ПАНЕЛЬ
	var panel = Panel.new()
	panel.position = Vector2(610, 140)
	panel.size = Vector2(700, 800)
	main_menu_canvas.add_child(panel)
	
	# ДЕКОР
	var corners_pos = [Vector2(10, 10), Vector2(665, 10), Vector2(10, 765), Vector2(665, 765)]
	for pos in corners_pos:
		var corner = ColorRect.new()
		corner.position = pos
		corner.size = Vector2(25, 25)
		corner.color = Color(0.72, 0.58, 0.32, 0.4)
		panel.add_child(corner)
	
	# ЗАГОЛОВОК
	var title = Label.new()
	title.text = "СКАЗ О ДРЕВНЕМ ПУТИ"
	title.position = Vector2(0, 65)
	title.size = Vector2(700, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	panel.add_child(title)
	apply_retro_style(panel, title, 35.0)
	if ResourceLoader.exists(FONT_PATH): title.add_theme_font_size_override("font_size", 46)
	
	# ПОДЗАГОЛОВОК
	var subtitle = Label.new()
	subtitle.text = "ГЛАВА I: ПЕКЕЛЬНЫЕ ЗЕМЛИ"
	subtitle.position = Vector2(0, 140)
	subtitle.size = Vector2(700, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.3, 0.2))
	if ResourceLoader.exists(FONT_PATH):
		subtitle.add_theme_font_override("font", load(FONT_PATH))
		subtitle.add_theme_font_size_override("font_size", 16)
	panel.add_child(subtitle)
	
	# ЛОР
	var lore_text = RichTextLabel.new()
	lore_text.bbcode_enabled = true
	lore_text.text = "[center]«...И разошлись туманы над капищем древним, и пробудилась лихая сила в топях болотных. Настало время обнажить верный клинок заговоренный, да пойти тропою неизведанной супротив Тьмы...»[/center]"
	lore_text.position = Vector2(50, 205)
	lore_text.size = Vector2(600, 130)
	lore_text.scroll_active = false
	lore_text.add_theme_color_override("default_color", Color(0.55, 0.52, 0.48))
	if ResourceLoader.exists(FONT_PATH):
		lore_text.add_theme_font_override("normal_font", load(FONT_PATH))
		lore_text.add_theme_font_size_override("normal_font_size", 16)
	panel.add_child(lore_text)

	# СТИЛИ КНОПОК
	var font_res = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.16, 0.11, 0.10); style_normal.border_width_bottom = 4
	style_normal.border_color = Color(0.55, 0.4, 0.25); style_normal.set_corner_radius_all(4)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.24, 0.16, 0.14); style_hover.border_color = Color(1.0, 0.82, 0.25)
	
	var setup_menu_btn = func(btn: Button, text: String, pos: Vector2):
		btn.text = text; btn.position = pos; btn.size = Vector2(400, 65)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if font_res: btn.add_theme_font_override("font", font_res); btn.add_theme_font_size_override("font_size", 21)
		panel.add_child(btn)
	
	# КНОПКИ
	btn_start = Button.new()
	setup_menu_btn.call(btn_start, "НАЧАТЬ СКАЗАНИЕ", Vector2(150, 385))
	btn_start.pressed.connect(func(): 
		AudioManager.play_game_sfx("click")
		Global.change_scene("res://scenes/CharacterSelection.tscn"))
	
	# КНОПКА НАСТРОЕК (вставлена в твой поток)
	var btn_settings = Button.new()
	setup_menu_btn.call(btn_settings, "НАСТРОЙКИ", Vector2(150, 465))
	btn_settings.pressed.connect(func(): 
		AudioManager.play_game_sfx("click")
		Global.change_scene("res://scenes/SettingsMenu.tscn"))
	
	var btn_exit = Button.new()
	setup_menu_btn.call(btn_exit, "ВЫЙТИ В ПОСАД", Vector2(150, 545))
	btn_exit.pressed.connect(func(): 
		AudioManager.play_game_sfx("click")
		get_tree().quit())
	
