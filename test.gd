extends Control

const SaveLoad = preload("res://save_load.gd")


@onready var reel_container = $ReelContainer
@onready var spin_button = $SpinButton

# 💰 經濟系統 UI 節點
@onready var gold_label = $GoldPanel/HBoxContainer/GoldLabel
@onready var gold_panel = $GoldPanel
@onready var bet_label = $BetPanel/HBoxContainer/BetLabel
@onready var bet_panel = $BetPanel
@onready var plus_button = $PlusButton
@onready var minus_button = $MinusButton
@onready var coin_icon = $GoldPanel/HBoxContainer/CoinIcon

# ⚔️ 戰鬥系統 UI 節點
@onready var player_hp_bar = $Player/HealthBar
@onready var enemy_hp_bar = $Enemy/HealthBar
@onready var player_sprite = $Player/Sprite
@onready var enemy_sprite = $Enemy/Sprite
@onready var enemy_node = $Enemy
@onready var player_hp_label = $Player/HealthBar/HPLabel
@onready var enemy_hp_label = $Enemy/HealthBar/HPLabel
@onready var heal_button = $Player/HBoxContainer/PotionFrame/HealButton
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

# 🕒 離線收益系統設定
var offline_income_gold_per_sec = 0.2 # 每 5 秒基礎收益 (0.2 gold/sec)
var offline_income_max_seconds = 86400 # 最大累計時間 (24小時)

var enemies_data = [
	{"name": "哥布林 (Goblin)", "texture": preload("res://assets/goblin.png"), "max_hp": 150, "str": 10, "weight": 40},
	{"name": "幽靈 (Ghost)", "texture": preload("res://assets/ghost.png"), "max_hp": 200, "str": 15, "weight": 25},
	{"name": "半獸人 (Orc)", "texture": preload("res://assets/orc.png"), "max_hp": 350, "str": 20, "weight": 20},
	{"name": "石巨人 (Golem)", "texture": preload("res://assets/golem.png"), "max_hp": 800, "str": 25, "weight": 10},
	{"name": "惡龍 (Dragon)", "texture": preload("res://assets/dragon.png"), "max_hp": 600, "str": 50, "weight": 5}
]

# 🕒 離線收益計算邏輯
func calculate_offline_income(last_save_time: float):
	var current_time = Time.get_unix_time_from_system()
	var elapsed_seconds = current_time - last_save_time
	
	if elapsed_seconds <= 0:
		return
	
	if elapsed_seconds > offline_income_max_seconds:
		elapsed_seconds = offline_income_max_seconds
	
	# 收益公式：每秒 1 金幣
	var earned_gold = int(elapsed_seconds * offline_income_gold_per_sec)
	
	if earned_gold > 0:
		current_gold += earned_gold
		# 顯示收益視窗
		show_offline_income_popup(elapsed_seconds, earned_gold)

	# 🕒 顯示離線收益彈窗
