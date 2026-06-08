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

var is_switching: bool = false # Блокировка переключения

var nav_cooldown: float = 0.0

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

var mp_bar_style: StyleBoxFlat # Сюда сохраним стиль, чтобы менять его позже

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
var attack_cooldown: float = 0.0 # Таймер задержки выстрела
var attack_delay: float = 0.5    # Задержка в 0.5 секунды между выстрелами

var is_first_run: bool = true # Добавь в переменные класса

func _ready() -> void:
	# Даем игре 0.5 секунды на загрузку всех узлов, 
	# чтобы порталы не открылись мгновенно из-за старых данных
	await get_tree().create_timer(0.5).timeout
	check_and_open_portal()
	# 1. Сначала создаем объекты, которые нужны для работы функций
	canvas_modulate = CanvasModulate.new()
	add_child(canvas_modulate)
	
	# 2. Теперь можем безопасно менять цвет
	canvas_modulate.color = Color(0.85, 0.85, 0.95)
	
	# 3. Настройка пост-обработки (вынесено в отдельный метод)
	setup_post_processing()
	
	if has_node("/root/TransitionManager"):
		# Добавили проверку, чтобы не падать, если TransitionManager еще не готов
		if TransitionManager.get("fade"):
			TransitionManager.fade.color.a = 0.0
			
	Global.current_mp = 100.0
	Global.reset_game_data()
	apply_class_stats()
	
	background = TextureRect.new()
	background.size = Vector2(map_width, map_height)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background)
	
	build_player()
	build_advanced_hud()
	build_boss_hp_bar_ui()
	build_minimap_ui()
	build_quest_and_inventory_ui()
	build_pause_menu_ui()
	
	update_all_ui()
	setup_input_map()
	
	start_tutorial_quest()
	load_location("Окраина Чернолесья", false)

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

func load_location(location_name: String, show_animation: bool = true) -> void:
	for proj in active_projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
		active_projectiles.clear()
	# Теперь он не будет пытаться анимировать, если ты передал false
	if show_animation and has_node("/root/TransitionManager"):
		var tween = create_tween()
		tween.tween_property(TransitionManager.fade, "color:a", 1.0, 0.5)
		await tween.finished
	
	# 2. Очистка
	for obj in level_objects: 
		if is_instance_valid(obj): obj.queue_free()
	level_objects.clear()
	enemy_list.clear()
	active_projectiles.clear()
	
	# 3. Смена данных
	current_location_name = location_name
	player.position = Vector2(250, 500)
	is_dialogue_active = false
	if is_instance_valid(dialogue_panel): dialogue_panel.visible = false
	if is_instance_valid(boss_ui_layer): boss_ui_layer.visible = false
	
	# 4. Логика расстановки (сохранена твоя)
	if location_name == "Окраина Чернолесья":
		background.texture = load_texture_safe("res://assets/bg_tutorial.png", Vector2(1920, 1080), Color(0.12, 0.14, 0.12))
		spawn_tutorial_trigger(Vector2(700, 600), "move", "Камень Движения")
		spawn_tutorial_trigger(Vector2(1400, 700), "roll", "Камень Уклонения")
		spawn_tutorial_trigger(Vector2(2100, 800), "nav", "Камень Нави")
		spawn_portal(Vector2(2800, 750), "Древнее Капище")
	elif location_name == "Древнее Капище":
		background.texture = load_texture_safe("res://assets/bg_shrine.png", Vector2(1920, 1080), Color(0.15, 0.1, 0.15))
		if current_combat_mode == CombatMode.COMBAT:
			spawn_enemy(Vector2(1600, 700), "res://assets/kikimora.png", Color(0.2, 0.6, 0.2), "boss")
			scatter_herbs(3)
			trigger_dialogue("kikimora_start", "Кикимора: Кто посмел осквернить Капище?", "[1] Договориться | [2] Напасть")
		else:
			world_label.text = "Капище очищено от скверны."
			
	update_world_label_ui()
	update_quest_journal()
	
	# 5. Возврат экрана
	if show_animation and has_node("/root/TransitionManager"):
		var tween_in = create_tween()
		tween_in.tween_property(TransitionManager.fade, "color:a", 0.0, 0.5)

