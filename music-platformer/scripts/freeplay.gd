extends Control

@onready var song_list_container = $MarginContainer/HBoxContainer/RightPanel/ScrollContainer/VBoxContainer
@onready var title_label = $Title
@onready var song_name_label = $MarginContainer/HBoxContainer/LeftPanel/SongName
@onready var bpm_label = $MarginContainer/HBoxContainer/LeftPanel/LevelInfo/BPM
@onready var stars_container = $MarginContainer/HBoxContainer/LeftPanel/Stars
@onready var vinyl = $MarginContainer/HBoxContainer/LeftPanel/CoverContainer/Vinyl
@onready var cover_panel = $MarginContainer/HBoxContainer/LeftPanel/CoverContainer/Cover
@onready var cover_texture = $MarginContainer/HBoxContainer/LeftPanel/CoverContainer/Cover/CoverTexture
@onready var cover_label = $MarginContainer/HBoxContainer/LeftPanel/CoverContainer/Cover/CoverLabel
@onready var back_btn = $BackButton
@onready var easy_label = $MarginContainer/HBoxContainer/LeftPanel/LevelInfo/Easy
@onready var hard_label = $MarginContainer/HBoxContainer/LeftPanel/LevelInfo/Hard
@onready var freeplay_score_label = $ScoreValue

var songs: Array = []
var selected_index: int = 0
var vinyl_rotation: float = 0.0
var cover_lookup: Dictionary = {}
var song_lookup: Dictionary = {}

var current_difficulty: String = "normal"

const COVER_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]

func _ready():
	vinyl.draw.connect(_on_vinyl_draw)
	back_btn.pressed.connect(_on_back_pressed)
	
	easy_label.gui_input.connect(_on_easy_gui_input)
	hard_label.gui_input.connect(_on_hard_gui_input)

	load_songs()
	populate_song_list()
	_update_last_score_display()
	if songs.size() > 0:
		select_song(0)

func _process(delta):
	if songs.size() > 0:
		vinyl_rotation += delta * 2.0
		vinyl.queue_redraw()

func _on_vinyl_draw():
	var center = Vector2(90, 0)
	vinyl.draw_circle(center, 140.0, Color(0.1, 0.1, 0.1, 1))
	vinyl.draw_arc(center, 125.0, 0, TAU, 32, Color(0.2, 0.2, 0.2, 1), 2.0)
	vinyl.draw_arc(center, 110.0, 0, TAU, 32, Color(0.2, 0.2, 0.2, 1), 2.0)
	vinyl.draw_arc(center, 95.0, 0, TAU, 32, Color(0.2, 0.2, 0.2, 1), 2.0)

	vinyl.draw_circle(center, 50.0, Color(0.9, 0.2, 0.2, 1))

	var p1 = center + Vector2(cos(vinyl_rotation), sin(vinyl_rotation)) * 50.0
	var p2 = center + Vector2(cos(vinyl_rotation + PI), sin(vinyl_rotation + PI)) * 50.0
	vinyl.draw_line(p1, p2, Color(1, 1, 1, 0.5), 4.0)

func _normalized_asset_key(raw_name: String) -> String:
	return raw_name.to_lower().replace(" ", "").replace("_", "").replace("-", "")

func _index_assets(folder_path: String, allowed_extensions: Array) -> Dictionary:
	var index := {}
	var dir := DirAccess.open(folder_path)
	if not dir:
		return index

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext := file_name.get_extension().to_lower()
			if allowed_extensions.has(ext):
				var base := file_name.get_basename()
				index[_normalized_asset_key(base)] = folder_path + file_name
		file_name = dir.get_next()

	return index

func _resolve_cover_path(song_group: Dictionary, active_data: Dictionary) -> String:
	if active_data.has("cover_path") and ResourceLoader.exists(active_data["cover_path"]):
		return active_data["cover_path"]

	if active_data.has("cover_file"):
		var explicit_cover = "res://covers/" + str(active_data["cover_file"])
		if ResourceLoader.exists(explicit_cover):
			return explicit_cover

	if song_group.has("meta") and song_group["meta"].has("cover_file"):
		var meta_cover = "res://covers/" + str(song_group["meta"]["cover_file"])
		if ResourceLoader.exists(meta_cover):
			return meta_cover

	var group_key := _normalized_asset_key(song_group.get("base_name", ""))
	if cover_lookup.has(group_key):
		return cover_lookup[group_key]

	var song_name_key := _normalized_asset_key(active_data.get("name", ""))
	if cover_lookup.has(song_name_key):
		return cover_lookup[song_name_key]

	return ""

