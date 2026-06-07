# res://scripts/game_world.gd
extends Node2D

enum CombatMode { COMBAT, PEACE }
var quest_objectives = {
	"move": false,
	"roll": false,
	"nav": false,
	"find_crystal": false,
	"defeat_kikimora": false
}
var status_panel: Panel
var stamina_regen_speed := 15.0 # Скорость восстановления в секунду
var current_combat_mode = CombatMode.COMBAT
var chosen_path_name: String = "Выбор не сделан"
var hp_bar: ProgressBar # Добавь это, если нет
var stamina_bar: ProgressBar
var map_width: float = 3200.0
var map_height: float = 1500.0
var mp_spell_cost: float = 20.0
var mp_regen_speed_yav: float = 20.0
var inventory = {"crystal": 0}
var current_location_name: String = "Окраина Чернолесья"
var is_nav_world: bool = false
var is_dialogue_active: bool = false
var current_dialogue_id: String = ""
var tutorial_steps_done = {"move": false, "roll": false, "nav": false}

var player: CharacterBody2D
var background: TextureRect
var canvas_modulate: CanvasModulate
var camera: Camera2D

var world_label: Label
var hp_beads_container: HBoxContainer
var mp_bar: ProgressBar
var xp_label: Label
var dialogue_panel: Panel
var dialogue_text: Label
var dialogue_choices: Label
var quest_text: RichTextLabel
var inv_slots_text: Label
var minimap_content: Control

var boss_ui_layer: CanvasLayer
var boss_hp_bar: ProgressBar
var boss_name_label: Label
var pause_canvas: CanvasLayer

var player_speed: float = 270.0
var roll_speed: float = 600.0
var roll_duration: float = 0.2
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO

var enemy_list = []
var active_projectiles = []
var level_objects = []

func _ready() -> void:
	apply_class_stats()
	setup_input_map()
	
	background = TextureRect.new()
	background.size = Vector2(map_width, map_height)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background)
	
	canvas_modulate = CanvasModulate.new()
	add_child(canvas_modulate)
	
	build_player()
	build_advanced_hud()
	build_boss_hp_bar_ui()
	build_minimap_ui()
	build_quest_and_inventory_ui() # Важно: UI создается до старта квеста
	build_pause_menu_ui()
	
	start_tutorial_quest()
	load_location("Окраина Чернолесья")
	update_hp_display()

func start_tutorial_quest() -> void:
	if quest_text:
		quest_text.text = "[color=#e0a651]ПЕРВЫЕ ШАГИ СКАЗАНИЯ[/color]\n\n" + \
		"[color=#a89f91]Обучение:[/color]\n" + \
		"• Оглядись кругом ([color=#ffdb70]WASD[/color] или стрелочки)\n" + \
		"• Поведай думы ([color=#ffdb70]Пробел[/color] для действия)\n" + \
		"• Отыщи три вещих камня на опушке"

func setup_input_map() -> void:
	var inputs = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"switch_world": [KEY_R], "roll": [KEY_SHIFT],
		"attack": [KEY_SPACE], "cast_spell": [MOUSE_BUTTON_LEFT, KEY_Q],
		"pause_game": [KEY_ESCAPE],
		"choice1": [KEY_1], "choice2": [KEY_2], "choice3": [KEY_3]
	}
	for action in inputs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in inputs[action]:
				var event
				if (action == "cast_spell" and key == MOUSE_BUTTON_LEFT):
					event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
				else:
					event = InputEventKey.new(); event.physical_keycode = key
				InputMap.action_add_event(action, event)

func load_texture_safe(path: String, fallback_size: Vector2, fallback_color: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	
	var img := Image.create(int(fallback_size.x), int(fallback_size.y), false, Image.FORMAT_RGBA8)
	img.fill(fallback_color)
	return ImageTexture.create_from_image(img)
	
var player_anim: AnimatedSprite2D # Заменили player_sprite

func build_player() -> void:
	# 1. Создаем игрока
	player = CharacterBody2D.new()
	player.position = Vector2(300, 300)
	
	# 2. Создаем и настраиваем AnimatedSprite2D
	player_anim = AnimatedSprite2D.new()
	
	# Пытаемся загрузить файл, но если его нет — выводим ошибку, а не просто молчим
	var frames_path = "res://assets/wizard_frames.tres"
	if ResourceLoader.exists(frames_path):
		player_anim.sprite_frames = load(frames_path)
		print("Успешно загружен файл анимаций: ", frames_path)
	else:
		push_error("ФАЙЛ АНИМАЦИЙ НЕ НАЙДЕН: " + frames_path)
		# Если файла нет, используем дефолтный, чтобы игра хотя бы запустилась
		player_anim.sprite_frames = SpriteFrames.new()
	
	# Устанавливаем настройки спрайта
	player_anim.animation = "idle"
	player_anim.scale = Vector2(1.5, 1.5)
	player_anim.z_index = 10 # Убедимся, что спрайт выше фона
	
	# 3. Добавляем спрайт в дерево ПЕРЕД запуском анимации
	player.add_child(player_anim)
	
	# 4. Запускаем анимацию только после добавления в дерево
	if player_anim.sprite_frames.has_animation("idle"):
		player_anim.play("idle")
	
	# 5. Коллизия и Камера
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(40, 80)
	player.add_child(shape)
	
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_width)
	camera.limit_bottom = int(map_height)
	player.add_child(camera)
	
	# 6. Добавляем игрока на сцену
	add_child(player)