func _process(delta: float) -> void:
	# 1. Базовые проверки
	update_all_ui()
	check_and_open_portal()
	
	if not is_instance_valid(player): return
	
	if get_tree().paused or is_dialogue_active: return
	if Global.current_hp <= 0:
		set_process(false)
		TransitionManager.fade_to_scene("res://scenes/GameOver.tscn")
		return
	
	# 2. Логика Нави/Яви
	if is_nav_world:
		if nav_cooldown > 0:
			# Сначала тикает таймер задержки
			nav_cooldown -= delta
		else:
			# Когда таймер дошел до 0, начинаем тратить ману
			Global.current_mp -= 10.0 * delta
			
			if Global.current_mp <= 0:
				Global.current_mp = 0
				switch_world(false) # Автоматический возврат в Явь
				Global.current_hp -= 10.0
				
	# Регенерация/Трата маны в зависимости от мира
	if is_nav_world:
		# Если в Нави, таймер тикает, потом тратим ману
		if nav_cooldown > 0:
			nav_cooldown -= delta
		else:
			Global.current_mp -= 10.0 * delta # ТРАТА в Нави
			if Global.current_mp <= 0:
				Global.current_mp = 0
				switch_world(false)
				Global.current_hp -= 10.0
	else:
		# Если в Яви, ВОССТАНАВЛИВАЕМ ману
		Global.current_mp = min(Global.current_mp + mp_regen_speed_yav * delta, 100.0)
	
	# Реген стамины (всегда)
	Global.current_stamina = min(Global.current_stamina + stamina_regen_speed * delta, Global.max_stamina)
	update_minimap()

	# 3. Движение игрока
	var input_dir = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")).normalized()
	if is_rolling:
		if player_anim.animation != "roll": player_anim.play("roll")
		player.velocity = roll_direction * roll_speed
		roll_timer -= delta
		if roll_timer <= 0: is_rolling = false
	else:
		player.velocity = input_dir * player_speed
		if input_dir != Vector2.ZERO:
			player_anim.flip_h = (input_dir.x < 0)
			player_anim.play("walk" if player_anim.sprite_frames.has_animation("walk") else "idle")
		else:
			player_anim.play("idle")
			
	player.move_and_slide()
	player.position.x = clamp(player.position.x, 100, map_width - 100)
	player.position.y = clamp(player.position.y, 500, map_height - 200)
	
	# 3. Регенерация
	Global.current_stamina = min(Global.current_stamina + stamina_regen_speed * delta, Global.max_stamina)
	update_minimap()
	
	# 4. Обработка снарядов
	var dead_projectiles = []
	for proj in active_projectiles:
		if not is_instance_valid(proj): continue
		
		# Анимация
		proj.rotation += 10.0 * delta
		var time_passed = (Time.get_ticks_msec() - proj.get_meta("spawn_time")) * 0.01
		proj.scale = Vector2.ONE * (1.0 + sin(time_passed) * 0.3)
		
		# Жизнь и движение
		var life = proj.get_meta("lifetime") - delta
		proj.set_meta("lifetime", life)
		if life <= 0:
			dead_projectiles.append(proj)
			continue
		proj.global_position += proj.get_meta("dir") * proj.get_meta("speed") * delta
		
		# Урон по игроку (от босса)
		if proj.get_meta("owner_id") == "boss" and life < 1.85:
			if proj.global_position.distance_to(player.position) < 50.0 and not is_rolling:
				Global.current_hp = max(0, Global.current_hp - 10.0)
				update_all_ui()
				_trigger_hit_effect()
				dead_projectiles.append(proj)
				continue
		
		# Попадание по врагам
		for enemy in enemy_list:
			if is_instance_valid(enemy) and not (proj.get_meta("owner_id") == "boss" and enemy.get_meta("id_tag") == "boss"):
				if proj.global_position.distance_to(enemy.global_position) < 120.0:
					_on_projectile_hit(enemy)
					dead_projectiles.append(proj)
					break

	for dp in dead_projectiles:
		active_projectiles.erase(dp)
		if is_instance_valid(dp): dp.queue_free()
	
	# 5. Стрельба
	if attack_cooldown > 0: attack_cooldown -= delta
	if Input.is_action_just_pressed("cast_spell") and not is_rolling and attack_cooldown <= 0:
		if Global.current_mp >= mp_spell_cost:
			Global.current_mp -= mp_spell_cost
			attack_cooldown = attack_delay
			var dir = (get_global_mouse_position() - player.position).normalized()
			spawn_projectile(player.position, dir, "player")

	# 6. Враги (логика перемещена)
	_process_enemies(delta)

# Вспомогательный метод для чистоты кода
func _trigger_hit_effect() -> void:
	if is_instance_valid(player_anim):
		if player_anim.has_meta("hit_tween") and is_instance_valid(player_anim.get_meta("hit_tween")):
			player_anim.get_meta("hit_tween").kill()
		player_anim.modulate = Color(1.0, 0.3, 0.3)
		var t = create_tween()
		t.tween_property(player_anim, "modulate", Color(1, 1, 1), 0.2)
		player_anim.set_meta("hit_tween", t)

func handle_dialogue_choice(index: int) -> void:
	# Сохраняем ID текущего диалога, чтобы знать, что обрабатывать
	var last_id = current_dialogue_id
	
	is_dialogue_active = false
	dialogue_panel.visible = false
	
	if last_id.begins_with("tutorial_"): return
		
	if last_id == "kikimora_start":
		if index == 1: # Мирный путь
			current_combat_mode = CombatMode.PEACE
			change_path("Путь Стали и Магии")
			
			# Переводим врагов в статус дружелюбных
			for e in enemy_list: 
				if is_instance_valid(e): e.set_meta("status", "friendly")
			
			# Запускаем "второй акт" диалога
			trigger_dialogue("kikimora_peace", "Кикимора: Твоё почтение спасло жизнь. Забирай Кристалл.", "[1] Забрать кристалл и уйти")
			
		elif index == 2: # Боевой путь
			current_combat_mode = CombatMode.COMBAT
			change_path("Путь Стали и Магии")
			
			# Активируем босса
			for e in enemy_list:
				if is_instance_valid(e):
					e.set_meta("status", "aggressive")
					if e.get_meta("id_tag") == "boss":
						boss_ui_layer.visible = true
						
	elif last_id == "kikimora_peace":
		if index == 1:
			inventory["crystal"] += 1
			quest_objectives["find_crystal"] = true
			quest_objectives["defeat_kikimora"] = true
			update_inventory_ui()
			world_label.text = "Кристалл в сумке."
			
	# Общие обновления
	update_quest_journal()
	update_world_label_ui()