func _resolve_audio_path(song_group: Dictionary, active_data: Dictionary) -> String:
	if active_data.has("audio_path") and ResourceLoader.exists(active_data["audio_path"]):
		return active_data["audio_path"]

	if active_data.has("audio_file"):
		var explicit_audio = "res://songs/" + str(active_data["audio_file"])
		if ResourceLoader.exists(explicit_audio):
			return explicit_audio

	if song_group.has("meta") and song_group["meta"].has("audio_file"):
		var meta_audio = "res://songs/" + str(song_group["meta"]["audio_file"])
		if ResourceLoader.exists(meta_audio):
			return meta_audio

	var group_key := _normalized_asset_key(song_group.get("base_name", ""))
	if song_lookup.has(group_key):
		return song_lookup[group_key]

	var song_name_key := _normalized_asset_key(active_data.get("name", ""))
	if song_lookup.has(song_name_key):
		return song_lookup[song_name_key]

	return ""

func _update_cover_art(song_group: Dictionary, active_data: Dictionary):
	if not is_instance_valid(cover_texture) or not is_instance_valid(cover_label):
		return

	var cover_path := _resolve_cover_path(song_group, active_data)
	if cover_path != "":
		var tex = load(cover_path)
		if tex is Texture2D:
			cover_texture.texture = tex
			cover_texture.visible = true
			cover_label.visible = false
			return

	cover_texture.texture = null
	cover_texture.visible = false
	cover_label.visible = true

func load_songs():
	songs.clear()
	cover_lookup = _index_assets("res://covers/", COVER_EXTENSIONS)
	song_lookup = _index_assets("res://songs/", AUDIO_EXTENSIONS)

	var dir = DirAccess.open("res://charts/")
	var temp_groups = {}
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open("res://charts/" + file_name, FileAccess.READ)
				if file:
					var json = JSON.new()
					if json.parse(file.get_as_text()) == OK:
						var data = json.data
						var bare_name = file_name.replace(".json", "")
						var difficulty = "normal"
						var base_name = bare_name
						
						if bare_name.ends_with("_easy"):
							difficulty = "easy"
							base_name = bare_name.replace("_easy", "")
						elif bare_name.ends_with("_hard"):
							difficulty = "hard"
							base_name = bare_name.replace("_hard", "")
							
						data["file_name"] = bare_name
						if not data.has("artist"): data["artist"] = "Unknown Artist"
						if not data.has("rating"): data["rating"] = 3
						if not data.has("bpm"): data["bpm"] = 120
						if not data.has("name"): data["name"] = base_name.replace("_", " ").capitalize()
						
						if not temp_groups.has(base_name):
							temp_groups[base_name] = {"base_name": base_name, "files": {}}
						
						temp_groups[base_name]["files"][difficulty] = data
						if not temp_groups[base_name].has("meta"):
							temp_groups[base_name]["meta"] = data # Save first found metadata
			file_name = dir.get_next()
	
	for key in temp_groups.keys():
		songs.append(temp_groups[key])

func populate_song_list():
	for child in song_list_container.get_children():
		child.queue_free()

	for i in range(songs.size()):
		var song_group = songs[i]
		var meta = song_group["meta"]

		var btn = Button.new()
		btn.text = meta.get("name", "Unknown") + " - " + meta.get("artist", "")
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 28)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.20, 0.35, 1) if i == selected_index else Color(0.1, 0.1, 0.1, 1)
		style.border_width_bottom = 4
		style.border_width_top = 4
		style.border_width_left = 4
		style.border_width_right = 4

		if i == selected_index:
			style.border_color = Color(0.2, 0.6, 1.0, 1) # Blue
		else:
			style.border_color = Color(0.8, 0.8, 0.8, 1) # White

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

		btn.pressed.connect(func():
			_on_song_clicked(i)
		)
		song_list_container.add_child(btn)