func load_location(location_name: String) -> void:
	current_location_name = location_name
	current_combat_mode = CombatMode.COMBAT; chosen_path_name = "Выбор не сделан"
	is_dialogue_active = false; current_dialogue_id = ""; dialogue_panel.visible = false
	boss_ui_layer.visible = false
	
	for obj in level_objects: if is_instance_valid(obj): obj.queue_free()
	level_objects.clear(); enemy_list.clear(); active_projectiles.clear()
	player.position = Vector2(250, 500)
	
	if location_name == "Окраина Чернолесья":
		tutorial_steps_done = {"move": false, "roll": false, "nav": false}
		background.texture = load_texture_safe("res://assets/bg_tutorial.png", Vector2(1920, 1080), Color(0.12, 0.14, 0.12))
		spawn_tutorial_trigger(Vector2(700, 500), "move", "Камень Движения: Векторы WASD направляют твой шаг.")
		spawn_tutorial_trigger(Vector2(1400, 700), "roll", "Камень Уклонения: Нажатие SHIFT дарует перекат.")
		spawn_tutorial_trigger(Vector2(2100, 400), "nav", "Камень Нави: Клавиша R открывает Изнанку Мира.")
		spawn_portal(Vector2(2900, 500), "Древнее Капище")
		
	elif location_name == "Древнее Капище":
		background.texture = load_texture_safe("res://assets/bg_shrine.png", Vector2(1920, 1080), Color(0.15, 0.1, 0.15))
		spawn_enemy(Vector2(1600, 700), "res://assets/kikimora.png", Color(0.2, 0.6, 0.2), "boss")
		spawn_item(Vector2(1750, 750), "crystal")
		spawn_portal(Vector2(3000, 700), "ПОБЕДА")
		
		trigger_dialogue("kikimora_start", "Кикимора Болотная: Кто посмел осквернить Древнее Капище?\nУбирайся, или твои кости сгниют в этой топи!", "[1] Договориться мирно (Дипломатия) | [2] Напасть (Бой)")
		
	update_world_label_ui(); update_quest_journal(); switch_world(false)

func _process(delta: float) -> void:
	update_all_ui()
	
	if get_tree().paused or is_dialogue_active: return
	if Global.current_hp <= 0:
		set_process(false)
		TransitionManager.fade_to_scene("res://scenes/GameOver.tscn")
		return
		
	var input_dir = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")).normalized()
	
	# Анимации и движение
	if is_rolling:
		# ПЕРЕПИСАННЫЙ БЛОК:
		# Мы играем анимацию только если она еще не играет, 
		# чтобы не перезапускать её каждый кадр
		if player_anim.animation != "roll":
			player_anim.play("roll")
			
		player.velocity = roll_direction * roll_speed
		roll_timer -= delta
		
		if roll_timer <= 0: 
			is_rolling = false
			player_anim.modulate = Color(1, 1, 1)
	else:
		if input_dir != Vector2.ZERO:
			player.velocity = input_dir * player_speed
			player_anim.flip_h = (input_dir.x < 0)
			if player_anim.sprite_frames.has_animation("walk"): player_anim.play("walk")
			else: player_anim.play("idle")
		else:
			player.velocity = Vector2.ZERO
			player_anim.play("idle")
	
	player.move_and_slide()
	player.position = player.position.clamp(Vector2.ZERO, Vector2(map_width, map_height))
	# Ограничение области передвижения
	player.position.x = clamp(player.position.x, 0, map_width)
	player.position.y = clamp(player.position.y, 0, map_height)
	
	# 3. Регенерация и UI
	Global.current_mp = min(Global.current_mp + mp_regen_speed_yav * delta, Global.max_mp)
	Global.current_stamina = min(Global.current_stamina + stamina_regen_speed * delta, Global.max_stamina)
	mp_bar.value = Global.current_mp
	stamina_bar.value = Global.current_stamina
	update_minimap()
	