func show_offline_income_popup(seconds: float, gold: int):
	# 計算離線的小時、分鐘、秒
	var hrs = int(seconds / 3600.0)
	var mins = int((int(seconds) % 3600) / 60.0)
	var secs = int(int(seconds) % 60)
	var time_str = ""
	
	if hrs > 0:
		time_str += str(hrs) + "h "
	if mins > 0:
		time_str += str(mins) + "m "
	if secs > 0 or time_str == "":
		time_str += str(secs) + "s"
	
	# 🏗️ 建立最高層級容器 (CanvasLayer)
	# 這能確保遮罩蓋住所有遊戲中的 UI 元件 (包含 Reset 按鈕)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 100 # 設定一個很高的數字，確保在最頂層
	add_child(ui_layer)
	
	# 🌑 建立黑色半透明遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(overlay) # 👈 加入層級中
	
	# 🎨 建立自定義彈窗容器 (PanelContainer)
	var popup_card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2, 0.5) 
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	style.content_margin_bottom = 20
	style.content_margin_top = 15
	popup_card.add_theme_stylebox_override("panel", style)
	
	ui_layer.add_child(popup_card)
	popup_card.custom_minimum_size = Vector2(400, 250)
	
	# 🎯 參考 SlotMachineFrame 設定方法：使用絕對像素位置 (Top-Left 模式)
	popup_card.layout_mode = 0
	popup_card.offset_left = 376
	popup_card.offset_top = 199
	popup_card.offset_right = 776
	popup_card.offset_bottom = 449
	
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	popup_card.add_child(layout)
	
	# 自定義標題
	var title_label = Label.new()
	title_label.text = "OFFLINE REWARDS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2)) # 金色標題
	layout.add_child(title_label)
	
	var info_label = Label.new()
	info_label.text = "Welcome back, Hero!\nWhile you were away (" + time_str + "),\nyour adventure party collected some loot:"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(info_label)
	
	# 💰 金幣獎勵區域
	var reward_hbox = HBoxContainer.new()
	reward_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_hbox.add_theme_constant_override("separation", 15)
	layout.add_child(reward_hbox)
	
	var icon_rect = TextureRect.new()
	icon_rect.texture = preload("res://assets/coin_icon.png")
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(45, 45)
	reward_hbox.add_child(icon_rect)
	
	var reward_label = Label.new()
	reward_label.text = "+" + str(gold) + " Gold"
	reward_label.add_theme_font_size_override("font_size", 36)
	reward_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	reward_hbox.add_child(reward_label)
	
	# 自定義 OK 按鈕
	var ok_btn = Button.new()
	ok_btn.text = " COLLECT "
	ok_btn.custom_minimum_size = Vector2(120, 40)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(ok_btn)
	
	# 按鈕樣式
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.border_width_bottom = 4
	btn_style.border_color = Color(0, 0, 0, 0.3)
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	
	# 點擊按鈕後的邏輯
	ok_btn.pressed.connect(func():
		save_game_data()
		overlay.queue_free()
		popup_card.queue_free()
	)

var player_textures = {
	"low": preload("res://assets/player1.png"),
	"high": preload("res://assets/player2.png")
}

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
	heal_button.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(heal_button, "scale", Vector2(1.1, 1.1), 0.1)
	)
	heal_button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(heal_button, "scale", Vector2(1.0, 1.0), 0.1)
	)
	heal_button.button_down.connect(func():
		if player_current_hp >= player_max_hp or current_gold < 50: return
		var tween = create_tween()
		tween.tween_property(heal_button, "scale", Vector2(0.9, 0.9), 0.05)
	)
	heal_button.button_up.connect(func():
		var tween = create_tween()
		# 放開按鈕時必定回彈至 1.1 (因為滑鼠還在上面)
		tween.tween_property(heal_button, "scale", Vector2(1.1, 1.1), 0.05)
	)

	# 由於 TextureButton 現在是 30x30，Pivot 設為 (15, 15)
	heal_button.pivot_offset = Vector2(15, 15)
	mute_button.pressed.connect(toggle_mute)
	
	update_ui()
	init_battle_system()
	
	enemy_node.visible = false
	is_in_battle = false
	update_player_appearance()

	# 🗑️ 動態產生「清除存檔」按鈕
	create_reset_button()
	
	# 🌟 自動讀取存檔 (移動到最後，確保後產生的 UI 能被 load 階段產生的彈窗覆蓋)
	load_game_data()

