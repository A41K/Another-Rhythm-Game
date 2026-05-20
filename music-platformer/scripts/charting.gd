extends Node2D

@export var song_name: String = "test_song"
@export var spawn_distance: float = 600.0
@export var note_speed: float = 200.0
@export var note_scene: PackedScene

var chart_data: Dictionary = {}
var song_position: float = 0.0
var notes_queue: Array = []

var time_begin: int = 0
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready():
	var chart_path = "res://charts/" + song_name + ".json"
	if FileAccess.file_exists(chart_path):
		var file = FileAccess.open(chart_path, FileAccess.READ)
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK:
			chart_data = json.data
			if chart_data.has("notes"):
				notes_queue = chart_data["notes"]
				notes_queue.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	else:
		print("Chart not found: ", chart_path)

	var audio_path = "res://songs/" + song_name + ".mp3"
	if ResourceLoader.exists(audio_path):
		audio_player.stream = load(audio_path)
		audio_player.play()
	else:
		print("Audio not found: ", audio_path, ". Proceeding with silent chart sequence.")
		
	time_begin = Time.get_ticks_usec()

func _process(delta):
	if audio_player and audio_player.playing:
		song_position = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()
	else:
		var time_passed = (Time.get_ticks_usec() - time_begin) / 1000000.0
		song_position = time_passed
		
	var spawn_advance = spawn_distance / note_speed
	
	while notes_queue.size() > 0:
		var next_note_time = float(notes_queue[0]["time"])
		if next_note_time <= song_position + spawn_advance:
			spawn_note(notes_queue[0])
			notes_queue.pop_front()
		else:
			break

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
	note_inst.speed = note_speed