func spawn_tutorial_trigger(pos: Vector2, step_id: String, msg: String) -> void:
	var area := Area2D.new()
	area.position = pos
	
	var spr := Sprite2D.new()
	# ЗАМЕНИ ЭТУ СТРОКУ:
	# spr.texture = load_texture_safe("res://assets/stone.png", Vector2(50, 60), Color(0.4, 0.4, 0.4))
	
	# НА ЭТУ (укажи путь к твоей картинке камня):
	spr.texture = load("res://assets/tutorial_stone.png") # Путь к твоей текстуре
	spr.scale = Vector2(1.5, 1.5) # Настрой размер, если текстура слишком большая
	area.add_child(spr)
	
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 80.0
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
	# 1. Создаем врага
	var enemy := CharacterBody2D.new()
	enemy.position = pos
	enemy.set_meta("id_tag", id_tag)
	enemy.set_meta("hp", 300.0)
	enemy.set_meta("status", "aggressive")
	enemy.set_meta("attack_timer", 0.0)
	enemy.set_meta("melee_timer", 0.0)
	enemy.set_meta("hit_tween", null)
	
	# 2. Анимация
	var anim_spr := AnimatedSprite2D.new()
	anim_spr.name = "AnimatedSprite2D"
	anim_spr.scale = Vector2(2.5, 2.5)
	
	var frames_res = load("res://assets/kikimora_frames.tres")
	if frames_res:
		anim_spr.sprite_frames = frames_res
		anim_spr.play("idle")
		enemy.add_child(anim_spr)
	else:
		# Заглушка, если файл не найден
		var spr := Sprite2D.new()
		spr.texture = load_texture_safe(path, Vector2(80, 120), fallback_color)
		enemy.add_child(spr)
	
	# 3. Коллизия
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 300)
	print("Кикимора создана. Хитбокс размер: ", rect.size)
	shape.shape = rect
	shape.position = Vector2(0, 15)
	enemy.add_child(shape)

	# 4. ВАЖНО: Добавляем врага в сцену ПЕРЕД тем, как менять UI
	add_child(enemy)
	enemy_list.append(enemy)
	level_objects.append(enemy)

	# 5. UI босса
	if id_tag == "boss":
		boss_hp_bar.max_value = 300.0
		boss_hp_bar.value = 300.0
		# Если ты хочешь, чтобы полоска была всегда видна при спавне босса:
		boss_hp_bar.show()

func spawn_item(pos: Vector2, type: String) -> void:
	var item := Area2D.new()
	item.position = pos
	item.set_meta("type", type)
	
	var spr := Sprite2D.new()
	spr.texture = load_texture_safe("res://assets/crystal.png", Vector2(32, 32), Color.CYAN)
	
	# --- ВКЛЮЧАЕМ СВЕЧЕНИЕ ---
	spr.modulate = Color(3.0, 3.0, 3.0, 1.0) # Яркое свечение для Bloom
	
	# --- ПУЛЬСАЦИЯ (необязательно, для красоты) ---
	var tween = create_tween().set_loops()
	tween.tween_property(spr, "modulate", Color(5.0, 5.0, 5.0, 1.0), 1.0)
	tween.tween_property(spr, "modulate", Color(2.0, 2.0, 2.0, 1.0), 1.0)
	
	item.add_child(spr)
	
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 50.0
	item.add_child(shape)
	
	# Логика подбора
	item.body_entered.connect(func(body):
		if body == player:
			if type == "crystal":
				inventory["crystal"] += 1
				update_inventory_ui()
				item.queue_free()
				check_and_open_portal()
	)
	
	add_child(item)
	level_objects.append(item)

func spawn_portal(pos: Vector2, target: String) -> Area2D:
	var portal := Area2D.new()
	portal.name = "MyPortal"
	portal.position = pos
	
	# Мета-данные
	portal.set_meta("type", "portal")
	portal.set_meta("is_open", false)
	portal.set_meta("target", target)
	
	# 1. СОЗДАЕМ МОЩНЫЙ СВЕТ ЗА ПОРТАЛОМ
	var light := PointLight2D.new()
	light.name = "PointLight2D"
	
	# Создаем программно мягкий градиент
	var light_size = 256 
	var img = Image.create(light_size, light_size, false, Image.FORMAT_RGBA8)
	for y in range(light_size):
		for x in range(light_size):
			var center = Vector2(light_size / 2.0, light_size / 2.0)
			var dist = Vector2(x, y).distance_to(center)
			var max_dist = light_size / 2.0
			
			if dist < max_dist:
				var alpha = 1.0 - (dist / max_dist)
				# Мощный спад, чтобы край был мягким
				alpha = pow(alpha, 2.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * 0.9)) # Ярче в центре
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0)) 
	var tex = ImageTexture.create_from_image(img)
	light.texture = tex
	
	# -- Настройки мощного света (АУРА) --
	light.energy = 0.0          # Включаем в open_portal
	light.texture_scale = 2.5   # Широкий ореол (в 2.5 раза больше спрайта)
	light.blend_mode = PointLight2D.BLEND_MODE_ADD # Яркое свечение
	# Цвет света (розово-фиолетовый, чтобы подходил)
	light.color = Color(1.0, 0.4, 1.0) 
	
	# ГАРАНТИРУЕМ, ЧТО СВЕТ СЗАДИ
	light.z_index = -1 
	
	portal.add_child(light)
	
	# 2. СОЗДАЕМ СПРАЙТ ПОРТАЛА (ВЕРНУЛИ ЕМУ РОДНЫЕ ЦВЕТА)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	if ResourceLoader.exists("res://assets/portal.png"):
		spr.texture = load("res://assets/portal.png")
	else:
		spr.texture = load("res://icon.svg")
		
	# -- НАСТРОЙКИ СПРАЙТА: ОН ДОЛЖЕН БЫТЬ ПОВЕРХ --
	spr.z_index = 0             # Спрайт на Z=0 (или 1), а свет на Z=-1
	spr.modulate = Color(1, 1, 1, 1) # Чистый, оригинальный цвет спрайта
	
	portal.add_child(spr)
	
	# 1. Создаем материал для спрайта
	var mat := CanvasItemMaterial.new()
	
	# 2. Устанавливаем режим освещения "Unshaded" (Неосвещаемый)
	# Это заставит спрайт игнорировать любые PointLight2D на сцене
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	
	# 3. Применяем материал к спрайту
	spr.material = mat
	
	# 3. КОЛЛАЙДЕР И ОСТАЛЬНОЕ
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	# Настрой размер под спрайт (например, под 256x256 спрайт)
	shape.shape.size = Vector2(100, 200) 
	portal.add_child(shape)
	
	# Слои коллизии
	portal.collision_layer = 1
	portal.collision_mask = 1
	
	# Финальные настройки Area2D (скрыт при спавне)
	# Мы скрываем через прозрачность Z-Index, чтобы он не моргал
	portal.visible = false
	portal.modulate.a = 0.0
	portal.monitoring = false
	
	# 4. РЕГИСТРАЦИЯ
	add_child(portal)
	level_objects.append(portal)
	
	return portal