func create_reset_button():
	var reset_btn = Button.new()
	reset_btn.name = "ResetButton"
	reset_btn.text = "■ Reset Game"
	
	# 設定位置與大小：使其與 MuteButton 屬性一致
	reset_btn.custom_minimum_size = Vector2(113, 31)
	reset_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT # 靠左對齊
	reset_btn.add_theme_font_size_override("font_size", 14) # 強制大小
	add_child(reset_btn)
	reset_btn.position = Vector2(1026, 573)
	
	# 建立確認視窗
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "DANGER: RESET GAME"
	confirm_dialog.dialog_text = "\nAre you sure you want to PERMANENTLY reset the game?\nThis will clear ALL your progress and gold."
	confirm_dialog.ok_button_text = "YES, RESET EVERYTHING"
	confirm_dialog.cancel_button_text = "No, Keep Playing"
	confirm_dialog.min_size = Vector2(400, 150) # 稍微加大視窗
	add_child(confirm_dialog)
	
	# 🌟 顯眼客製化：修改內部節點樣式
	var dialog_label = confirm_dialog.get_label()
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # 文字置中
	dialog_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # 警示黃色
	dialog_label.add_theme_font_size_override("font_size", 16)
	
	var ok_btn = confirm_dialog.get_ok_button()
	ok_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	ok_btn.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.5)) # 稍微亮一點的紅
	ok_btn.add_theme_color_override("font_focus_color", Color(1, 0.5, 0.5))
	ok_btn.add_theme_color_override("font_pressed_color", Color(0.8, 0, 0))
	
	var cancel_btn = confirm_dialog.get_cancel_button()
	cancel_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	cancel_btn.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.6)) # 稍微亮一點的綠
	cancel_btn.add_theme_color_override("font_focus_color", Color(0.6, 1.0, 0.6))
	cancel_btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.8, 0.2))
	
	# 點擊確認後的邏輯
	confirm_dialog.confirmed.connect(func():
		print("☢️ 確認重置遊戲...")
		SaveLoad.delete_save()
		get_tree().reload_current_scene()
	)
	
	# 點擊按鈕時顯示自定義確認視窗 (改用與收益彈窗相同的設計)
	reset_btn.pressed.connect(func():
		show_custom_reset_dialog()
	)

# 🗑️ 自定義重置確認彈窗 (解決跨平台位置偏移問題)
func show_custom_reset_dialog():
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 101
	add_child(ui_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(overlay)
	
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.2, 0.2, 0.8) # 更亮的紅色邊框
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 25
	style.content_margin_bottom = 25
	style.content_margin_top = 20
	style.content_margin_left = 30
	style.content_margin_right = 30
	card.add_theme_stylebox_override("panel", style)
	
	ui_layer.add_child(card)
	card.custom_minimum_size = Vector2(420, 240)
	card.layout_mode = 0
	card.offset_left = 366
	card.offset_top = 204
	card.offset_right = 786
	card.offset_bottom = 444
	
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 25)
	card.add_child(layout)
	
	var title = Label.new()
	title.text = "DANGER: RESET GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_constant_override("outline_size", 4)
	layout.add_child(title)
	
	var msg = Label.new()
	msg.text = "Are you sure you want to PERMANENTLY\nreset the game? This will clear everything."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 14)
	layout.add_child(msg)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 30)
	layout.add_child(btn_hbox)
	
	# --- 現代扁平外框風 YES 按鈕 (紅色) ---
	var yes_btn = Button.new()
	yes_btn.text = " YES, RESET "
	yes_btn.custom_minimum_size = Vector2(130, 40)
	
	var yes_style = StyleBoxFlat.new()
	yes_style.bg_color = Color(0.4, 0.1, 0.1, 0.7) # 半透明深紅
	yes_style.set_corner_radius_all(5)
	yes_style.set_border_width_all(2)
	yes_style.border_color = Color(1.0, 0.3, 0.3, 0.8) # 明亮紅邊框
	yes_btn.add_theme_stylebox_override("normal", yes_style)
	yes_btn.add_theme_color_override("font_color", Color(1, 0.8, 0.8))
	btn_hbox.add_child(yes_btn)
	
	# --- 現代扁平外框風 NO 按鈕 (綠色) ---
	var no_btn = Button.new()
	no_btn.text = " BACK TO SAFETY "
	no_btn.custom_minimum_size = Vector2(160, 40)
	
	var no_style = StyleBoxFlat.new()
	no_style.bg_color = Color(0.1, 0.3, 0.1, 0.7) # 半透明深綠
	no_style.set_corner_radius_all(5)
	no_style.set_border_width_all(2)
	no_style.border_color = Color(0.3, 1.0, 0.3, 0.8) # 明亮綠邊框
	no_btn.add_theme_stylebox_override("normal", no_style)
	no_btn.add_theme_color_override("font_color", Color(0.8, 1, 0.8))
	btn_hbox.add_child(no_btn)
	
	yes_btn.pressed.connect(func():
		SaveLoad.delete_save()
		get_tree().reload_current_scene()
	)
	
	no_btn.pressed.connect(func():
		ui_layer.queue_free()
	)

