extends Node2D

@onready var player_texture = $Player/PlayerTexture

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if player_texture:
		var tex_path = "res://assets/" + Global.equipped_skin + ".png"
		if ResourceLoader.exists(tex_path):
			player_texture.texture = load(tex_path)
		player_texture.scale = Vector2(0.352, 0.352)
		var eyes = $Player/Eyes
		if eyes:
			eyes.scale = Vector2(0.352, 0.352)



func _process(delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Freeplay.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_player_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SkinSelection.tscn")
