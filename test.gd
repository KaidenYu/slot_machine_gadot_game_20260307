extends Control

@onready var reel_container = $ReelContainer
@onready var spin_button = $SpinButton

# 💰 經濟系統 UI 節點
@onready var gold_label = $GoldPanel/HBoxContainer/GoldLabel
@onready var gold_panel = $GoldPanel
@onready var bet_label = $BetPanel/HBoxContainer/BetLabel
@onready var bet_panel = $BetPanel
@onready var plus_button = $PlusButton
@onready var minus_button = $MinusButton

# ⚔️ 戰鬥系統 UI 節點
@onready var player_hp_bar = $Player/HealthBar
@onready var enemy_hp_bar = $Enemy/HealthBar
@onready var player_sprite = $Player/Sprite
@onready var enemy_sprite = $Enemy/Sprite
@onready var enemy_node = $Enemy
@onready var player_hp_label = $Player/HealthBar/HPLabel
@onready var enemy_hp_label = $Enemy/HealthBar/HPLabel
@onready var heal_button = $Player/HealButton
@onready var level_label = $Player/LevelLabel
@onready var mute_button = $MuteButton

var player_effect_tween: Tween
var enemy_effect_tween: Tween

var audio_players = {}
var is_muted = false

var current_gold = 1000
var displayed_gold = 1000 # 用於動畫顯示的金幣數
var current_bet = 10
var last_bet = 10 # 用於偵測下注變動

var player_level = 1
var player_current_exp = 0
var player_next_level_exp = 100

var player_max_hp = 100
var player_current_hp = 100
var player_str = 15 # 新增：主角基礎力量 (隨等級提升)
var enemy_max_hp = 500
var enemy_current_hp = 500
var is_in_battle = false
var just_encountered = false

var enemies_data = [
	{"name": "哥布林 (Goblin)", "texture": preload("res://assets/goblin.png"), "max_hp": 150, "str": 10, "weight": 40},
	{"name": "幽靈 (Ghost)", "texture": preload("res://assets/ghost.png"), "max_hp": 200, "str": 15, "weight": 25},
	{"name": "半獸人 (Orc)", "texture": preload("res://assets/orc.png"), "max_hp": 350, "str": 20, "weight": 20},
	{"name": "石巨人 (Golem)", "texture": preload("res://assets/golem.png"), "max_hp": 800, "str": 25, "weight": 10},
	{"name": "惡龍 (Dragon)", "texture": preload("res://assets/dragon.png"), "max_hp": 600, "str": 50, "weight": 5}
]

var symbols_data = {
	"Cherry": {"weight": 40, "texture": preload("res://assets/cherry.png"), "payout_multiplier": 2},
	"Lemon": {"weight": 30, "texture": preload("res://assets/lemon.png"), "payout_multiplier": 3},
	"Bar": {"weight": 15, "texture": preload("res://assets/bar.png"), "payout_multiplier": 5},
	"Seven": {"weight": 10, "texture": preload("res://assets/seven.png"), "payout_multiplier": 10},
	"Diamond": {"weight": 5, "texture": preload("res://assets/diamond.png"), "payout_multiplier": 50}
}

var reels = []
var is_spinning = false
var is_encountering_transition = false # 新增：正在處理敵人遭遇動畫的標記
var icon_height = 104
var current_board = []
var current_enemy_name = ""
var current_enemy_str = 10
var current_enemy_exp_reward = 0 # 新增：當前敵人的經驗值獎勵

func _ready() -> void:
	randomize()
	setup_reels()
	setup_audio()
	
	spin_button.pressed.connect(spin_reels)
	plus_button.pressed.connect(increase_bet)
	minus_button.pressed.connect(decrease_bet)
	heal_button.pressed.connect(heal_player)
	mute_button.pressed.connect(toggle_mute)
	
	update_ui()
	init_battle_system()
	
	# 🌟 強行設定縮放中心點為圖片中心，避免被 Container 重置
	player_sprite.pivot_offset = Vector2(75, 75)
	enemy_sprite.pivot_offset = Vector2(75, 75)
	
	enemy_node.visible = false
	is_in_battle = false