# 4. Атака магией и движение снарядов
	var dead_projectiles = []
	
	for proj in active_projectiles:
		if is_instance_valid(proj):
			# ДВИЖЕНИЕ
			proj.position += proj.get_meta("dir") * proj.get_meta("speed") * delta
			
			# ПРИНУДИТЕЛЬНАЯ ПРОВЕРКА УРОНА (чтобы не пролетали сквозь врагов)
			for enemy in enemy_list:
				if is_instance_valid(enemy) and enemy.get_meta("status") == "aggressive":
					# Если расстояние меньше 30 пикселей - считаем попаданием
					if proj.position.distance_to(enemy.position) < 30.0:
						_on_projectile_hit(enemy)
						dead_projectiles.append(proj)
						break # Выходим из цикла врагов, так как снаряд уже попал
			
			# Удаление, если снаряд улетел слишком далеко (время жизни)
			var life = proj.get_meta("lifetime") - delta
			if life <= 0:
				dead_projectiles.append(proj)
			else:
				proj.set_meta("lifetime", life)
				
	# Очистка удаленных снарядов
	for dp in dead_projectiles:
		if is_instance_valid(dp):
			active_projectiles.erase(dp)
			dp.queue_free()

	# ВЫСТРЕЛ
	if Input.is_action_just_pressed("cast_spell") and not is_rolling:
		if Global.current_mp >= mp_spell_cost:
			Global.current_mp -= mp_spell_cost
			var mouse_pos = get_global_mouse_position()
			var shoot_dir = (mouse_pos - player.position).normalized()
			if shoot_dir.x != 0: player_anim.flip_h = (shoot_dir.x < 0)
			spawn_projectile(player.position, shoot_dir)
	
	# 5. Обработка врагов
	for enemy in enemy_list:
		if not is_instance_valid(enemy) or enemy.get_meta("status") == "friendly": continue
		
		var espr = enemy.get_node_or_null("AnimatedSprite2D") # Убедись, что имя совпадает!
		var distance = enemy.position.distance_to(player.position)
		var move_dir = (player.position - enemy.position).normalized()
		var att_t = enemy.get_meta("attack_timer")
		
		# ЛОГИКА АНИМАЦИИ
		if espr:
			# Анимация атаки (если таймер атаки почти закончился или активен)
			if distance < 150.0 and att_t > 0.5:
				if espr.sprite_frames.has_animation("attack"): espr.play("attack")
			# Анимация ходьбы
			elif enemy.velocity != Vector2.ZERO:
				if espr.sprite_frames.has_animation("walk"): espr.play("walk")
			# Анимация бездействия
			else:
				if espr.sprite_frames.has_animation("idle"): espr.play("idle")
		
		# Остальная логика движения (твоя)
		if enemy.get_meta("id_tag") == "boss" and distance > 150.0 and distance < 600.0:
			enemy.velocity = Vector2.ZERO 
			if att_t <= 0: 
				spawn_boss_projectile(enemy.position, player.position)
				enemy.set_meta("attack_timer", 2.0)
		else:
			enemy.velocity = move_dir * 110.0 * Global.enemy_speed_mod
			enemy.move_and_slide()
		
		# Поворот спрайта
		if espr and move_dir.x != 0: espr.flip_h = (move_dir.x < 0)
			
		# Получение урона
		if distance < 110.0 and not is_rolling and att_t <= 0:
			Global.current_hp -= 25.0 * Global.enemy_damage_mod
			enemy.set_meta("attack_timer", 1.4)
			update_hp_display()
			if is_instance_valid(player_anim):
				player_anim.modulate = Color(1.0, 0.3, 0.3)
				var tween = create_tween()
				tween.tween_property(player_anim, "modulate", Color(1, 1, 1), 0.2)

func handle_dialogue_choice(index: int) -> void:
	is_dialogue_active = false; dialogue_panel.visible = false
	if current_dialogue_id.begins_with("tutorial_"): return
		
	if current_dialogue_id == "kikimora_start":
		if index == 1:
			change_path("Путь Стали и Магии")
			current_combat_mode = CombatMode.PEACE
			update_quest_journal()
			trigger_dialogue("kikimora_peace", "Кикимора: Твоё почтение спасло тебе жизнь. Забирай Кристалл Яви.", "[1] Взять кристалл")
			for e in enemy_list: if is_instance_valid(e): e.set_meta("status", "friendly")
			update_world_label_ui() # <--- ДОБАВЬ ЭТО СЮДА
		elif index == 2:
			change_path("Путь Стали и Магии")
			current_combat_mode = CombatMode.COMBAT
			trigger_dialogue("kikimora_war", "Кикимора: Я разорву тебя на куски! Защищайся!", "[1] К бою!")
			update_world_label_ui() # <--- И СЮДА
			for e in enemy_list:
				if is_instance_valid(e):
					e.set_meta("status", "aggressive")
					if e.get_meta("id_tag") == "boss":
						boss_ui_layer.visible = true
	update_quest_journal()

func spawn_tutorial_trigger(pos: Vector2, step_id: String, msg: String) -> void:
	var area := Area2D.new()
	area.position = pos
	
	var spr := Sprite2D.new()
	spr.texture = load_texture_safe("res://assets/stone.png", Vector2(50, 60), Color(0.4, 0.4, 0.4))
	area.add_child(spr)
	
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 70.0
	area.add_child(shape)
	
	area.body_entered.connect(func(body):
		if body == player:
			var formatted_msg = "ВЕЩИЙ КАМЕНЬ СТРУИТ НАКАЗ:\n\n" + msg + ""
			trigger_dialogue("tutorial_" + step_id, formatted_msg, "[1] Осознать")
			
			tutorial_steps_done[step_id] = true
			quest_objectives[step_id] = true # Ставим галочку в новой системе
			update_quest_journal()
	)
	add_child(area)
	level_objects.append(area)

func spawn_enemy(pos: Vector2, path: String, fallback_color: Color, id_tag: String) -> void:
	var enemy := CharacterBody2D.new(); enemy.position = pos; enemy.set_meta("id_tag", id_tag)
	enemy.set_meta("hp", 300.0); enemy.set_meta("status", "aggressive"); enemy.set_meta("attack_timer", 0.0)
	
	var spr := Sprite2D.new(); spr.name = "Sprite2D"
	spr.texture = load_texture_safe(path, Vector2(80, 120), fallback_color)
	spr.scale = Vector2(2.5, 2.5)
	enemy.add_child(spr)
	
	var shape := CollisionShape2D.new(); shape.shape = RectangleShape2D.new(); shape.shape.size = Vector2(140, 220)
	enemy.add_child(shape)
	add_child(enemy); enemy_list.append(enemy); level_objects.append(enemy)

	boss_hp_bar.max_value = 300.0
	boss_hp_bar.value = 300.0