func _on_portal_body_entered(body: Node2D, portal: Area2D) -> void:
	if body != player: return
	
	# Получаем target из мета-данных портала внутри функции
	var target = portal.get_meta("target")
	
	if portal.has_meta("is_open") and portal.get_meta("is_open") == false:
		return
		
	if target == "ПОБЕДА":
		if inventory.get("crystal", 0) >= 1:
			TransitionManager.fade_to_scene("res://scenes/Victory.tscn")
		else:
			world_label.text = "Кикимора не пустит!"
		return

	load_location(target)

func change_path(new_name: String) -> void:
	chosen_path_name = new_name
	if is_instance_valid(world_label):
		update_world_label_ui()
		
var world_tween: Tween

func switch_world(to_nav: bool) -> void:
	# 1. Если мы уже в нужном состоянии или процесс переключения идет — выходим
	if is_nav_world == to_nav or is_switching:
		return
	
	# 2. Включаем блокировку
	is_switching = true
	
	if to_nav:
		nav_cooldown = 2.0 # Время, сколько персонаж может находиться в Нави до траты маны
		print("DEBUG: Навь включена, таймер запущен")
	
	is_nav_world = to_nav
	
	# Обновляем стиль полоски маны
	if mp_bar_style:
		mp_bar_style.bg_color = Color(0.2, 0.8, 0.2) if is_nav_world else Color(0.22, 0.44, 0.78)
	
	# Твин (анимация мира)
	if is_instance_valid(canvas_modulate) and is_instance_valid(player_anim):
		if world_tween and world_tween.is_running():
			world_tween.kill()
		world_tween = create_tween()
		var target_color = Color(0.2, 0.1, 0.4) if is_nav_world else Color(1.0, 1.0, 1.0)
		world_tween.tween_property(canvas_modulate, "color", target_color, 0.5)
		world_tween.parallel().tween_property(player_anim, "modulate:a", 0.6 if is_nav_world else 1.0, 0.5)
	
	# Физика
	if is_instance_valid(player):
		player.set_collision_mask_value(1, not is_nav_world)
	
	# Враги
	for enemy in enemy_list:
		if is_instance_valid(enemy):
			enemy.set_meta("status", "friendly" if is_nav_world else "aggressive")
			
	# 4. Снимаем блокировку через небольшой промежуток времени
	await get_tree().create_timer(0.3).timeout
	is_switching = false

func update_world_label_ui() -> void: world_label.text = "МЕСТО: %s\nПУТЬ: %s" % [current_location_name.to_upper(), chosen_path_name.to_upper()]

func update_quest_journal() -> void:
	# 1. ЛОГИКА ОТКРЫТИЯ ПОРТАЛОВ
	for obj in level_objects:
		if not is_instance_valid(obj): continue
		
		if obj is Area2D and obj.has_meta("type") and obj.get_meta("type") == "portal":
			# Если уже открыт — выходим из итерации
			if obj.has_meta("is_open") and obj.get_meta("is_open") == true:
				continue

			var should_open = false
			
			if current_location_name == "Окраина Чернолесья":
				if tutorial_steps_done.move and tutorial_steps_done.roll and tutorial_steps_done.nav:
					remove_tutorial_button()
					should_open = true
			
			elif current_location_name == "Древнее Капище":
				# ВАЖНО: Проверим, что реально происходит с квестом
				var has_crystal = quest_objectives.get("find_crystal", false)
				print("DEBUG: В Капище, кристалл найден: ", has_crystal)
				if has_crystal:
					should_open = true
			
			if should_open:
				print("DEBUG: Открываю портал!")
				open_portal(obj)

	# 2. ОБНОВЛЕНИЕ ТЕКСТА КВЕСТА
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
		
		# Логика галочек для квеста
		var is_boss_done = quest_objectives["defeat_kikimora"] or (current_combat_mode == CombatMode.PEACE)
		text_output += "%s [color=#888888]Победа над Кикиморой[/color]\n" % ("✔" if is_boss_done else "•")
		text_output += "%s Найти Кристалл Яви" % ("✔" if quest_objectives["find_crystal"] else "•")
	
	quest_text.text = text_output