func setup_audio():
	var sound_files = {
		"spin": "res://assets/spin.wav",
		"win": "res://assets/win.wav",
		"attack": "res://assets/attack.wav",
		"heal": "res://assets/heal.wav",
		"level_up": "res://assets/levelup.wav",
		"encounter": "res://assets/encounter.wav",
		"defeat": "res://assets/defeat.wav"
	}
	
	var sound_volumes = {
		"spin": - 15.0,
		"win": - 15.0,
		"attack": - 15.0,
		"heal": - 15.0,
		"level_up": - 15.0,
		"encounter": - 10.0,
		"defeat": - 10.0
	}
	
	for sound_name in sound_files.keys():
		var player = AudioStreamPlayer.new()
		if ResourceLoader.exists(sound_files[sound_name]):
			player.stream = load(sound_files[sound_name])
			if sound_volumes.has(sound_name):
				player.volume_db = sound_volumes[sound_name]
		else:
			print("⚠️ 找不到音效檔案：", sound_files[sound_name], " (將會靜音處理)")
			
		add_child(player)
		audio_players[sound_name] = player

# 🌟 🌟 🌟 修改：透過 AudioServer 控制總音量 🌟 🌟 🌟
func toggle_mute():
	is_muted = !is_muted
	
	# 取得 Godot 的 "Master" (主音軌) 索引號碼
	var master_bus_index = AudioServer.get_bus_index("Master")
	
	# 直接把整個遊戲的主音軌設定為靜音 (或解除靜音)
	AudioServer.set_bus_mute(master_bus_index, is_muted)
	
	if is_muted:
		mute_button.text = "🔇 Sound OFF"
	else:
		mute_button.text = "🔊 Sound ON"

func play_sound(sound_name: String):
	# 🌟 移除了這裡的 if is_muted: return，讓音效可以照常「無聲播放」
	if audio_players.has(sound_name) and audio_players[sound_name].stream != null:
		audio_players[sound_name].play()

func stop_sound(sound_name: String):
	if audio_players.has(sound_name) and audio_players[sound_name].playing:
		audio_players[sound_name].stop()

