extends Control

@onready var back_btn: Button = $"back to freeplay"
@onready var return_btn: Button = $"return"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if return_btn:
		return_btn.pressed.connect(resume_game)

func _input(event):
	if event.is_action_pressed("escape"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()

func resume_game():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false

func _on_back_pressed():
	resume_game()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
	get_tree().change_scene_to_file("res://scenes/Freeplay.tscn")