func spawn_item(pos: Vector2, type: String) -> void:
	var item := Area2D.new(); item.position = pos; item.set_meta("type", type)
	var spr := Sprite2D.new()
	spr.texture = load_texture_safe("res://assets/crystal.png", Vector2(32, 32), Color.CYAN)
	item.add_child(spr)
	var shape := CollisionShape2D.new(); shape.shape = CircleShape2D.new(); shape.shape.radius = 50.0; item.add_child(shape)
	
	item.body_entered.connect(func(body):
		if body == player:
			# --- ПРОВЕРКА СОСТОЯНИЯ БОЯ ---
			if current_combat_mode == CombatMode.COMBAT:
				# Если бой идет, кристалл не берется
				world_label.text = "ВРАГ НЕ ПОБЕЖДЁН!"
				return
			
			# Если мы в режиме PEACE, забираем предмет
			inventory["crystal"] += 1; add_xp(60)
			quest_objectives["find_crystal"] = true # Ставим галочку
			level_objects.erase(item); item.queue_free()
			update_inventory_ui(); update_quest_journal()
			world_label.text = "Ты овладел Кристаллом Яви."
	)
	add_child(item); level_objects.append(item)

func spawn_portal(pos: Vector2, target: String) -> void:
	var portal := Area2D.new()
	portal.position = pos
	
	var spr := Sprite2D.new()
	spr.texture = load_texture_safe("res://assets/portal.png", Vector2(60, 140), Color.PURPLE)
	spr.scale = Vector2(1.3, 1.3)
	portal.add_child(spr)
	
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(90, 180)
	portal.add_child(shape)
	
	# Подключаем функцию обработки входа
	portal.body_entered.connect(_on_portal_body_entered.bind(portal, target))
	
	add_child(portal)
	level_objects.append(portal)

func _on_portal_body_entered(body: Node2D, portal: Area2D, target: String) -> void:
	if body != player: return
	
	# Блокируем портал, чтобы избежать двойного вызова
	portal.set_deferred("monitoring", false)
	
	# --- Логика Обучения ---
	if current_location_name == "Окраина Чернолесья":
		if tutorial_steps_done.move and tutorial_steps_done.roll and tutorial_steps_done.nav:
			# Вызываем глобальный переход через TransitionManager
			TransitionManager.fade_to_scene(target)
		else:
			# Если рано, возвращаем мониторинг, чтобы игрок мог попробовать снова
			portal.set_deferred("monitoring", true)
			world_label.text = "АКТИВИРУЙТЕ ВСЕ ТРИ КАМНЯ!"
		return

	# --- Логика Победы ---
	if target == "ПОБЕДА":
		if inventory["crystal"] >= 1:
			Global.final_score = (inventory["crystal"] * 300) + (Global.player_level * 500)
			TransitionManager.fade_to_scene("res://scenes/Victory.tscn")
		else:
			portal.set_deferred("monitoring", true)
			world_label.text = "ПОРТАЛ ЗАКРЫТ БЕЗ КРИСТАЛЛА!"

func change_path(new_name: String) -> void:
	chosen_path_name = new_name
	if is_instance_valid(world_label):
		update_world_label_ui()

func switch_world(to_nav: bool) -> void:
	is_nav_world = to_nav
	canvas_modulate.color = Color(0.4, 0.35, 0.7) if is_nav_world else Color(1.0, 1.0, 1.0)

func update_world_label_ui() -> void: world_label.text = "МЕСТО: %s\nПУТЬ: %s" % [current_location_name.to_upper(), chosen_path_name.to_upper()]

func update_quest_journal() -> void:
	if not is_instance_valid(quest_text): return
	
	quest_text.bbcode_enabled = true
	var text_output = ""
	
	if current_location_name == "Окраина Чернолесья":
		text_output = "[color=#e0a651]--- ПЕРВЫЕ ШАГИ ---[/color]\n\n"
		text_output += "%s Оглядеться (WASD)\n" % ("✔" if quest_objectives["move"] else "•")
		text_output += "%s Уклониться (SHIFT)\n" % ("✔" if quest_objectives["roll"] else "•")
		text_output += "%s Изнанка (R)\n" % ("✔" if quest_objectives["nav"] else "•")
		
	elif current_location_name == "Древнее Капище":
		text_output = "[color=#e0a651]--- ГЛАВА I: КАПИЩЕ ---[/color]\n\n"
		
		# Если выбран мирный путь, ставим галочку автоматически
		var is_boss_done = quest_objectives["defeat_kikimora"] or (current_combat_mode == CombatMode.PEACE)
		var boss_icon = "✔" if is_boss_done else "•"
		
		text_output += "%s [color=#888888]Победа над Кикиморой[/color]\n" % boss_icon
		text_output += "%s Найти Кристалл Яви" % ("✔" if quest_objectives["find_crystal"] else "•")
	
	quest_text.text = text_output

func update_inventory_ui() -> void: if is_instance_valid(inv_slots_text): inv_slots_text.text = "[ Кристалл ]: %d шт." % inventory["crystal"]
func add_xp(amount: int) -> void: Global.player_xp += amount; if Global.player_xp >= 100: Global.player_xp -= 100; Global.player_level += 1; xp_label.text = "Уровень: %d (%d / 100 XP)" % [Global.player_level, Global.player_xp]

func create_stat_bar(parent: Node, pos: Vector2, color: Color, max_val: float) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(300, 25)
	bar.max_value = max_val
	bar.show_percentage = true # Покажет цифры (например, 80/100)
	
	# Создаем стиль для полоски
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8) # Темный фон
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = color # Цвет полоски (HP или MP)
	
	bar.add_theme_stylebox_override("background", style_bg)
	bar.add_theme_stylebox_override("fill", style_fill)
	
	parent.add_child(bar)
	return bar

func apply_retro_style(panel: Panel, label: Label = null, padding: float = 20.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.07, 0.85)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.72, 0.58, 0.32)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	
	var font_path = "res://assets/fonts/main_font.otf"
	if label:
		if ResourceLoader.exists(font_path):
			var custom_font = load(font_path)
			label.add_theme_font_override("font", custom_font)
			label.add_theme_font_size_override("font_size", 21)
		
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)