func update_ui():
	# 🏆 處理金幣顯示與動畫
	if int(displayed_gold) != current_gold:
		# 金幣滾動動畫
		var gold_tween = create_tween()
		gold_tween.tween_method(func(v):
			displayed_gold = v
			gold_label.text = str(int(displayed_gold))
		, displayed_gold, current_gold, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		# 金幣標籤彈跳 (只在金幣真的變動時)
		var gold_pop = create_tween()
		gold_pop.tween_property(gold_panel, "scale", Vector2(1.1, 1.1), 0.05)
		gold_pop.tween_property(gold_panel, "scale", Vector2(1.0, 1.0), 0.05)
	else:
		gold_label.text = str(current_gold)

	# ⚔️ 處理下注顯示與動畫
	bet_label.text = str(current_bet)
	if current_bet != last_bet:
		# 下注標籤彈跳 (只在按 +/- 時)
		var bet_pop = create_tween()
		bet_pop.tween_property(bet_panel, "scale", Vector2(1.2, 1.2), 0.1)
		bet_pop.tween_property(bet_panel, "scale", Vector2(1.0, 1.0), 0.1)
		last_bet = current_bet

	level_label.text = "Lv: " + str(player_level) + "\nEXP: " + str(player_current_exp) + " / " + str(player_next_level_exp)
	update_hp_display()

func update_hp_display():
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_current_hp
	player_hp_label.text = str(player_current_hp) + " / " + str(player_max_hp)
	
	if enemy_node.visible:
		enemy_hp_bar.max_value = enemy_max_hp
		enemy_hp_bar.value = enemy_current_hp
		enemy_hp_label.text = str(enemy_current_hp) + " / " + str(enemy_max_hp)

func increase_bet():
	if is_spinning: return
	current_bet += 10
	if current_bet > current_gold:
		current_bet = current_gold
	update_ui()

func decrease_bet():
	if is_spinning: return
	current_bet -= 10
	if current_bet < 10:
		current_bet = 10
	update_ui()

func heal_player():
	if player_current_hp <= 0: return
	if player_current_hp >= player_max_hp: return
	if current_gold < 50: return
		
	current_gold -= 50
	player_current_hp += 10
	if player_current_hp > player_max_hp:
		player_current_hp = player_max_hp
		
	update_ui()
	play_heal_effect(player_sprite)
	play_sound("heal")

func init_battle_system():
	update_hp_display()

func setup_reels():
	for control_node in reel_container.get_children():
		var scroll_vbox = VBoxContainer.new()
		scroll_vbox.add_theme_constant_override("separation", 4)
		control_node.add_child(scroll_vbox)
		reels.append(scroll_vbox)
		
		for i in range(25):
			var icon = TextureRect.new()
			icon.texture = symbols_data[get_random_symbol()]["texture"]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(100, 100)
			icon.pivot_offset = Vector2(50, 50)
			icon.modulate = Color(0.8, 0.8, 0.8) # Darken the icons
			scroll_vbox.add_child(icon)
			
		scroll_vbox.position.y = - (22 * icon_height)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		spin_reels()

func spin_reels():
	if is_spinning or is_encountering_transition or player_current_hp <= 0: return
	if current_gold < current_bet: return
		
	is_spinning = true
	current_gold -= current_bet
	update_ui()
	just_encountered = false
	
	play_sound("spin")
	
	current_board.clear()
	for i in range(5):
		var column = []
		for j in range(3):
			column.append(get_random_symbol())
		current_board.append(column)
	
	for i in range(reels.size()):
		var scroll_vbox = reels[i]
		for j in range(25):
			if j >= 22:
				var symbol_name = current_board[i][j - 22]
				scroll_vbox.get_child(j).texture = symbols_data[symbol_name]["texture"]
				scroll_vbox.get_child(j).rotation_degrees = 0
				scroll_vbox.get_child(j).modulate = Color(0.8, 0.8, 0.8)
			else:
				var random_symbol = get_random_symbol()
				scroll_vbox.get_child(j).texture = symbols_data[random_symbol]["texture"]
				scroll_vbox.get_child(j).modulate = Color(0.8, 0.8, 0.8)
			
		scroll_vbox.position.y = 0
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var target_y = - (22 * icon_height)
		var spin_duration = 1.5 + (i * 0.3)
		tween.tween_property(scroll_vbox, "position:y", target_y, spin_duration)
		
		if i == reels.size() - 1:
			tween.finished.connect(func():
				stop_sound("spin")
				check_win()
			)

func start_encounter():
	is_encountering_transition = true
	is_in_battle = true
	play_sound("encounter")
	await get_tree().create_timer(0.5).timeout
	
	# 🎲 權重系統：根據 weight 決定遇到哪個敵人
	var total_weight = 0
	for enemy in enemies_data:
		total_weight += enemy["weight"]
		
	var random_val = randi() % total_weight
	var current_sum = 0
	var selected_enemy = enemies_data[0] # 預設
	
	for enemy in enemies_data:
		current_sum += enemy["weight"]
		if random_val < current_sum:
			selected_enemy = enemy
			break
	
	current_enemy_name = selected_enemy["name"]
	
	if enemy_effect_tween and enemy_effect_tween.is_valid():
		enemy_effect_tween.kill()
	
	enemy_sprite.modulate = Color.WHITE
	enemy_hp_bar.modulate.a = 1.0
	
	enemy_sprite.texture = selected_enemy["texture"]
	enemy_max_hp = selected_enemy["max_hp"]
	enemy_current_hp = enemy_max_hp
	current_enemy_str = selected_enemy["str"] 
	current_enemy_exp_reward = selected_enemy["max_hp"] # 使用 HP 作為經驗值獎勵
	
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_current_hp
	
	enemy_node.visible = true
	update_hp_display()
	
	enemy_sprite.modulate.a = 0.0
	enemy_hp_bar.modulate.a = 0.0
	enemy_effect_tween = create_tween().set_parallel(true)
	enemy_effect_tween.tween_property(enemy_sprite, "modulate:a", 1.0, 1.5)
	enemy_effect_tween.tween_property(enemy_hp_bar, "modulate:a", 1.0, 1.5)
	
	# ⏳ 等待敵人出現動畫結束後，才允許再次按 Spin
	await enemy_effect_tween.finished
	is_encountering_transition = false

func enemy_attack():
	# 🍖 根據當前敵人的 STR 浮動攻擊力 (±20% 隨機性)
	var min_dmg = int(current_enemy_str * 0.8)
	var max_dmg = int(current_enemy_str * 1.2)
	var damage = randi_range(min_dmg, max_dmg)
	
	player_current_hp -= damage
	if player_current_hp < 0: player_current_hp = 0
		
	update_hp_display()
	play_character_damage_effect(player_sprite)
	play_floating_text(player_sprite, "-" + str(damage))
	play_sound("attack")
	
	if player_current_hp == 0:
		play_character_death_effect(player_sprite, player_hp_bar)

func player_attack(base_damage: int):
	# 🍖 增加主角攻擊隨機性 (±20% 浮動)
	var min_dmg = int(base_damage * 0.8)
	var max_dmg = int(base_damage * 1.2)
	var damage = randi_range(min_dmg, max_dmg)
	
	enemy_current_hp -= damage
	if enemy_current_hp < 0: enemy_current_hp = 0
		
	update_hp_display()
	play_character_damage_effect(enemy_sprite)
	play_floating_text(enemy_sprite, "-" + str(damage))
	play_sound("attack")
	
	if enemy_current_hp == 0:
		is_in_battle = false
		var death_tween = play_character_death_effect(enemy_sprite, enemy_hp_bar)
		play_sound("defeat")
		# ⏳ 等待敵人死亡動畫 (1.5s) 結束後再多等 0.5s 才拿 EXP
		if death_tween:
			await death_tween.finished
		await get_tree().create_timer(0.5).timeout
		gain_exp(current_enemy_exp_reward) 

func gain_exp(amount: int):
	player_current_exp += amount
	var leveled_up = false
	
	while player_current_exp >= player_next_level_exp:
		player_current_exp -= player_next_level_exp
		player_level += 1
		player_next_level_exp = int(player_next_level_exp * 1.5)
		
		player_max_hp += 20
		player_current_hp = player_max_hp
		player_str += 5 # 升級時增加基礎攻擊力
		
		leveled_up = true

	update_ui()
	if leveled_up:
		play_level_up_effect()

func check_win():
	var total_win = 0
	var winning_nodes = []
	var was_in_battle = is_in_battle
	
	for x in range(5):
		var s1 = current_board[x][0]
		var s2 = current_board[x][1]
		var s3 = current_board[x][2]
		
		if s1 == s2 and s2 == s3:
			total_win += current_bet * symbols_data[s1]["payout_multiplier"]
			winning_nodes.append(reels[x].get_child(22))
			winning_nodes.append(reels[x].get_child(23))
			winning_nodes.append(reels[x].get_child(24))
			
	for y in range(3):
		var current_symbol = current_board[0][y]
		var match_count = 1
		var current_line_nodes = [reels[0].get_child(22 + y)]
		
		for x in range(1, 5):
			if current_board[x][y] == current_symbol:
				match_count += 1
				current_line_nodes.append(reels[x].get_child(22 + y))
			else:
				if match_count >= 3:
					winning_nodes.append_array(current_line_nodes)
					total_win += calculate_line_win(current_symbol, match_count)
				current_symbol = current_board[x][y]
				match_count = 1
				current_line_nodes = [reels[x].get_child(22 + y)]
				
		if match_count >= 3:
			winning_nodes.append_array(current_line_nodes)
			total_win += calculate_line_win(current_symbol, match_count)

	if total_win > 0:
		current_gold += total_win
		update_ui()
		play_sound("win")
		
		var unique_winning_nodes = []
		for node in winning_nodes:
			if not node in unique_winning_nodes:
				unique_winning_nodes.append(node)
		
		play_win_effects(unique_winning_nodes)
	
	# 主角在戰鬥中每一輪都會反擊
	if is_in_battle and not just_encountered:
		# 傷害 = 主角力量 + 贏得的金幣
		var total_damage = player_str + total_win
		player_attack(total_damage)
		# ⏳ 等待主角攻擊動作結束
		await get_tree().create_timer(0.6).timeout
	
	if not was_in_battle:
		if randf() <= 0.25:
			start_encounter()
			just_encountered = true
	else:
		if is_in_battle and not just_encountered:
			if enemy_current_hp > 0: # 確保敵人被打死後不會反擊
				enemy_attack()
				# ⏳ 等待敵人攻擊動畫結束 (數字漂浮與紅閃約 0.6s)
				await get_tree().create_timer(0.6).timeout
	
	# 🏁 所有結算(中獎、戰鬥、反擊)完成，解鎖 Spin
	is_spinning = false

func calculate_line_win(symbol: String, count: int) -> int:
	var base_win = current_bet * symbols_data[symbol]["payout_multiplier"]
	if count == 4: return base_win * 2
	elif count == 5: return base_win * 5
	else: return base_win

func play_win_effects(nodes: Array):
	for icon_node in nodes:
		if not icon_node is TextureRect: continue
		var shake_tween = create_tween()
		var flash_tween = create_tween()
		for i in range(5):
			shake_tween.tween_property(icon_node, "rotation_degrees", -10, 0.02)
			shake_tween.tween_property(icon_node, "rotation_degrees", 10, 0.02)
		shake_tween.tween_property(icon_node, "rotation_degrees", 0, 0.02)
		
		for i in range(3):
			flash_tween.tween_property(icon_node, "modulate", Color(2, 0, 0, 1), 0.06)
			flash_tween.tween_property(icon_node, "modulate", Color.WHITE, 0.06)
		flash_tween.tween_property(icon_node, "modulate", Color(0.8, 0.8, 0.8), 0.06)

func play_character_damage_effect(sprite: TextureRect):
	if not sprite: return
	var tween = create_tween()
	
	if sprite == player_sprite:
		if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
		player_effect_tween = tween
	else:
		if enemy_effect_tween and enemy_effect_tween.is_valid(): enemy_effect_tween.kill()
		enemy_effect_tween = tween
		
	tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func play_character_death_effect(sprite: TextureRect, hp_bar: ProgressBar) -> Tween:
	var tween = create_tween().set_parallel(true)
	
	if sprite == player_sprite:
		if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
		player_effect_tween = tween
	else:
		if enemy_effect_tween and enemy_effect_tween.is_valid(): enemy_effect_tween.kill()
		enemy_effect_tween = tween
		
	if sprite: tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	if hp_bar: tween.tween_property(hp_bar, "modulate:a", 0.0, 1.5)
	
	return tween

func play_heal_effect(sprite: TextureRect):
	if not sprite: return
	var tween = create_tween()
	
	if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
	player_effect_tween = tween
	
	tween.tween_property(sprite, "modulate", Color(0, 2, 0, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func play_level_up_effect():
	if not player_sprite: return
	var tween = create_tween().set_parallel(true)
	
	if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
	player_effect_tween = tween
	
	tween.tween_property(player_sprite, "modulate", Color(2, 2, 0, 1), 0.2)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.5).set_delay(0.2)
	tween.tween_property(player_sprite, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(player_sprite, "scale", Vector2(1.0, 1.0), 0.5).set_delay(0.2).set_trans(Tween.TRANS_BOUNCE)
	
	play_sound("level_up")

func play_floating_text(target_sprite: TextureRect, text: String):
	if not target_sprite: return
	
	var label = Label.new()
	label.text = text
	
	label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 28)
	
	target_sprite.add_child(label)
	label.position = Vector2(target_sprite.size.x / 2 - 60, 20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func get_random_symbol() -> String:
	var total_weight = 0
	for data in symbols_data.values():
		total_weight += data["weight"]
	var random_value = randi() % total_weight
	var current_weight = 0
	for symbol in symbols_data.keys():
		current_weight += symbols_data[symbol]["weight"]
		if random_value < current_weight:
			return symbol
	return ""