extends Node2D

const FONT_PATH = "res://assets/fonts/main_font.otf"

func _ready() -> void:
	build_ui()
	animate_panel_entrance()

func build_ui() -> void:
# ЗАМЕНА ГРАДИЕНТА НА КАРТИНКУ
	var bg = TextureRect.new()
	bg.size = Vector2(1920, 1080)
	
	# Загружаем текстуру из файла
	bg.texture = load("res://assets/bg_menu.png")
	
	# Растягиваем текстуру на весь экран
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	add_child(bg)
	
	# 2. Панель
	var panel = Panel.new()
	panel.position = Vector2(610, 140)
	panel.size = Vector2(700, 800)
	panel.modulate = Color(1, 1, 1, 0) # Начальная прозрачность = 0
	add_child(panel)
	
	apply_retro_style(panel)
	
	var title = Label.new()
	title.text = "ВЫБЕРИ СВОЙ ПУТЬ"
	title.position = Vector2(0, 65)
	title.size = Vector2(700, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	_apply_style(title, 40, Color(1.0, 0.82, 0.25))
	
	# 3. Кнопки (сдвинули чуть влево для идеального баланса)
	# Мы используем RichTextLabel, поэтому передаем BB-код
	create_class_button(panel, "ВОИН", "Выносливый боец, мастер ближнего боя.", Vector2(150, 200), "Воин")
	create_class_button(panel, "ВОЛХВ", "Мудрец, управляющий стихиями и духами.", Vector2(150, 350), "Волхв")
	create_class_button(panel, "ТРАВНИК", "Ловкий следопыт, знаток ядов и отваров.", Vector2(150, 500), "Травник")

	# КНОПКА НАЗАД
	var btn_back = Button.new()
	btn_back.text = "ВЕРНУТЬСЯ"
	btn_back.position = Vector2(150, 650) # Ниже кнопок классов
	btn_back.size = Vector2(400, 60)
	
	# Стили для кнопки назад (можно сделать чуть скромнее)
	var style_back = StyleBoxFlat.new()
	style_back.bg_color = Color(0.1, 0.08, 0.07)
	
	# Заменяем border_width_all = 1 на явное указание сторон:
	style_back.border_width_left = 1
	style_back.border_width_top = 1
	style_back.border_width_right = 1
	style_back.border_width_bottom = 1
	
	style_back.border_color = Color(0.4, 0.3, 0.2)
	btn_back.add_theme_stylebox_override("normal", style_back)
	
	# Шрифт
	if ResourceLoader.exists(FONT_PATH):
		btn_back.add_theme_font_override("font", load(FONT_PATH))
	btn_back.add_theme_font_size_override("font_size", 18)
	
	# Логика возврата
	btn_back.pressed.connect(func():
		AudioManager.play_game_sfx("click")
		Global.change_scene("res://scenes/MainMenu.tscn") # Укажи путь к своей сцене меню
	)
	panel.add_child(btn_back)
	
func create_class_button(parent: Control, title: String, desc: String, pos: Vector2, _class_id: String) -> void:
	# Стили
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.16, 0.11, 0.10)
	style_normal.border_width_left = 2; style_normal.border_width_top = 2
	style_normal.border_width_right = 2; style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.55, 0.4, 0.25)
	
	var style_hover = style_normal.duplicate()
	style_hover.border_color = Color(1.0, 0.82, 0.25)
	
	var btn = Button.new()
	btn.position = pos
	btn.size = Vector2(400, 120)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	# ЗАГОЛОВОК
	var lbl_title = Label.new()
	lbl_title.text = title
	# Ставим его чуть выше центра
	lbl_title.position = Vector2(0, 20) 
	lbl_title.size = Vector2(400, 30)
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(FONT_PATH): lbl_title.add_theme_font_override("font", load(FONT_PATH))
	lbl_title.add_theme_font_size_override("font_size", 24)
	btn.add_child(lbl_title)
	
	# ОПИСАНИЕ
	var lbl_desc = Label.new()
	lbl_desc.text = desc
	# Включаем автоматический перенос текста
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Задаем отступы по бокам (по 20 пикселей), чтобы текст не прилипал к краям
	lbl_desc.position = Vector2(20, 55) 
	lbl_desc.size = Vector2(360, 60)
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl_desc.modulate = Color(0.8, 0.8, 0.8, 0.6)
	if ResourceLoader.exists(FONT_PATH): lbl_desc.add_theme_font_override("font", load(FONT_PATH))
	lbl_desc.add_theme_font_size_override("font_size", 16)
	btn.add_child(lbl_desc)
	
	btn.pressed.connect(func(): 
		AudioManager.play_game_sfx("click")
		Global.player_class = _class_id
		Global.change_scene("res://scenes/GameWorld.tscn")
	)
	parent.add_child(btn)

func apply_retro_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.72, 0.58, 0.32)
	panel.add_theme_stylebox_override("panel", style)

func _apply_style(node: Control, size: int, color: Color) -> void:
	if ResourceLoader.exists(FONT_PATH):
		node.add_theme_font_override("font", load(FONT_PATH))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)

func animate_panel_entrance() -> void:
	# Ищем нашу панель (предполагаем, что она первый ребенок после bg)
	# Если панель не находится, убедись что добавил её в дерево ДО вызова этой функции
	var panel = get_children()[1] # bg — это index 0, panel — index 1
	
	var tween = create_tween()
	# Плавно меняем прозрачность (альфа-канал) с 0 до 1 за 0.8 секунды
	tween.tween_property(panel, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC)