func update_inventory_ui() -> void: 
	if is_instance_valid(inv_slots_text): 
		inv_slots_text.text = "[ Кристалл ]: %d шт." % inventory["crystal"]
	else:
		print("DEBUG: inv_slots_text не найден!")
		
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
	# 1. Создаем CanvasLayer
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "HUDLayer"
	add_child(canvas_layer)
	
	# 2. Основная панель
	status_panel = Panel.new()
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
		bar.show_percentage = false # Отключаем текст процентов, если он не нужен
		
		# Создаем стиль заполнения
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = data[1]
		fill_style.set_corner_radius_all(6) # Удобный метод для скругления всех углов
		bar.add_theme_stylebox_override("fill", fill_style)
		
		# Сохраняем ссылку на стиль маны для будущего доступа
		if data[2] == "mp":
			mp_bar_style = fill_style
		
		# Фон полоски
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		bg_style.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bg_style)
		
		hbox.add_child(bar)
		
		match data[2]:
			"hp": hp_bar = bar
			"mp": mp_bar = bar
			"stamina": stamina_bar = bar
	
	# Уровень
	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(xp_label)
	_apply_label_font(xp_label, 18)
	
	create_styled_skip_button()
	
	# 3. Диалоговая панель
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
	
	# Инициализация текста
	xp_label.text = "Уровень: 1"
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

func create_melee_flash(_pos: Vector2) -> void: pass
func spawn_xp_effect(_pos: Vector2) -> void: pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_world"):
		# Если блокировка активна, просто игнорируем нажатие
		if is_switching: return
		
		get_viewport().set_input_as_handled()
		
		if is_nav_world:
			switch_world(false) # Принудительно в Явь
		else:
			if Global.current_mp >= 20.0:
				switch_world(true) # Принудительно в Навь
			else:
				world_label.text = "Мало маны для Нави!"
			
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
	# 1. Задаем характеристики
	if Global.player_class == "Воин":
		Global.max_hp = 150
		Global.max_mp = 50
		Global.max_stamina = 100
	elif Global.player_class == "Волхв":
		Global.max_hp = 80
		Global.max_mp = 150
		Global.max_stamina = 60
	elif Global.player_class == "Травник":
		Global.max_hp = 110
		Global.max_mp = 100
		Global.max_stamina = 80
	else:
		Global.max_hp = 100
		Global.max_mp = 100
		Global.max_stamina = 90
	
	Global.current_hp = Global.max_hp # Важно: сбрасываем HP до максимума класса
	update_all_ui() # Обновляем бар под новый максимум

func kill_enemy(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy): return
	
	spawn_xp_effect(enemy.global_position)
	
	if enemy.get_meta("id_tag") == "boss":
		# Спавним предмет
		spawn_item(enemy.global_position, "crystal")
		world_label.text = "Кикимора повержена! Забери Кристалл!"
		
		# ПРЯЧЕМ БАР БОССА
		if is_instance_valid(boss_ui_layer):
			boss_ui_layer.visible = false
	
	# Очистка списков
	enemy_list = enemy_list.filter(is_instance_valid)
	level_objects = level_objects.filter(is_instance_valid)
	
	# Удаление врага
	enemy.queue_free()
	
	# Обновление состояния
	update_all_ui()
	update_quest_journal()
	update_world_label_ui()

func spawn_boss_projectile(start_pos: Vector2, target_pos: Vector2) -> void:
	var proj := Area2D.new()
	# Смещаем спавн на 60 пикселей вперед, чтобы снаряд не задевал босса
	var dir = (target_pos - start_pos).normalized()
	proj.position = start_pos + dir * 60.0 
	
	proj.set_meta("owner_id", "boss")
	proj.set_meta("speed", 300.0)
	proj.set_meta("damage", 15.0)
	proj.set_meta("lifetime", 2.0)
	active_projectiles.append(proj)
	
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
			update_all_ui()
			player_anim.modulate = Color(1.0, 0.3, 0.3)
			create_tween().tween_property(player_anim, "modulate", Color(1,1,1), 0.2)
			proj.queue_free()
	)
	add_child(proj)
	active_projectiles.append(proj)
	
func update_all_ui() -> void:
	if is_instance_valid(hp_bar):
		hp_bar.max_value = float(Global.max_hp) # ОБНОВЛЯЕМ МАКСИМУМ
		hp_bar.value = float(Global.current_hp)
		
	if is_instance_valid(mp_bar):
		mp_bar.max_value = float(Global.max_mp)
		mp_bar.value = float(Global.current_mp)
		
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = float(Global.max_stamina)
		stamina_bar.value = float(Global.current_stamina)
		
	# Обновляем уровень и XP
	if is_instance_valid(xp_label):
		# Предполагаем, что у тебя в Global есть переменные player_level, current_xp и xp_to_next_level
		xp_label.text = "Уровень: %d (%d / %d XP)" % [
			Global.player_level, 
			Global.player_xp, 
			Global.xp_to_next_level
		]
		
