extends Node

var current_song_data: Dictionary = {}
var current_song_name: String = "test_song"
var last_song_score: int = 0
var last_song_misses: int = 0
var last_song_name: String = ""
var song_scores: Dictionary = {}

var master_volume: float = 1.0
var cursor_sensitivity: float = 1.0
const SETTINGS_SAVE_PATH: String = "user://settings.json"

const SCORE_SAVE_PATH: String = "user://song_scores.json"

func _ready():
	load_song_scores()
	load_settings()

func load_settings():
	if not FileAccess.file_exists(SETTINGS_SAVE_PATH):
		return
	var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
	if not file: return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		if json.data.has("master_volume"):
			master_volume = float(json.data["master_volume"])
			var bus = AudioServer.get_bus_index("Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))
		if json.data.has("cursor_sensitivity"):
			cursor_sensitivity = float(json.data["cursor_sensitivity"])

func save_settings():
	var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if not file: return
	var data = {
		"master_volume": master_volume,
		"cursor_sensitivity": cursor_sensitivity
	}
	file.store_string(JSON.stringify(data, "\t"))

func load_song_scores():
	song_scores = {}
	if not FileAccess.file_exists(SCORE_SAVE_PATH):
		return

	var file = FileAccess.open(SCORE_SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	if typeof(json.data) == TYPE_DICTIONARY:
		song_scores = json.data

func save_song_scores():
	var file = FileAccess.open(SCORE_SAVE_PATH, FileAccess.WRITE)
	if not file:
		return

	file.store_string(JSON.stringify(song_scores, "\t"))

func get_song_score(song_key: String) -> int:
	if song_scores.has(song_key):
		return int(song_scores[song_key])
	return 0

func record_song_score(song_key: String, new_score: int):
	if song_key == "":
		return

	var stored_score = get_song_score(song_key)
	song_scores[song_key] = max(stored_score, new_score)
	save_song_scores()