func create_bar_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.1, 0.1, 0.5)
	return style

func _apply_label_font(label: Label, size: int = 21) -> void:
	var font_path = "res://assets/fonts/main_font.otf"
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
		label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func build_advanced_hud() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HUDLayer"
	add_child(canvas_layer)
	
	# Увеличил высоту до 260, чтобы всё гарантированно поместилось
	var status_panel := Panel.new()
	status_panel.position = Vector2(40, 40)
	status_panel.size = Vector2(490, 200) 
	canvas_layer.add_child(status_panel)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	status_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	# Правильное написание свойства для Godot:
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Заголовок
	world_label = Label.new()
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(world_label)
	apply_retro_style(status_panel, world_label, 20.0)
	
	# Контейнер для статов
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(stats_vbox)
	
	var bar_data = [
		["Жизнь:", Color(0.7, 0.1, 0.1), "hp"],
		["Дух:", Color(0.22, 0.44, 0.78), "mp"],
		["Сила:", Color(0.9, 0.7, 0.1), "stamina"]
	]
	
	for data in bar_data:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 15)
		stats_vbox.add_child(hbox)
		
		var title = Label.new()
		title.text = data[0]
		title.custom_minimum_size = Vector2(80, 20)
		hbox.add_child(title)
		_apply_label_font(title, 18)
		
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(340, 16)
		bar.add_theme_stylebox_override("fill", create_bar_style(data[1]))
		
		# --- ИСПРАВЛЕНИЕ: ДЕЛАЕМ ФОН ПРОЗРАЧНЫМ ---
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0, 0, 0, 0) # Четвертый параметр (0) делает цвет прозрачным
		bar.add_theme_stylebox_override("background", bg_style)
		# -------------------------------------------
		
		hbox.add_child(bar)
		
		match data[2]:
			"hp": hp_bar = bar
			"mp": mp_bar = bar
			"stamina": stamina_bar = bar
	
	# Уровень
	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Добавляем небольшой отступ сверху, чтобы отделить от полосок
	xp_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(xp_label)
	_apply_label_font(xp_label, 18)
	
	# Диалоговая панель
	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(360, 770)
	dialogue_panel.size = Vector2(1200, 250)
	dialogue_panel.visible = false
	canvas_layer.add_child(dialogue_panel)
	
	dialogue_text = Label.new()
	dialogue_text.position = Vector2(40, 35)
	dialogue_text.size = Vector2(1120, 110)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_panel.add_child(dialogue_text)
	apply_retro_style(dialogue_panel, dialogue_text, 30.0)
	
	dialogue_choices = Label.new()
	dialogue_choices.position = Vector2(40, 175)
	dialogue_choices.size = Vector2(1120, 50)
	dialogue_choices.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	dialogue_panel.add_child(dialogue_choices)
	_apply_label_font(dialogue_choices, 19)
	
	xp_label.text = "Уровень: 1 (DEBUG)"
	xp_label.visible = true
	print("XP Label создан и виден: ", xp_label.get_global_rect())
	
	update_all_ui()

func build_boss_hp_bar_ui() -> void:
	boss_ui_layer = CanvasLayer.new()
	boss_ui_layer.visible = false
	add_child(boss_ui_layer)
	
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.position = Vector2(510, 65)
	boss_hp_bar.size = Vector2(900, 24)
	boss_hp_bar.show_percentage = false
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.75, 0.05, 0.05)
	sb_fill.border_width_left = 2; sb_fill.border_width_top = 2
	sb_fill.border_width_right = 2; sb_fill.border_width_bottom = 2
	sb_fill.border_color = Color(0.1, 0.1, 0.1)
	boss_hp_bar.add_theme_stylebox_override("fill", sb_fill)
	boss_ui_layer.add_child(boss_hp_bar)
	
	boss_name_label = Label.new()
	boss_name_label.text = "КИКИМОРА БОЛОТНАЯ — ХРАНИТЕЛЬНИЦА КАПИЩА"
	boss_name_label.position = Vector2(510, 25)
	boss_name_label.size = Vector2(900, 30)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	boss_ui_layer.add_child(boss_name_label)
	_apply_label_font(boss_name_label, 22)

func build_minimap_ui() -> void:
	var minimap_panel = Panel.new()
	minimap_panel.position = Vector2(40, 300)
	minimap_panel.size = Vector2(220, 220)
	$HUDLayer.add_child(minimap_panel)
	
	# Создаем круглый стиль
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 4; style.border_width_top = 4
	style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(0.7, 0.5, 0.3)
	style.corner_radius_top_left = 110; style.corner_radius_top_right = 110
	style.corner_radius_bottom_left = 110; style.corner_radius_bottom_right = 110
	minimap_panel.add_theme_stylebox_override("panel", style)
	
	# Метка "Миникарта" сверху
	var m_label = Label.new()
	m_label.text = "Миникарта"
	# Позиция: x=0, y=высота панели + немного отступа
	m_label.position = Vector2(0, 230) 
	m_label.size = Vector2(220, 20)
	m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_font(m_label, 16)
	minimap_panel.add_child(m_label)
	
	minimap_content = Control.new()
	minimap_content.position = Vector2(10, 10)
	minimap_content.size = Vector2(200, 200)
	# Ограничиваем область видимости, чтобы точки не вылезали за круг
	minimap_content.clip_contents = true 
	minimap_panel.add_child(minimap_content)

