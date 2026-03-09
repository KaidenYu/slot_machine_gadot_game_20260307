extends Control

@onready var video_player = $VideoStreamPlayer
@onready var skip_btn = $SkipButton

var transitioning = false

func _ready():
	# 🎬 當影片播放結束時，觸發 3 秒延遲
	video_player.finished.connect(_on_video_finished)
	# 🖱️ 隨時可以點擊跳過切換
	skip_btn.pressed.connect(_on_skip_pressed)
	
	# 💡 淡入顯示 Skip 按鈕 (2秒後才顯示)
	var tween = create_tween()
	skip_btn.modulate.a = 0
	tween.tween_interval(2.0)
	tween.tween_property(skip_btn, "modulate:a", 0.6, 1.0)

# 🎬 影片播放結束：進入 3 秒停頓期，但允许手動跳過
func _on_video_finished():
	if transitioning:
		return
	# 這裡不立即設為 transitioning，因為我們要讓 skip_btn 還能按
	await get_tree().create_timer(3.0).timeout
	_change_scene()

# 🖱️ 手動點擊跳過：立刻更換場景
func _on_skip_pressed():
	_change_scene()

# 🚀 執行場景切換
func _change_scene():
	if transitioning:
		return
	transitioning = true
	
	# 🎬 先把按鈕隱藏並停止影片
	skip_btn.disabled = true
	var tween = create_tween()
	tween.tween_property(skip_btn, "modulate:a", 0, 0.3)
	
	if video_player.is_playing():
		video_player.stop()

	get_tree().change_scene_to_file("res://main.tscn")

