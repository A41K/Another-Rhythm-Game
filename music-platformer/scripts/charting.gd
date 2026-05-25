extends Node2D

@export var song_name: String = "test_song"
@export var spawn_distance: float = 600.0
@export var note_speed: float = 200.0
@export var approach_time: float = 1.2
@export var input_offset: float = 0.0
@export var max_spawns_per_frame: int = 48
@export var note_scene: PackedScene

var chart_data: Dictionary = {}
var song_position: float = 0.0
var notes_queue: Array = []
var last_note_time: float = 0.0
var has_audio_stream: bool = false
var showing_results: bool = false
var result_timer: float = 0.0
var score_key: String = ""

const RESULT_SCREEN_SECONDS: float = 2.75

var time_begin: int = 0
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var results_overlay: Control = get_parent().get_node_or_null("ResultsOverlay")
@onready var result_song_label: Label = get_parent().get_node_or_null("ResultsOverlay/Summary/ResultSong")
@onready var result_score_label: Label = get_parent().get_node_or_null("ResultsOverlay/Summary/ResultScore")
@onready var result_misses_label: Label = get_parent().get_node_or_null("ResultsOverlay/Summary/ResultMisses")

func _ready():
	if Global.current_song_name != "":
		song_name = Global.current_song_name
	var selected_song_data := Global.current_song_data
	score_key = str(selected_song_data.get("score_key", _get_score_key_from_song_name(song_name)))
	note_speed = spawn_distance / max(0.25, approach_time)
		
	var chart_path = "res://charts/" + song_name + ".json"
	if selected_song_data.has("chart_path") and FileAccess.file_exists(selected_song_data["chart_path"]):
		chart_path = selected_song_data["chart_path"]
	if FileAccess.file_exists(chart_path):
		var file = FileAccess.open(chart_path, FileAccess.READ)
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK:
			chart_data = json.data
			if chart_data.has("approach_time"):
				approach_time = max(0.25, float(chart_data["approach_time"]))
				note_speed = spawn_distance / approach_time
			elif chart_data.has("note_speed"):
				note_speed = max(1.0, float(chart_data["note_speed"]))
				approach_time = spawn_distance / note_speed
			if chart_data.has("input_offset"):
				input_offset = float(chart_data["input_offset"])
			if chart_data.has("max_spawns_per_frame"):
				max_spawns_per_frame = max(1, int(chart_data["max_spawns_per_frame"]))
			if chart_data.has("notes"):
				var raw_notes = chart_data["notes"]
				notes_queue = []
				last_note_time = 0.0
				for n in raw_notes:
					if typeof(n) == TYPE_ARRAY and n.size() >= 2:
						var parsed_time = float(n[0])
						notes_queue.append({"time": parsed_time, "direction": n[1]})
						last_note_time = max(last_note_time, parsed_time)
					else:
						notes_queue.append(n)
						last_note_time = max(last_note_time, float(n.get("time", 0.0)))
				notes_queue.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	else:
		print("Chart not found: ", chart_path)

	var audio_path = "res://songs/" + song_name + ".mp3"
	if selected_song_data.has("audio_path") and ResourceLoader.exists(selected_song_data["audio_path"]):
		audio_path = selected_song_data["audio_path"]
	elif selected_song_data.has("audio_file"):
		var explicit_audio = "res://songs/" + str(selected_song_data["audio_file"])
		if ResourceLoader.exists(explicit_audio):
			audio_path = explicit_audio
	if ResourceLoader.exists(audio_path):
		audio_player.stream = load(audio_path)
		audio_player.play()
		has_audio_stream = true
	else:
		print("Audio not found: ", audio_path, ". Proceeding with silent chart sequence.")
		has_audio_stream = false

	if results_overlay:
		results_overlay.visible = false
		
	time_begin = Time.get_ticks_usec()

func _get_score_key_from_song_name(name: String) -> String:
	if name.ends_with("_easy"):
		return name.replace("_easy", "")
	if name.ends_with("_hard"):
		return name.replace("_hard", "")
	if name.ends_with("_normal"):
		return name.replace("_normal", "")
	if name.ends_with("_expert"):
		return name.replace("_expert", "")
	return name

func _process(delta):
	if showing_results:
		result_timer -= delta
		if result_timer <= 0.0:
			_return_to_freeplay()
		return

	if audio_player and audio_player.playing:
		song_position = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()
	else:
		var time_passed = (Time.get_ticks_usec() - time_begin) / 1000000.0
		song_position = time_passed

	song_position += input_offset
		
	var spawn_advance = approach_time
	if note_speed > 0.0:
		spawn_advance = max(approach_time, spawn_distance / note_speed)
	
	var spawned_this_frame := 0
	while notes_queue.size() > 0 and spawned_this_frame < max_spawns_per_frame:
		var next_note_time = float(notes_queue[0]["time"])
		if next_note_time <= song_position + spawn_advance:
			spawn_note(notes_queue[0])
			notes_queue.pop_front()
			spawned_this_frame += 1
		else:
			break

	_check_song_finished()

func _check_song_finished():
	if showing_results:
		return
	if notes_queue.size() > 0:
		return

	for note in get_tree().get_nodes_in_group("Notes"):
		if note.active:
			return

	var chart_finished = song_position >= (last_note_time + 0.25)
	var audio_finished = (not has_audio_stream) or (audio_player and not audio_player.playing)
	if chart_finished and audio_finished:
		_show_results()

func _show_results():
	showing_results = true
	result_timer = RESULT_SCREEN_SECONDS

	var player = get_tree().get_first_node_in_group("Player")
	var final_score := 0
	var misses := 0
	if player:
		if player.has_method("get_final_score"):
			final_score = int(player.get_final_score())
		if player.has_method("get_miss_count"):
			misses = int(player.get_miss_count())

	Global.last_song_score = final_score
	Global.last_song_misses = misses
	Global.last_song_name = song_name
	if score_key == "":
		score_key = _get_score_key_from_song_name(song_name)
	Global.record_song_score(score_key, final_score)

	if result_song_label:
		result_song_label.text = "Song: " + song_name
	if result_score_label:
		result_score_label.text = "Final Score: " + str(final_score)
	if result_misses_label:
		result_misses_label.text = "Misses: " + str(misses)
	if results_overlay:
		results_overlay.visible = true

func _return_to_freeplay():
	if ResourceLoader.exists("res://scenes/Freeplay.tscn"):
		get_tree().change_scene_to_file("res://scenes/Freeplay.tscn")

func spawn_note(note_data: Dictionary):
	if not note_scene:
		print("ERROR: Note scene not assigned in Conductor!")
		return
		
	var note_inst = note_scene.instantiate()
	add_child(note_inst)
	
	var dir: int = int(note_data.get("direction", 0))
	
	var player = get_tree().get_first_node_in_group("Player")
	var center_pos = player.global_position if player else Vector2(576, 324)
	var start_pos = center_pos
	
	if dir == 0: start_pos += Vector2(0, -spawn_distance) 
	elif dir == 1: start_pos += Vector2(spawn_distance, 0)
	elif dir == 2: start_pos += Vector2(0, spawn_distance) 
	elif dir == 3: start_pos += Vector2(-spawn_distance, 0) 
	
	note_inst.global_position = start_pos
	note_inst.spawn_position = start_pos
	note_inst.direction = dir
	note_inst.hit_time = float(note_data.get("time", 0.0))
	note_inst.speed = note_speed
	note_inst.conductor = self