func update_player_appearance():
	if player_level > 5:
		player_sprite.texture = player_textures["high"]
	else:
		player_sprite.texture = player_textures["low"]

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
		mute_button.text = "□ Sound OFF"
	else:
		mute_button.text = "■ Sound ON"

# 🪙 金幣飛行特效資源
var coin_texture = preload("res://assets/coin_icon.png")

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
	var max_bet_allowed = player_level * 10
	
	if current_bet >= max_bet_allowed:
		# 💡 達到上限，顯示黃色提示文本
		play_floating_text(plus_button, "MAX!", Color(1, 0.8, 0))
		return
	
	current_bet += 10
	if current_bet > max_bet_allowed:
		current_bet = max_bet_allowed
			
	if current_bet > current_gold:
		current_bet = max(10, int(floor(current_gold / 10.0)) * 10)
		
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
	save_game_data() # 存檔：記錄回血後的狀態與金錢

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
	save_game_data() # 存檔：扣錢後立即存檔，防止刷新大法
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
	play_attack_movement_effect(enemy_sprite, -30) # 敵人往左衝
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
	play_attack_movement_effect(player_sprite, 30) # 主角往右衝
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
		await gain_exp(current_enemy_exp_reward)

func gain_exp(amount: int):
	player_current_exp += amount
	var leveled_up = false
	
	while player_current_exp >= player_next_level_exp:
		player_current_exp = 0
		player_level += 1
		player_next_level_exp = int(player_next_level_exp * 1.5)
		
		player_max_hp += 20
		player_current_hp = player_max_hp
		player_str += 5 # 升級時增加基礎攻擊力
		
		leveled_up = true

	update_ui()
	if leveled_up:
		update_player_appearance()
		await play_level_up_effect()

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
		
		# 🪙 觸發金幣噴發特效：從每個中獎格子飛向左上角
		for node in unique_winning_nodes:
			play_coin_fly_animation(node.global_position + node.size / 2)
	
	# 主角在戰鬥中每一輪都會反擊
	if is_in_battle and not just_encountered:
		# 傷害 = 主角力量 + 贏得的金幣
		var total_damage = player_str + total_win
		await player_attack(total_damage)
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
	
	# 🏁 所有結算(中獎、戰鬥、反擊)完成，解鎖 Spin 並存檔
	is_spinning = false
	save_game_data() # 存檔：完成一輪後的最終結果

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
	var original_pos = sprite.position
	
	# 🔴 閃紅光 (獨立的 Tween)
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", Color(2, 0, 0, 1), 0.1)
	color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# 🫨 抖動 (獨立的序列式 Tween)
	var move_tween = create_tween()
	if sprite == player_sprite:
		if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
		player_effect_tween = move_tween
	else:
		if enemy_effect_tween and enemy_effect_tween.is_valid(): enemy_effect_tween.kill()
		enemy_effect_tween = move_tween
	
	var shake_duration = 0.04
	var offset = 3
	
	# 加入一點點延遲，讓「被打」的感覺在對方衝刺過來時發生
	move_tween.tween_interval(0.05)
	
	for i in range(5):
		move_tween.tween_property(sprite, "position:x", original_pos.x - offset, shake_duration)
		move_tween.tween_property(sprite, "position:x", original_pos.x + offset, shake_duration)
	
	# 最後回到原位
	move_tween.tween_property(sprite, "position:x", original_pos.x, shake_duration)

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
	
	# ⏳ 等待升級音效播放完畢
	if audio_players.has("level_up"):
		await audio_players["level_up"].finished