func build_quest_and_inventory_ui() -> void:
	# Загружаем шрифт один раз
	var font_res = load("res://assets/fonts/main_font.otf") if ResourceLoader.exists("res://assets/fonts/main_font.otf") else null
	
	# --- Панель квестов ---
	var quest_panel = Panel.new()
	quest_panel.position = Vector2(1440, 40)
	quest_panel.size = Vector2(440, 240)
	$HUDLayer.add_child(quest_panel)
	
	# Заголовок квестов
	var quest_title = Label.new()
	quest_title.text = "АКТУАЛЬНЫЙ СКАЗ:"
	quest_title.position = Vector2(25, 20)
	quest_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	if font_res:
		quest_title.add_theme_font_override("font", font_res)
		quest_title.add_theme_font_size_override("font_size", 18)
	quest_panel.add_child(quest_title)
	
	# Текст квестов (чистый, без BBCode)
	quest_text = RichTextLabel.new()
	quest_text.bbcode_enabled = true
	quest_text.position = Vector2(25, 60)
	quest_text.size = Vector2(390, 160)
	quest_text.scroll_active = false
	
	if font_res:
		quest_text.add_theme_font_override("normal_font", font_res)
		quest_text.add_theme_font_size_override("normal_font_size", 17)
	
	# Устанавливаем мягкий бежевый цвет текста
	quest_text.add_theme_color_override("default_color", Color(0.92, 0.88, 0.75))
	
	quest_panel.add_child(quest_text)
	apply_retro_style(quest_panel, null, 20.0)
	
	# --- Панель инвентаря ---
	var inv_panel = Panel.new()
	inv_panel.position = Vector2(1440, 815)
	inv_panel.size = Vector2(440, 225)
	$HUDLayer.add_child(inv_panel)
	
	var inv_title = Label.new()
	inv_title.text = "СУМКА С КУДЕЕЙ:"
	inv_title.position = Vector2(25, 20)
	inv_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	if font_res:
		inv_title.add_theme_font_override("font", font_res)
		inv_title.add_theme_font_size_override("font_size", 18)
	inv_panel.add_child(inv_title)
	
	inv_slots_text = Label.new()
	inv_slots_text.position = Vector2(25, 65)
	inv_slots_text.size = Vector2(390, 135)
	if font_res:
		inv_slots_text.add_theme_font_override("font", font_res)
		inv_slots_text.add_theme_font_size_override("font_size", 16)
	inv_slots_text.add_theme_color_override("font_color", Color(0.92, 0.88, 0.75))
	
	inv_panel.add_child(inv_slots_text)
	apply_retro_style(inv_panel, inv_slots_text, 20.0)

func build_pause_menu_ui() -> void:
	pause_canvas = CanvasLayer.new()
	pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_canvas.visible = false
	add_child(pause_canvas)
	
	var blur = ColorRect.new()
	blur.size = Vector2(1920, 1080)
	blur.color = Color(0.04, 0.03, 0.03, 0.82)
	pause_canvas.add_child(blur)
	
	var panel = Panel.new()
	panel.position = Vector2(710, 290)
	panel.size = Vector2(500, 520)
	pause_canvas.add_child(panel)
	
	var title = Label.new()
	title.text = "ДРЕВНЯЯ ПАУЗА"
	title.position = Vector2(0, 45)
	title.size = Vector2(500, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	panel.add_child(title)
	apply_retro_style(panel, title, 25.0)
	
	var font_res = load("res://assets/fonts/main_font.otf") if ResourceLoader.exists("res://assets/fonts/main_font.otf") else null
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.12, 0.11)
	style_normal.border_width_bottom = 4
	style_normal.border_color = Color(0.58, 0.42, 0.25)
	style_normal.corner_radius_top_left = 6; style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6; style_normal.corner_radius_bottom_left = 6
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.26, 0.18, 0.16)
	style_hover.border_color = Color(0.95, 0.75, 0.3)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.12, 0.08, 0.07)
	style_pressed.border_width_bottom = 1
	style_pressed.border_color = Color(0.4, 0.3, 0.18)
	
	var setup_btn = func(btn: Button, text: String, pos: Vector2):
		btn.text = text
		btn.position = pos
		btn.size = Vector2(320, 55)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
		btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.5, 0.4))
		
		if font_res:
			btn.add_theme_font_override("font", font_res)
			btn.add_theme_font_size_override("font_size", 18)
		panel.add_child(btn)
	
	var btn_resume = Button.new()
	setup_btn.call(btn_resume, "ПРОДОЛЖИТЬ ПУТЬ", Vector2(90, 145))
	btn_resume.pressed.connect(toggle_pause)
	
	var line = ColorRect.new()
	line.position = Vector2(90, 230)
	line.size = Vector2(320, 2)
	line.color = Color(0.4, 0.3, 0.2, 0.5)
	panel.add_child(line)
	
	var settings_label = Label.new()
	settings_label.text = "НАСТРОЙКИ СКАЗА:"
	settings_label.position = Vector2(0, 255)
	settings_label.size = Vector2(500, 30)
	settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	if font_res: settings_label.add_theme_font_override("font", font_res)
	settings_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(settings_label)
	
	var btn_scale = Button.new()
	setup_btn.call(btn_scale, "ЭКРАН: ПОЛНОРАЗМЕРНЫЙ", Vector2(90, 300))
	btn_scale.pressed.connect(func():
		var fs = DisplayServer.window_get_mode()
		if fs == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			btn_scale.text = "ЭКРАН: В ОКНЕ"
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			btn_scale.text = "ЭКРАН: ПОЛНОРАЗМЕРНЫЙ"
	)
	
	var btn_exit = Button.new()
	setup_btn.call(btn_exit, "ВЫЙТИ В ПОСАД", Vector2(90, 410))
	btn_exit.pressed.connect(func(): get_tree().quit())

