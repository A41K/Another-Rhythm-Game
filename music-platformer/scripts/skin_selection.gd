extends Node2D

@onready var status_label: Label = $Panel/StatusLabel

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_status()

func update_status() -> void:
	status_label.text = "Current Skin: " + Global.equipped_skin

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/titlescreen.tscn")

func _on_skin_1_pressed() -> void:
	Global.equipped_skin = "player"
	Global.save_settings()
	update_status()

func _on_skin_2_pressed() -> void:
	if Global.ach_no_misses:
		Global.equipped_skin = "Red"
		Global.save_settings()
		status_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
		update_status()
	else:
		status_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		status_label.text = "Locked: Beat a song with 0 misses!"

func _on_skin_3_pressed() -> void:
	if Global.get_hard_songs_beaten_count() >= 2:
		Global.equipped_skin = "Tophat"
		Global.save_settings()
		status_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
		update_status()
	else:
		status_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		status_label.text = "Locked: Beat 2 hard charts! (Done: " + str(Global.get_hard_songs_beaten_count()) + ")"
func _on_skin_4_pressed() -> void:
	Global.equipped_skin = "Skins/rectangle"
	Global.save_settings()
	status_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
	update_status()
