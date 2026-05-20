extends Control


func _on_lvl_1_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_1.tscn")


func _on_lvl_2_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_2.tscn")


func _on_lvl_3_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_3.tscn")
