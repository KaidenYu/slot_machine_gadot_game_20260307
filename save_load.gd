extends Node

# 存檔路徑：user:// 會在 Windows 自動指向 AppData，其餘平台依照系統規範。
# 在 Web 平台則會自動映射到瀏覽器的 IndexedDB。
const SAVE_PATH = "user://save_data.cfg"

## 儲存遊戲資料
## @param data: 包含要儲存的所有變數字典 (例如 { "gold": 100, "level": 5 })
static func save_game(data: Dictionary) -> void:
	var config = ConfigFile.new()
	
	# 將資料存入 "Player" 區塊
	# ConfigFile 會自動處理資料類型 (int, float, bool, String 等)
	for key in data.keys():
		config.set_value("Player", key, data[key])
	
	# 執行存檔
	var err = config.save(SAVE_PATH)
	if err != OK:
		printerr("存檔失敗！錯誤代碼: ", err)
	else:
		print("遊戲已成功存檔到: ", SAVE_PATH)

## 讀取遊戲資料
## @return: 返回包含讀取到資料的字典，若無檔案則返回空字典
static func load_game() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	var loaded_data = {}
	
	if err == OK:
		# 檢查是否有 "Player" 區塊
		if config.has_section("Player"):
			# 遍歷該區塊內所有的 Key
			for key in config.get_section_keys("Player"):
				loaded_data[key] = config.get_value("Player", key)
		print("讀取存檔成功！路徑: ", SAVE_PATH)
	else:
		print("找不到存檔或讀取失敗 (如果是第一次玩是正常的)，將使用初始資料。")
		
	return loaded_data

## 刪除存檔 (通常用於重置遊戲)
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		dir.remove("save_data.cfg")
		print("存檔已刪除。")