func _on_projectile_hit(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy.get_meta("hp") <= 0:
		return
		
	# 1. ДОБАВЛЯЕМ ВИЗУАЛЬНЫЙ ЭФФЕКТ ВЗРЫВА
	play_hit_effect(enemy.global_position)
		
	if enemy.get_meta("status") == "aggressive":
		var damage = 35.0
		var enemy_hp = max(0.0, enemy.get_meta("hp") - damage)
		enemy.set_meta("hp", enemy_hp)
		
		# 2. Визуальный отклик (покраснение)
		var espr = enemy.get_node_or_null("AnimatedSprite2D")
		if espr:
			if enemy.has_meta("hit_tween"):
				var old_tween = enemy.get_meta("hit_tween")
				if old_tween and old_tween is Tween and old_tween.is_valid():
					old_tween.kill()
			
			espr.modulate = Color(1.0, 0.3, 0.3)
			var new_tween = create_tween()
			new_tween.tween_property(espr, "modulate", Color(1, 1, 1), 0.3)
			enemy.set_meta("hit_tween", new_tween)
		
		# 3. Обновление UI босса
		if enemy.get_meta("id_tag") == "boss":
			boss_hp_bar.value = enemy_hp
			
		# 4. Проверка смерти
		if enemy_hp <= 0:
			if enemy.has_meta("hit_tween"):
				var final_tween = enemy.get_meta("hit_tween")
				if final_tween and final_tween is Tween and final_tween.is_valid():
					final_tween.kill()
			
			# --- ДОБАВЛЯЕМ ВЫПАДЕНИЕ ХИЛКИ ---
			# Спавним хилку в месте смерти врага
			# Если это босс, можно заспавнить даже несколько!
			if enemy.get_meta("id_tag") == "boss":
				spawn_herb(enemy.global_position + Vector2(150, 0))
				spawn_herb(enemy.global_position + Vector2(-150, 0))
			# ---------------------------------
			
			kill_enemy(enemy)

func spawn_projectile(start_pos: Vector2, dir: Vector2, owner_id: String = "player") -> void:
	var proj = Area2D.new()
	proj.position = start_pos + (dir * 45.0)
	
	# 1. Настройки коллизий
	proj.collision_layer = 0
	proj.collision_mask = 2 
	
	# 2. Создаем коллизию
	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = 15.0
	proj.add_child(col)
	
	# 3. Добавляем в сцену
	add_child(proj)
	
	# 4. Подключаем сигнал
	proj.body_entered.connect(_on_projectile_hit)
	
	# 5. Спрайт
	var spr = Sprite2D.new()
	if ResourceLoader.exists("res://assets/spell.png"):
		spr.texture = load("res://assets/spell.png")
	else:
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.YELLOW)
		spr.texture = ImageTexture.create_from_image(img)
	proj.add_child(spr)
	
	# --- НОВОЕ: ЭФФЕКТ ЧАСТИЦ (ХВОСТ) ---
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.local_coords = false # Чтобы хвост тянулся за снарядом
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.9, 0.5) # Желтоватый оттенок магии
	proj.add_child(particles)
	
	# 6. Параметры
	proj.set_meta("dir", dir)
	proj.set_meta("speed", 600.0)
	proj.set_meta("damage", 30.0)
	proj.set_meta("lifetime", 2.0)
	proj.set_meta("owner_id", owner_id)
	proj.set_meta("spawn_time", Time.get_ticks_msec()) # Для пульсации
	
	# 7. Список активных снарядов
	active_projectiles.append(proj)
	
func open_portal(portal: Area2D) -> void:
	# 1. Защита от повторного запуска
	if portal.get_meta("is_open"): return
	portal.set_meta("is_open", true)
	
	# 2. Активация коллизии и видимости
	portal.visible = true
	portal.set_deferred("monitoring", true)
	portal.set_deferred("monitorable", true)
	# Начинаем с полной прозрачности всего Area2D
	portal.modulate.a = 0.0 
	
	# 3. Активация света
	var light = portal.get_node_or_null("PointLight2D")
	if is_instance_valid(light):
		light.enabled = true    
		light.energy = 0.0      # Начинаем с 0 энергии
	
	var spr = portal.get_node_or_null("Sprite2D")
	
	# 4. Создание твинов для плавного появления
	var t = create_tween().set_parallel(true)
	
	# Плавное появление всего Area2D (от 0 до 1 прозрачности)
	t.tween_property(portal, "modulate:a", 1.0, 1.5)
	
	# Анимация спрайта (МЫ УБРАЛИ "ПЕРЕСВЕТ")
	if is_instance_valid(spr):
		# Спрайт больше не будет пересвечен. Просто плавно проявляется.
		spr.scale = Vector2(0.5, 0.5)
		# Анимируем только масштаб для эффекта "развертывания"
		t.tween_property(spr, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_BACK)
		# Если ты хочешь, чтобы он сам по себе не моргал, 
		# убедись, что spr.modulate.a в spawn_portal стоит в 1.0.
	
	# Анимация света (ВОТ ТУТ МЫ СТАВИМ МОЩНУЮ АУРУ)
	if is_instance_valid(light):
		t.tween_property(light, "energy", 4.0, 1.5).set_trans(Tween.TRANS_CUBIC)
	
	# 5. Подключение сигнала входа
	if not portal.body_entered.is_connected(_on_portal_body_entered):
		# См. Вариант 1 выше, если твоя функция требует target
		portal.body_entered.connect(func(body): _on_portal_body_entered(body, portal))
	