func _on_song_clicked(idx: int):
	if selected_index == idx:
		play_selected_song()
	else:
		select_song(idx)
		populate_song_list()

func play_selected_song():
	var group = songs[selected_index]
	var diff_to_play = current_difficulty
	
	if not group["files"].has(diff_to_play):
		# Fallback to whatever is available
		if group["files"].keys().size() > 0:
			diff_to_play = group["files"].keys()[0]
	
	Global.current_song_name = group["files"][diff_to_play]["file_name"]
	var selected_data: Dictionary = group["files"][diff_to_play].duplicate(true)
	selected_data["score_key"] = group["base_name"]
	selected_data["audio_path"] = _resolve_audio_path(group, selected_data)
	selected_data["cover_path"] = _resolve_cover_path(group, selected_data)
	Global.current_song_data = selected_data
	get_tree().change_scene_to_file("res://scenes/mainscene.tscn")

func select_song(idx: int):
	selected_index = idx
	
	# Determine best default difficulty if what they clicked doesn't have it
	var group = songs[idx]
	if not group["files"].has(current_difficulty):
		if group["files"].has("normal"): current_difficulty = "normal"
		elif group["files"].keys().size() > 0: current_difficulty = group["files"].keys()[0]

	update_difficulty_display()

func update_difficulty_display():
	if songs.size() == 0: return
	var group = songs[selected_index]
	
	var active_data = group["meta"]
	if group["files"].has(current_difficulty):
		active_data = group["files"][current_difficulty]
	else:
		if group["files"].keys().size() > 0:
			active_data = group["files"][group["files"].keys()[0]]
		
	song_name_label.text = active_data.get("name", "Unknown")
	bpm_label.text = str(active_data.get("bpm", 120)) + " BPM"
	_update_cover_art(group, active_data)
	_update_song_score_display(group)

	easy_label.modulate = Color(1.0, 1.0, 1.0, 1.0) if current_difficulty == "easy" else Color(0.4, 0.4, 0.4, 1.0)
	hard_label.modulate = Color(1.0, 1.0, 1.0, 1.0) if current_difficulty == "hard" else Color(0.4, 0.4, 0.4, 1.0)

	for child in stars_container.get_children():
		child.queue_free()

	var rating = int(active_data.get("rating", 3))
	for i in range(5):
		var star = Label.new()
		star.text = "★" if i < rating else "☆"
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.add_theme_font_size_override("font_size", 32)
		star.add_theme_color_override("font_color", Color.WHITE)

		var star_style = StyleBoxFlat.new()
		star_style.bg_color = Color.TRANSPARENT
		star_style.border_width_bottom = 2
		star_style.border_width_top = 2
		star_style.border_width_left = 2
		star_style.border_width_right = 2
		star_style.border_color = Color.WHITE

		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", star_style)
		panel.add_child(star)

		stars_container.add_child(panel)

func _on_easy_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if songs[selected_index]["files"].has("easy"):
			current_difficulty = "easy"
			update_difficulty_display()

func _on_hard_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if songs[selected_index]["files"].has("hard"):
			current_difficulty = "hard"
			update_difficulty_display()

func _on_back_pressed():
	if ResourceLoader.exists("res://scenes/titlescreen.tscn"):
		get_tree().change_scene_to_file("res://scenes/titlescreen.tscn")
	elif ResourceLoader.exists("res://OLD ASSETS/scenes/titlescreen.tscn"):
		get_tree().change_scene_to_file("res://OLD ASSETS/scenes/titlescreen.tscn")

func _update_last_score_display():
	if freeplay_score_label:
		freeplay_score_label.text = str(Global.last_song_score)

func _update_song_score_display(song_group: Dictionary):
	if not freeplay_score_label:
		return

	var key = str(song_group.get("base_name", ""))
	if key == "":
		freeplay_score_label.text = "0"
		return

	freeplay_score_label.text = str(Global.get_song_score(key))