func toggle_pause() -> void:
	var state = get_tree().paused
	get_tree().paused = !state
	pause_canvas.visible = !state

func update_minimap() -> void:
	if not is_instance_valid(minimap_content) or not is_instance_valid(player): return
	for n in minimap_content.get_children(): n.queue_free()
	
	var p = ColorRect.new()
	p.size = Vector2(8, 8)
	p.position = Vector2(85, 85)
	p.color = Color.WHITE
	minimap_content.add_child(p)
	
	var sm = 0.05
	for obj in level_objects:
		if is_instance_valid(obj):
			var mp = Vector2(85, 85) + (obj.position - player.position) * sm
			if mp.x > 5 and mp.x < 173 and mp.y > 5 and mp.y < 173:
				var d := ColorRect.new()
				d.size = Vector2(6, 6)
				d.position = mp
				if enemy_list.has(obj):
					d.color = Color(0.9, 0.15, 0.15)
				else:
					d.color = Color(0.65, 0.25, 0.85)
				minimap_content.add_child(d)

func trigger_dialogue(id: String, main_text: String, choices: String) -> void:
	current_dialogue_id = id
	is_dialogue_active = true
	dialogue_text.text = main_text
	dialogue_choices.text = choices
	dialogue_panel.visible = true

# Вспомогательные заглушки-функции для визуальных эффектов боя
func update_hp_display() -> void:
	if is_instance_valid(hp_bar):
		hp_bar.value = Global.current_hp
	if is_instance_valid(mp_bar):
		mp_bar.value = Global.current_mp
func create_melee_flash(_pos: Vector2) -> void: pass
func spawn_xp_effect(_pos: Vector2) -> void: pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"): toggle_pause(); return
	if is_dialogue_active:
		if event.is_action_pressed("choice1"): handle_dialogue_choice(1)
		elif event.is_action_pressed("choice2"): handle_dialogue_choice(2)
		elif event.is_action_pressed("choice3"): handle_dialogue_choice(3)
		return
		
	if event.is_action_pressed("switch_world"): switch_world(!is_nav_world)
	
	# Перекат
	if event.is_action_pressed("roll") and not is_rolling:
		if Global.current_stamina >= 25.0:
			Global.current_stamina -= 25.0
			is_rolling = true
			var anim_fps = player_anim.sprite_frames.get_animation_speed("roll")
			var frame_count = player_anim.sprite_frames.get_frame_count("roll")
			roll_timer = float(frame_count) / anim_fps
			roll_direction = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")).normalized()
			if roll_direction == Vector2.ZERO: 
				roll_direction = Vector2.LEFT if player_anim.flip_h else Vector2.RIGHT
			player_anim.modulate = Color(0.5, 0.7, 1.0, 0.7)
		else:
			# Можно добавить звук "нет стамины" или просто проигнорировать
			print("Недостаточно силы для переката!")
		return
		
	if event.is_action_pressed("attack") and not is_rolling:
		var att_dir = Vector2.LEFT if player_anim.flip_h else Vector2.RIGHT
		create_melee_flash(player.position + att_dir * 60.0)
		for enemy in enemy_list:
			if is_instance_valid(enemy) and enemy.get_meta("status") == "aggressive":
				if player.position.distance_to(enemy.position) < 140.0:
					var ehp = enemy.get_meta("hp") - 40.0
					enemy.set_meta("hp", ehp)
					if enemy.get_meta("id_tag") == "boss" and boss_ui_layer.visible: boss_hp_bar.value = ehp
					if ehp <= 0: kill_enemy(enemy)
		return
		
			
func apply_class_stats() -> void:
	if Global.player_class == "Воин":
		Global.max_hp = 150
		Global.max_mp = 50
	elif Global.player_class == "Волхв":
		Global.max_hp = 80
		Global.max_mp = 150
	elif Global.player_class == "Травник":
		Global.max_hp = 110
		Global.max_mp = 100
	else:
		# Стандартные значения, если класс не выбран
		Global.max_hp = 100
		Global.max_mp = 100
func update_location_data(new_location: String) -> void:
	current_location_name = new_location
	print("Локация обновлена на: ", new_location)
	
	# 1. Удаляем все объекты старой локации (врагов и порталы)
	for obj in level_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	level_objects.clear()
	enemy_list.clear()
	active_projectiles.clear()
	
	# 2. Меняем фон
	if new_location == "Древнее Капище":
		background.texture = load_texture_safe("res://assets/bg_shrine.png", Vector2(1920, 1080), Color(0.15, 0.1, 0.15))
		# Спавним содержимое Капища
		spawn_enemy(Vector2(1600, 700), "res://assets/kikimora.png", Color(0.2, 0.6, 0.2), "boss")
		spawn_item(Vector2(1750, 750), "crystal")
		spawn_portal(Vector2(3000, 700), "ПОБЕДА")
		trigger_dialogue("kikimora_start", "Кикимора: Кто посмел осквернить Древнее Капище?", "[1] Мир | [2] Бой")
	
	elif new_location == "Окраина Чернолесья":
		background.texture = load_texture_safe("res://assets/bg_tutorial.png", Vector2(1920, 1080), Color(0.12, 0.14, 0.12))
		# ... тут спавн триггеров обучения, если нужно
		
	# 3. Перемещаем игрока на стартовую позицию
	player.position = Vector2(250, 500)
	
	# 4. Обновляем интерфейс
	update_world_label_ui()
	update_quest_journal()
