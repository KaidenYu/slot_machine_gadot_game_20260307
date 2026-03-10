extends Control

@onready var player = $Player
@onready var goblin = $Goblin
@onready var skip_button = $SkipButton

var transitioning = false
var anim_tween: Tween
var move_tween: Tween
var goblin_tween: Tween
var mark_tween: Tween
var skip_tween: Tween
var original_pos_y: float
var player_stopped = false
var goblin_stopped = false
var attack_count = 0
var sfx_attack: AudioStreamPlayer
var sfx_levelup: AudioStreamPlayer
var sfx_step: AudioStreamPlayer

func _ready():
	# 1. 確保 Pivot 在腳底中心
	player.pivot_offset = Vector2(player.size.x / 2, player.size.y)
	
	# 🌟 初始化音效
	sfx_attack = AudioStreamPlayer.new()
	sfx_attack.stream = load("res://assets/attack.wav")
	sfx_attack.volume_db = -10.0
	add_child(sfx_attack)
	
	sfx_levelup = AudioStreamPlayer.new()
	sfx_levelup.stream = load("res://assets/levelup.wav")
	sfx_levelup.volume_db = -5.0
	add_child(sfx_levelup)
	
	sfx_step = AudioStreamPlayer.new()
	sfx_step.stream = load("res://assets/step.wav")
	sfx_step.volume_db = -15.0
	add_child(sfx_step)
	
	# 2. 設定起始位置：放在畫面左側外面
	var target_x = player.position.x
	original_pos_y = player.position.y
	player.position.x = -100 # 足夠遠到螢幕外
	
	# 3. 開始踏步動畫 (無限循環)
	play_walk_animation()
	
	# 4. 開始移動動畫：走入畫面中心
	_enter_scene(target_x)
	
	# 5. 哥布林來回轉身 (設定 10 秒後跟主角一起停止)
	_play_goblin_idle(5.0)
	
	# 6. Skip 提示動畫 (延遲淡入 + 呼吸效果)
	_start_skip_button_animation()
	
	# 🌟 接上按鈕點擊與懸停事件
	skip_button.pressed.connect(_change_scene)
	skip_button.mouse_entered.connect(_on_skip_button_mouse_entered)
	skip_button.mouse_exited.connect(_on_skip_button_mouse_exited)

func _enter_scene(target_x):
	move_tween = create_tween()
	# 花費 5 秒從左邊走到中間
	move_tween.tween_property(player, "position:x", target_x, 5.0).set_trans(Tween.TRANS_LINEAR)
	
	# 當走到中間後，停止走路動畫
	move_tween.finished.connect(_stop_walk_animation)

func _stop_walk_animation():
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	
	# 讓主角恢復站立姿勢 (歸零旋轉與高度)
	var reset_tween = create_tween().set_parallel(true)
	reset_tween.tween_property(player, "rotation_degrees", 0, 0.2)
	reset_tween.tween_property(player, "position:y", original_pos_y, 0.2)
	
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
		
	player_stopped = true
	_check_show_exclamation()

func _check_show_exclamation():
	if player_stopped and goblin_stopped:
		_show_exclamation_mark()

