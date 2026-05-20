class_name Player extends CharacterBody2D

@onready var CoyoteTimer: Timer = $CoyoteTimer
@onready var JumpBufferTimer: Timer = $JumpBufferTimer

const TOUCH_LEFT_MAX: float = 0.35
const TOUCH_RIGHT_MIN: float = 0.65

var _touch_id_to_action: Dictionary = {}
var _touch_action_counts: Dictionary = {
	"left": 0,
	"right": 0,
	"jump": 0,
}
var _is_mobile: bool = false

var coyote_time_activated: bool = false
var spawn_position: Vector2


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if _is_mobile:
		_create_mobile_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_mobile:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			var action: String = _get_touch_action(touch_event.position)
			_touch_id_to_action[touch_event.index] = action
			_add_touch_action(action)
		else:
			if _touch_id_to_action.has(touch_event.index):
				var released_action: String = _touch_id_to_action[touch_event.index]
				_remove_touch_action(released_action)
				_touch_id_to_action.erase(touch_event.index)
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if _touch_id_to_action.has(drag_event.index):
			var current_action: String = _touch_id_to_action[drag_event.index]
			var next_action: String = _get_touch_action(drag_event.position)
			if current_action != next_action:
				_remove_touch_action(current_action)
				_touch_id_to_action[drag_event.index] = next_action
				_add_touch_action(next_action)


func _get_touch_action(touch_position: Vector2) -> String:
	var viewport_width: float = get_viewport_rect().size.x
	if viewport_width <= 0.0:
		return "jump"

	var normalized_x: float = touch_position.x / viewport_width
	if normalized_x <= TOUCH_LEFT_MAX:
		return "left"
	if normalized_x >= TOUCH_RIGHT_MIN:
		return "right"
	return "jump"


func _add_touch_action(action: String) -> void:
	_touch_action_counts[action] += 1
	Input.action_press(action)


func _remove_touch_action(action: String) -> void:
	_touch_action_counts[action] = max(_touch_action_counts[action] - 1, 0)
	if _touch_action_counts[action] == 0:
		Input.action_release(action)


func _create_mobile_controls() -> void:
	var controls_layer: CanvasLayer = CanvasLayer.new()
	controls_layer.layer = 100
	add_child(controls_layer)

	var controls_root: Control = Control.new()
	controls_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_root.mouse_filter = Control.MOUSE_FILTER_PASS
	controls_layer.add_child(controls_root)

	_create_virtual_button(controls_root, "left", "<", 0.03, 0.78, 0.18, 0.96)
	_create_virtual_button(controls_root, "right", ">", 0.21, 0.78, 0.36, 0.96)
	_create_virtual_button(controls_root, "jump", "JUMP", 0.79, 0.72, 0.96, 0.96)


func _create_virtual_button(parent: Control, action: String, text_value: String, a_left: float, a_top: float, a_right: float, a_bottom: float) -> void:
	var button: Button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = a_left
	button.anchor_top = a_top
	button.anchor_right = a_right
	button.anchor_bottom = a_bottom
	button.offset_left = 0
	button.offset_top = 0
	button.offset_right = 0
	button.offset_bottom = 0
	button.modulate = Color(1.0, 1.0, 1.0, 0.8)
	button.button_down.connect(_on_virtual_button_down.bind(action))
	button.button_up.connect(_on_virtual_button_up.bind(action))
	parent.add_child(button)


func _on_virtual_button_down(action: String) -> void:
	_add_touch_action(action)


func _on_virtual_button_up(action: String) -> void:
	_remove_touch_action(action)


func _exit_tree() -> void:
	for action in _touch_action_counts.keys():
		if _touch_action_counts[action] > 0:
			Input.action_release(action)

func respawn() -> void:
	velocity = Vector2.ZERO
	gravity = 20.0
	coyote_time_activated = false
	is_wall_sticking = false
	CoyoteTimer.stop()
	JumpBufferTimer.stop()

var jump_height: float = -400.0
var gravity: float = 20.0
const max_gravity: float = 18

var is_wall_sticking: bool = false

const max_speed: float = 300
const acceleration: float = 16
const friction: float = 20

func _physics_process(delta: float) -> void:
	var x_input: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var velocity_weight: float = delta * (acceleration if x_input else friction)
	
	velocity.x = lerp(velocity.x, x_input * max_speed, velocity_weight)
	if is_wall_sticking:
		velocity.y = 0
		
	if is_on_floor():
		coyote_time_activated = false
		gravity = lerp(gravity, 12.0, 12.0 * delta)
	elif not is_wall_sticking:
		if CoyoteTimer.is_stopped() and !coyote_time_activated:
			CoyoteTimer.start()
			coyote_time_activated = true
		
		if Input.is_action_just_released("jump") or is_on_ceiling():
			velocity.y *= 0.5
		
		gravity = lerp(gravity, max_gravity, 12.0 * delta)
		
	if Input.is_action_just_pressed("jump"):
		if JumpBufferTimer.is_stopped():
			JumpBufferTimer.start()
			
	if !JumpBufferTimer.is_stopped() and (!CoyoteTimer.is_stopped() or is_on_floor() or is_wall_sticking):
		velocity.y = jump_height
		JumpBufferTimer.stop()
		CoyoteTimer.stop()
		coyote_time_activated = true
		if is_wall_sticking:
			is_wall_sticking = false
		
	if velocity.y < jump_height/2.0:
		var head_collision: Array = [$Left_HeadNudge.is_colliding(), $Left_HeadNudge2.is_colliding(), $Right_HeadNudge.is_colliding(), $Right_HeadNudge2.is_colliding()]
		if head_collision.count(true) == 1:
			if head_collision[0]:
				global_position.x += 1.75
			if head_collision[2]:
				global_position.x -= 1.75
	
	if velocity.y > -30 and velocity.x < -5 and abs(velocity.x) > 3:
		if $Left_LedgeHop.is_colliding() and !$Left_LedgeHop2.is_colliding() and velocity.x < 0:
			velocity.y += jump_height/3.25
		if $Right_LedgeHop.is_colliding() and !$Right_LedgeHop2.is_colliding() and velocity.x > 0:
			velocity.y += jump_height/3.25
	
	if not is_wall_sticking:
		velocity.y += gravity
	else:
		velocity.y = 0
	
	move_and_slide()
