extends Node2D

@onready var volume_slider = $Panel/VolumeSlider
@onready var sensitivity_slider = $Panel/SensitivitySlider
@onready var volume_value = $Panel/VolumeValue
@onready var sensitivity_value = $Panel/SensitivityValue

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	volume_slider.value = Global.master_volume
	sensitivity_slider.value = Global.cursor_sensitivity
	
	volume_value.text = str(round(volume_slider.value * 100))
	sensitivity_value.text = str(sensitivity_slider.value)
	
	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _on_volume_changed(value: float) -> void:
	Global.master_volume = value
	volume_value.text = str(round(value * 100))
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
	Global.save_settings()

func _on_sensitivity_changed(value: float) -> void:
	Global.cursor_sensitivity = value
	sensitivity_value.text = str(snapped(value, 0.1))
	Global.save_settings()

func _process(delta: float) -> void:
	pass

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/titlescreen.tscn")