func check_and_open_portal() -> void:
	# Оставляем только самое важное, без лишнего спама
	for obj in level_objects:
		if not is_instance_valid(obj) or not obj.has_meta("type"): continue
		
		if obj.get_meta("type") == "portal" and not obj.get_meta("is_open"):
			var should_open = false
			
			if current_location_name == "Окраина Чернолесья":
				if tutorial_steps_done.move and tutorial_steps_done.roll and tutorial_steps_done.nav:
					should_open = true
			elif current_location_name == "Древнее Капище":
				if inventory.get("crystal", 0) > 0:
					should_open = true
			
			if should_open:
				open_portal(obj)
		
	if current_location_name == "Древнее Капище":
		# Проверяем, есть ли кристалл
		if inventory.get("crystal", 0) > 0:
			# Проверяем, не создан ли уже портал (чтобы не спавнить их пачками)
			var portal_exists = false
			for obj in level_objects:
				if is_instance_valid(obj) and obj.has_meta("type") and obj.get_meta("type") == "portal":
					portal_exists = true
					break
			
			if not portal_exists:
				print("Кристалл найден! Создаю портал.")
				var p = spawn_portal(Vector2(2800, 750), "ПОБЕДА")
				# Сразу делаем его активным
				open_portal(p)

# Измени определение функции:
func spawn_crystal_reward(pos: Vector2 = Vector2.ZERO) -> void:
	var final_pos = pos
	if final_pos == Vector2.ZERO:
		for obj in level_objects:
			if is_instance_valid(obj) and obj.has_meta("type") and obj.get_meta("type") == "portal":
				final_pos = obj.global_position
				break
	
	# Теперь вызываем спавн один раз
	spawn_item(final_pos, "crystal")
	
func _process_enemies(delta: float) -> void:
	for enemy in enemy_list:
		if not is_instance_valid(enemy) or enemy.get_meta("status") == "friendly": continue
		
		# УМЕНЬШАЕМ ОБА ТАЙМЕРА
		var att_t = enemy.get_meta("attack_timer")
		var melee_t = enemy.get_meta("melee_timer")
		if att_t > 0: enemy.set_meta("attack_timer", att_t - delta)
		if melee_t > 0: enemy.set_meta("melee_timer", melee_t - delta)
		
		var espr = enemy.get_node_or_null("AnimatedSprite2D")
		var distance = enemy.position.distance_to(player.position)
		var move_dir = (player.position - enemy.position).normalized()
		
		# Анимации
		if espr:
			var target_anim = "idle"
			if distance < 150.0 and att_t > 0.5: target_anim = "attack"
			elif enemy.velocity.length() > 10.0: target_anim = "walk"
			else: target_anim = "idle"
			
			if espr.animation != target_anim:
				if espr.sprite_frames.has_animation(target_anim):
					espr.play(target_anim)
		
		# --- ЛОГИКА АТАК ---
		# 1. Снарядная атака (босс)
		if enemy.get_meta("id_tag") == "boss" and distance < 600.0 and distance > 150.0:
			if att_t <= 0:
				var dir_to_player = (player.position - enemy.position).normalized()
				spawn_projectile(enemy.position + dir_to_player * 40.0, dir_to_player, "boss")
				enemy.set_meta("attack_timer", 2.0)
			enemy.velocity = Vector2.ZERO
		
		# 2. Контактный урон (ближний бой)
		elif distance < 120.0 and not is_rolling:
			if melee_t <= 0:
				Global.current_hp -= 25.0 * Global.enemy_damage_mod
				enemy.set_meta("melee_timer", 1.5)
				update_all_ui()
				# Эффект удара
				player_anim.modulate = Color(1.0, 0.3, 0.3)
				var tween = create_tween()
				tween.tween_property(player_anim, "modulate", Color(1, 1, 1), 0.2)
			enemy.velocity = Vector2.ZERO
		
		# 3. Ходьба к игроку
		else:
			enemy.velocity = move_dir * 110.0 * Global.enemy_speed_mod
			enemy.move_and_slide()
		
		# Поворот спрайта
		if espr and move_dir.x != 0: espr.flip_h = (move_dir.x < 0)
			
		# Получение урона (от игрока)
		if distance < 110.0 and not is_rolling and att_t <= 0:
			Global.current_hp -= 25.0 * Global.enemy_damage_mod
			enemy.set_meta("attack_timer", 1.4)
			update_all_ui()
			if is_instance_valid(player_anim):
				player_anim.modulate = Color(1.0, 0.3, 0.3)
				var tween = create_tween()
				tween.tween_property(player_anim, "modulate", Color(1, 1, 1), 0.2)
func play_hit_effect(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 15
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(1.0, 0.8, 0.2) # Желто-оранжевый "взрыв"
	add_child(p)
	# Удаляем частицы автоматически после завершения анимации
	await p.finished
	p.queue_free()
	
func spawn_herb(pos: Vector2) -> void:
	var herb := Area2D.new()
	herb.position = pos
	herb.set_meta("is_herb", true)
	
	var spr := Sprite2D.new()
	# Убедись, что путь верный
	if ResourceLoader.exists("res://assets/herb.png"):
		spr.texture = load("res://assets/herb.png")
	else:
		# Временная заглушка, если картинка пока не подгрузилась
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color.GREEN)
		spr.texture = ImageTexture.create_from_image(img)
		
	spr.scale = Vector2(2, 2) # Немного увеличим для заметности
	herb.add_child(spr)
	
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 30.0
	herb.add_child(shape)
	
	herb.body_entered.connect(func(body):
		if body == player:
			Global.current_hp = min(Global.current_hp + 50.0, 100.0)
			update_all_ui()
			world_label.text = "Ты отведал целебных трав."
			herb.queue_free()
	)
	
	add_child(herb)
	level_objects.append(herb)
	