func kill_enemy(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy): return
	
	# Эффекты смерти
	spawn_xp_effect(enemy.position)
	
	# Логика победы над боссом
	if enemy.get_meta("id_tag") == "boss":
		current_combat_mode = CombatMode.PEACE # <--- Снимаем блокировку с кристалла
		boss_ui_layer.visible = false
		world_label.text = "КИКИМОРА ПОВЕРЖЕНА!"
		update_world_label_ui() # Обновляем заголовок, чтобы он не застрял на тексте победы
		
	if enemy.get_meta("id_tag") == "boss":
		quest_objectives["defeat_kikimora"] = true # Ставим галочку
		update_quest_journal() # Обновляем UI
		
	# Удаление врага
	enemy_list.erase(enemy)
	level_objects.erase(enemy)
	enemy.queue_free()
	
	# Финальные обновления
	update_all_ui()
	update_quest_journal()

func spawn_boss_projectile(start_pos: Vector2, target_pos: Vector2) -> void:
	var proj := Node2D.new()
	# Смещаем спавн на 60 пикселей вперед, чтобы снаряд не задевал босса
	var dir = (target_pos - start_pos).normalized()
	proj.position = start_pos + dir * 60.0 
	
	proj.set_meta("dir", dir)
	proj.set_meta("speed", 300.0)
	proj.set_meta("damage", 15.0)
	proj.set_meta("lifetime", 2.0)
	
	var spr := Sprite2D.new()
	spr.texture = load_texture_safe("res://assets/spell.png", Vector2(20, 20), Color(0.2, 0.8, 0.2))
	proj.add_child(spr)
	
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 15.0
	area.add_child(shape)
	proj.add_child(area)
	
	# Важно: используем set_collision_mask_value, чтобы игнорировать босса (если он на 2-м слое)
	# Или просто проверяем, является ли body игроком
	area.body_entered.connect(func(body):
		if body == player and not is_rolling:
			Global.current_hp -= 15.0
			update_hp_display()
			player_anim.modulate = Color(1.0, 0.3, 0.3)
			create_tween().tween_property(player_anim, "modulate", Color(1,1,1), 0.2)
			proj.queue_free()
	)
	add_child(proj)
	active_projectiles.append(proj)
	
func update_all_ui() -> void:
	# Обновляем бары
	if is_instance_valid(hp_bar):
		hp_bar.max_value = Global.max_hp
		hp_bar.value = Global.current_hp
		
	if is_instance_valid(mp_bar):
		mp_bar.max_value = Global.max_mp
		mp_bar.value = Global.current_mp
		
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = Global.max_stamina
		stamina_bar.value = Global.current_stamina
		
	# Обновляем уровень и XP
	if is_instance_valid(xp_label):
		# Предполагаем, что у тебя в Global есть переменные player_level, current_xp и xp_to_next_level
		xp_label.text = "Уровень: %d (%d / %d XP)" % [
			Global.player_level, 
			Global.player_xp, 
			Global.xp_to_next_level
		]
		
func _on_projectile_hit(enemy: Node2D) -> void:
	# Проверяем, существует ли враг и активен ли он
	if is_instance_valid(enemy) and enemy.get_meta("status") == "aggressive":
		var damage = 35.0 
		var enemy_hp = enemy.get_meta("hp") - damage
		enemy.set_meta("hp", enemy_hp)
		
		# Визуальный эффект
		print("Попадание по врагу! HP: ", enemy_hp)
		
		# Обновление UI босса
		if enemy.get_meta("id_tag") == "boss":
			boss_hp_bar.value = enemy_hp
			
		# Проверка смерти
		if enemy_hp <= 0:
			kill_enemy(enemy)

func spawn_projectile(start_pos: Vector2, dir: Vector2) -> void:
	var proj = Area2D.new()
	proj.position = start_pos + (dir * 45.0)
	
	# 1. Принудительно задаем коллизии
	proj.collision_layer = 0  # Снаряд не должен сталкиваться с другими снарядами
	proj.collision_mask = 2   # Снаряд ищет врагов на 2-м слое (проверь, на каком слое Кикимора!)
	
	# 2. Создаем коллизию
	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 15.0
	proj.add_child(col)
	
	# 3. Подключаем сигнал
	proj.body_entered.connect(_on_projectile_hit)
	
	add_child(proj)
	active_projectiles.append(proj)
	
	# Создаем спрайт снаряда
	var spr = Sprite2D.new()
	# Используем стандартный load, если load_texture_safe не определена в твоем скрипте
	if ResourceLoader.exists("res://assets/spell.png"):
		spr.texture = load("res://assets/spell.png")
	else:
		# Если картинки нет, создаем простой желтый квадратик
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.YELLOW)
		spr.texture = ImageTexture.create_from_image(img)
	proj.add_child(spr)
	
	# Коллизия снаряда
	var p_col = CollisionShape2D.new()
	p_col.shape = CircleShape2D.new()
	p_col.shape.radius = 10.0
	proj.add_child(p_col)
	
	# Установка параметров
	proj.set_meta("dir", dir)
	proj.set_meta("speed", 600.0)
	proj.set_meta("damage", 30.0)
	proj.set_meta("lifetime", 2.0)
	
	proj.body_entered.connect(_on_projectile_hit)
	
	add_child(proj)
	active_projectiles.append(proj)