func play_attack_movement_effect(sprite: TextureRect, offset_x: float):
	if not sprite: return
	var original_pos = sprite.position
	var tween = create_tween()
	
	if sprite == player_sprite:
		if player_effect_tween and player_effect_tween.is_valid(): player_effect_tween.kill()
		player_effect_tween = tween
	else:
		if enemy_effect_tween and enemy_effect_tween.is_valid(): enemy_effect_tween.kill()
		enemy_effect_tween = tween
		
	tween.tween_property(sprite, "position:x", original_pos.x + offset_x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:x", original_pos.x, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func play_floating_text(target: Control, text: String, color: Color = Color(1, 0, 0, 1)):
	if not target: return
	
	var label = Label.new()
	label.text = text
	
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 28)
	
	target.add_child(label)
	label.position = Vector2(target.size.x / 2 - 30, -20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func get_random_symbol() -> String:
	var total_weight = 0
	for data in symbols_data.values():
		total_weight += data["weight"]
	
	if total_weight <= 0: return symbols_data.keys()[0]
	
	var random_value = randi() % total_weight
	var current_weight = 0
	for symbol in symbols_data.keys():
		current_weight += symbols_data[symbol]["weight"]
		if random_value < current_weight:
			return symbol
	
	return symbols_data.keys()[0] # Fallback return to ensure all code paths return a value

# 🪙 核心：金幣飛行特效邏輯
func play_coin_fly_animation(start_pos: Vector2):
	# 🎯 目的地：獲取準確的視覺中心
	var target_center = coin_icon.get_global_rect().get_center()
	var base_size = Vector2(90, 90)
	var end_scale = 0.22
	
	# 每次噴發 5 個代表性金幣
	for i in range(5):
		var coin = TextureRect.new()
		coin.texture = coin_texture
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = base_size
		coin.size = base_size
		coin.pivot_offset = Vector2.ZERO # 👈 關鍵：樞軸設為 0 以避免與 global_position 衝突
		
		add_child(coin)
		# 起始位置：中心對準 start_pos
		coin.global_position = start_pos - (base_size / 2)
		
		var tween = create_tween().set_parallel(true)
		var duration = 0.4 + randf() * 0.2
		var delay = i * 0.05
		
		# 1. 直接飛向目標中心 (計算縮小後的偏移量)
		var final_pos = target_center - (base_size * end_scale / 2)
		tween.tween_property(coin, "global_position", final_pos, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 2. 飛行過程中縮小
		tween.tween_property(coin, "scale", Vector2(end_scale, end_scale), duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# 當抵達目的地
		tween.chain().tween_callback(func():
			coin.queue_free()
			var pop_tween = create_tween()
			pop_tween.tween_property(gold_panel, "scale", Vector2(1.1, 1.1), 0.05)
			pop_tween.tween_property(gold_panel, "scale", Vector2(1.0, 1.0), 0.05)
		)

# 💾 存檔資料整合
func save_game_data():
	var data = {
		"gold": current_gold,
		"level": player_level,
		"exp": player_current_exp,
		"next_level_exp": player_next_level_exp,
		"max_hp": player_max_hp,
		"hp": player_current_hp,
		"str": player_str,
		"last_save_time": Time.get_unix_time_from_system() # 紀錄最後操作時間
	}
	SaveLoad.save_game(data)

# 💾 讀取資料並更新變數
func load_game_data():
	var data = SaveLoad.load_game()
	if data.is_empty(): return
	
	current_gold = data.get("gold", 1000)
	displayed_gold = current_gold # 讓顯示數字同步起始
	player_level = data.get("level", 1)
	player_current_exp = data.get("exp", 0)
	player_next_level_exp = data.get("next_level_exp", 100)
	player_max_hp = data.get("max_hp", 100)
	player_current_hp = data.get("hp", 100)
	player_str = data.get("str", 15)
	
	# 🕒 處理離線收益
	var last_save_time = data.get("last_save_time", 0.0)
	if last_save_time > 0:
		calculate_offline_income(last_save_time)
	
	update_ui()
	update_player_appearance()
	print("存檔載入完成！目前的金幣：", current_gold)
