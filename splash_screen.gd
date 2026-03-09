extends Control

@onready var video_player = $VideoStreamPlayer
@onready var skip_btn = $SkipButton

var transitioning = false
var elapsed = 0.0
# 🎬 影片長度與總等待時間設定
const VIDEO_DURATION = 9.0  # 影片實際播放長度
const TARGET_TIME = VIDEO_DURATION + 3.0  # 影片後額外等待 3 秒再跳轉

func _ready():
	# 基礎設定
	# 即使我們主力用定時器，保留 Skip 按鈕還是比較好的體驗，按了就直接進去
	skip_btn.pressed.connect(_change_scene)
	
	# Skip 按鈕淡入效果 (1.5秒後顯示)
	skip_btn.modulate.a = 0
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(skip_btn, "modulate:a", 0.6, 1.0)

func _process(delta):
	if transitioning:
		return
		
	elapsed += delta
	
	# 🕒 時間一到，直接換景
	if elapsed >= TARGET_TIME:
		_change_scene()

func _change_scene():
	if transitioning:
		return
	transitioning = true
	
	# 停止影片播放
	if video_player != null:
		video_player.stop()
	
	# 切換場景
	get_tree().change_scene_to_file("res://main.tscn")

func _input(event):
	# 仍然保留輸入偵測，點擊畫面可協助解鎖瀏覽器對 Web 遊戲的限制
	if event is InputEventMouseButton and event.pressed:
		pass 