func cleanup_level_objects() -> void:
	# Удаляет из списка все ссылки, которые ведут в никуда
	level_objects = level_objects.filter(is_instance_valid)
	
func scatter_herbs(count: int) -> void:
	for i in range(count):
		var rx = randf_range(100, map_width - 100)
		var ry = randf_range(500, map_height - 200)
		
		# ПРОВЕРКА: если позиция слишком близко к центру арены (где босс),
		# либо к координатам портала — не спавним там траву.
		if Vector2(rx, ry).distance_to(Vector2(960, 540)) < 200:
			continue # Пропускаем этот круг
			
		spawn_herb(Vector2(rx, ry))
		
func _on_skip_tutorial_pressed() -> void:
	# 1. ЗАЩИТА: поглощаем событие, чтобы мир не "увидел" клик как атаку
	get_viewport().set_input_as_handled()
	
	# 2. Очистка "зависших" снарядов перед переходом
	for proj in active_projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	active_projectiles.clear()
	
	# 3. Состояние обучения
	tutorial_steps_done = {"move": true, "roll": true, "nav": true}
	
	# 4. Переход
	load_location("Древнее Капище")
	
	# 5. Убираем кнопку
	remove_tutorial_button()
	
func remove_tutorial_button() -> void:
	var btn = get_node_or_null("HUDLayer/SkipTutorialButton")
	if is_instance_valid(btn):
		btn.queue_free()
		
func create_styled_skip_button() -> void:
	var skip_tutorial_btn = Button.new()
	skip_tutorial_btn.name = "SkipTutorialButton"
	skip_tutorial_btn.text = "ПРОПУСТИТЬ ОБУЧЕНИЕ"
	skip_tutorial_btn.size = Vector2(440, 50)
	skip_tutorial_btn.position = Vector2(740, 50)
	
	# --- Стилизация ---
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.12, 0.11) # Темно-коричневый
	style_normal.border_width_bottom = 4
	style_normal.border_color = Color(0.58, 0.42, 0.25) # "Золотистая" кайма
	style_normal.corner_radius_top_left = 6; style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6; style_normal.corner_radius_bottom_left = 6
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.26, 0.18, 0.16) # Чуть светлее при наведении
	style_hover.border_color = Color(0.95, 0.75, 0.3) # Яркое золото при наведении
	
	skip_tutorial_btn.add_theme_stylebox_override("normal", style_normal)
	skip_tutorial_btn.add_theme_stylebox_override("hover", style_hover)
	
	# --- Шрифт ---
	var font_res = load("res://assets/fonts/main_font.otf") if ResourceLoader.exists("res://assets/fonts/main_font.otf") else null
	if font_res:
		skip_tutorial_btn.add_theme_font_override("font", font_res)
		skip_tutorial_btn.add_theme_font_size_override("font_size", 18)
	
	# --- Цвета текста ---
	skip_tutorial_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	skip_tutorial_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
	
	# --- Логика ---
	skip_tutorial_btn.pressed.connect(_on_skip_tutorial_pressed)
	$HUDLayer.add_child(skip_tutorial_btn)
	
func spawn_mist_layer() -> void:
	# Создаем CanvasLayer с низким слоем, чтобы он был ПОД UI
	var canvas = CanvasLayer.new()
	canvas.layer = 1 # Отрисовывается сразу над фоном, но под всеми остальными UI элементами
	add_child(canvas)
	
	var mist = CPUParticles2D.new()
	mist.position = Vector2(960, 800) 
	mist.material = CanvasItemMaterial.new()
	mist.material.light_mode = CanvasItemMaterial.LIGHT_MODE_NORMAL
	
	mist.amount = 40
	mist.lifetime = 25.0 
	mist.preprocess = 20.0
	
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(1200, 100) 
	
	mist.gravity = Vector2.ZERO 
	mist.initial_velocity_min = 20.0
	mist.initial_velocity_max = 40.0
	mist.direction = Vector2(1, 0)
	mist.spread = 0.0
	
	var cloud_tex_path = "res://assets/mist.png"
	if ResourceLoader.exists(cloud_tex_path): mist.texture = load(cloud_tex_path)
	else: mist.texture = load("res://icon.svg")
	
	mist.scale_amount_min = 3.0
	mist.scale_amount_max = 6.0
	
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(1, 1, 1, 0))
	color_ramp.set_color(0.2, Color(1, 1, 1, 0.15))
	color_ramp.set_color(0.8, Color(1, 1, 1, 0.15))
	color_ramp.set_color(1, Color(1, 1, 1, 0))
	mist.color_ramp = color_ramp
	
	canvas.add_child(mist)
	
func setup_post_processing() -> void:
	# 1. Туман (обычный узел)
	spawn_mist_layer()
	
	# 2. Окружение
	var env = WorldEnvironment.new()
	var config = Environment.new()
	
	config.background_mode = Environment.BG_CANVAS
	
	# Настройка свечения
	config.glow_enabled = true
	# В Godot 4 уровни свечения устанавливаются методами:
	config.set_glow_level(1, 0.5)
	config.set_glow_level(2, 0.5)
	config.set_glow_level(3, 0.5) # Можно добавить и 3-й уровень для мягкости
	
	config.glow_intensity = 0.8
	config.glow_strength = 1.0
	config.glow_bloom = 0.1
	config.glow_hdr_threshold = 0.9 
	
	# Коррекция цвета
	config.adjustment_enabled = true
	config.adjustment_contrast = 1.1
	config.adjustment_saturation = 1.05
	
	env.environment = config
	add_child(env)