func _show_exclamation_mark():
	var mark = Label.new()
	mark.text = "!!!"
	mark.add_theme_font_size_override("font_size", 60)
	mark.add_theme_color_override("font_color", Color(1, 1, 0)) # 黃色
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mark.add_theme_constant_override("outline_size", 10)
	
	# 放在哥布林上方
	add_child(mark)
	mark.position = goblin.position + Vector2(goblin.size.x / 2 - 20, -100)
	
	# 彈出動畫
	mark.modulate.a = 0
	mark.scale = Vector2(0.5, 0.5)
	mark.pivot_offset = Vector2(25, 40)
	
	mark_tween = create_tween()
	# 階段 1: 彈出
	mark_tween.set_parallel(true)
	mark_tween.tween_property(mark, "modulate:a", 1.0, 0.1)
	mark_tween.tween_property(mark, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mark_tween.tween_property(mark, "position:y", mark.position.y - 30, 0.2)
	
	# 階段 2: 停留 1 秒
	mark_tween.set_parallel(false)
	mark_tween.tween_interval(1.0)
	
	# 階段 3: 消失並觸發攻擊
	mark_tween.tween_property(mark, "modulate:a", 0.0, 0.3)
	mark_tween.tween_callback(mark.queue_free)
	mark_tween.tween_callback(_play_clash_animation)

func _play_clash_animation():
	print("[Splash] Clash Sequence Started!")
	attack_count = 0
	_play_attack_cycle()

func _play_attack_cycle():
	if transitioning: return
	attack_count += 1
	
	# --- 主角回合 (Player Turn) ---
	var p_pos_x = player.position.x
	var p_tween = create_tween()
	
	# 播放攻擊音效
	if sfx_attack: sfx_attack.play()
	
	p_tween.tween_property(player, "position:x", p_pos_x + 80, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p_tween.parallel().tween_callback(func(): _play_damage_effect(goblin))
	
	# 如果是第四次攻擊，觸發擊飛
	if attack_count >= 4:
		# 往前衝 (0.1s)
		p_tween.tween_property(player, "position:x", p_pos_x + 100, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 命中瞬間：同時觸發傷害特效與「立刻」擊飛
		p_tween.parallel().tween_callback(func():
			# _play_damage_effect(goblin)
			_goblin_fly_away()
		)
		# 主角自己彈回來
		p_tween.chain().tween_property(player, "position:x", p_pos_x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return

	# 正常的彈回
	p_tween.tween_property(player, "position:x", p_pos_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p_tween.tween_interval(0.3)
	
	# --- 哥布林回合 (Goblin Turn) ---
	p_tween.tween_callback(func():
		var g_pos_x = goblin.position.x
		var g_tween = create_tween()
		
		# 播放攻擊音效
		if sfx_attack: sfx_attack.play()
		
		g_tween.tween_property(goblin, "position:x", g_pos_x - 80, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		g_tween.parallel().tween_callback(func(): _play_damage_effect(player))
		g_tween.tween_property(goblin, "position:x", g_pos_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# 等待一下再開始下一輪
		g_tween.finished.connect(func():
			if not transitioning:
				if attack_count == 3:
					# 🌟 第三輪結束，先等 1 秒再變身
					get_tree().create_timer(1.0).timeout.connect(func():
						print("[Splash] Player Transformation!")
						if sfx_levelup: sfx_levelup.play()
						player.texture = load("res://assets/player2.png")
						# 變身後再等 1 秒進行最後一擊
						get_tree().create_timer(2.5).timeout.connect(_play_attack_cycle)
					)
				else:
					get_tree().create_timer(0.3).timeout.connect(_play_attack_cycle)
		)
	)

func _goblin_fly_away():
	if not goblin: return
	print("[Splash] Goblin Defeated! Flying away...")
	
	# 調整中心點以便旋轉
	goblin.pivot_offset = goblin.size / 2
	
	var fly_tween = create_tween().set_parallel(true)
	# 往右方飛走
	fly_tween.tween_property(goblin, "position:x", goblin.position.x + 1000, 1.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	# fly_tween.tween_property(goblin, "position:y", goblin.position.y - 1000, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 順時針快速旋轉
	fly_tween.tween_property(goblin, "rotation_degrees", 1440, 1.5)
	
	# 縮小與淡出
	fly_tween.tween_property(goblin, "scale", Vector2(0.1, 0.1), 1.5)
	fly_tween.tween_property(goblin, "modulate:a", 0.0, 1.5)
	
	# 飛走後延遲進入主畫面
	fly_tween.chain().tween_interval(5.0)
	fly_tween.chain().tween_callback(_change_scene)

func _play_damage_effect(sprite: TextureRect):
	if not sprite: return
	var original_pos = sprite.position
	
	# 🔴 閃紅光
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", Color(2, 0, 0, 1), 0.1)
	color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# 🫨 抖動
	var shake_tween = create_tween()
	var shake_duration = 0.04
	var offset = 4
	
	for i in range(4):
		shake_tween.tween_property(sprite, "position:x", original_pos.x - offset, shake_duration)
		shake_tween.tween_property(sprite, "position:x", original_pos.x + offset, shake_duration)
	
	shake_tween.tween_property(sprite, "position:x", original_pos.x, shake_duration)

func play_walk_animation():
	if not player: return
	
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	
	anim_tween = create_tween().set_loops()
	
	# 模擬左腳踏步
	anim_tween.tween_property(player, "rotation_degrees", 2, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	anim_tween.parallel().tween_property(player, "position:y", original_pos_y - 5, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_tween.tween_property(player, "rotation_degrees", 4, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	anim_tween.parallel().tween_property(player, "position:y", original_pos_y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_tween.tween_callback(func(): if sfx_step: sfx_step.play())
	
	# 模擬右腳踏步
	anim_tween.tween_property(player, "rotation_degrees", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	anim_tween.parallel().tween_property(player, "position:y", original_pos_y - 5, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_tween.tween_property(player, "rotation_degrees", -4, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	anim_tween.parallel().tween_property(player, "position:y", original_pos_y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_tween.tween_callback(func(): if sfx_step: sfx_step.play())

func _play_goblin_idle(duration: float = -1.0):
	if not goblin: return
	if goblin_tween and goblin_tween.is_valid():
		goblin_tween.kill()
	
	goblin_tween = create_tween().set_loops()
	# 每 3 秒翻轉一次，模擬左右觀看
	goblin_tween.tween_interval(3)
	goblin_tween.tween_callback(func(): goblin.flip_h = !goblin.flip_h)
	
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(_stop_goblin_idle)

func _stop_goblin_idle():
	if goblin_tween and goblin_tween.is_valid():
		goblin_tween.kill()
	
	goblin_stopped = true
	_check_show_exclamation()

func _start_skip_button_animation():
	if not skip_button: return
	
	skip_button.modulate.a = 0
	
	# 1. 初始登場 (只延遲一次)
	var intro_tween = create_tween()
	intro_tween.tween_property(skip_button, "modulate:a", 0.6, 1.5).set_delay(2.0)
	
	# 2. 登場完畢後，啟動無限呼吸循環
	intro_tween.finished.connect(func():
		if transitioning: return # 預防轉場中啟動
		skip_tween = create_tween().set_loops()
		skip_tween.tween_property(skip_button, "modulate:a", 0.0, 1.5)
		skip_tween.tween_property(skip_button, "modulate:a", 0.6, 1.5)
	)

func _on_skip_button_mouse_entered():
	# 暫停呼吸，並瞬間變亮
	if skip_tween and skip_tween.is_valid():
		skip_tween.pause()
	
	# 用一個極短的動畫讓它變亮，看起來更順
	create_tween().tween_property(skip_button, "modulate:a", 1.0, 0.1)

func _on_skip_button_mouse_exited():
	# 恢復呼吸
	if skip_tween and skip_tween.is_valid():
		skip_tween.play()

func _change_scene():
	if transitioning:
		return
	transitioning = true
	
	if anim_tween:
		anim_tween.kill()
	if move_tween:
		move_tween.kill()
	if goblin_tween:
		goblin_tween.kill()
	if mark_tween:
		mark_tween.kill()
	if skip_tween:
		skip_tween.kill()
		
	get_tree().change_scene_to_file("res://main.tscn")
