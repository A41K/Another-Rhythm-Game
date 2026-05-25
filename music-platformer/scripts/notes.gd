extends Area2D

@export var speed: float = 200.0
var target_position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var direction: int = 0
var hit_time: float = 0.0
var conductor: Node2D
var player_node: Node2D
var active: bool = true

func _try_deflect_from_shield_overlap():
	if not active or not player_node:
		return
	if not player_node.get("player_cover"):
		return

	var cover: Area2D = player_node.player_cover
	if cover == null:
		return

	if not overlaps_area(cover):
		return

	if not player_node.has_method("is_position_in_shield_arc"):
		return
	if not player_node.is_position_in_shield_arc(global_position):
		return

	var dist = global_position.distance_to(target_position)
	if dist > player_node.GOOD_RADIUS:
		return
	if dist < player_node.DEAD_ZONE_RADIUS:
		miss()
		return

	hit_note()

func time_until_hit() -> float:
	if not conductor:
		return 9999.0
	return hit_time - conductor.song_position

func timing_error_abs() -> float:
	return abs(time_until_hit())

func _ready():
	add_to_group("Notes")
	input_pickable = false
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	player_node = get_tree().get_first_node_in_group("Player")
	if player_node:
		target_position = player_node.global_position

	area_entered.connect(_on_area_entered)

func _process(delta):
	if not active or not player_node or not conductor:
		return
		
	var current_time = conductor.song_position
	var time_left = hit_time - current_time
	var pulse_strength = clamp(1.0 - abs(time_left) / max(player_node.MISS_WINDOW, 0.001), 0.0, 1.0)
	var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005) * (0.06 + pulse_strength * 0.08)
	scale = Vector2(pulse, pulse)
	
	var travel_dir = (spawn_position - target_position).normalized()
	
	var target_hit_dist = player_node.GOOD_RADIUS
	var dist_from_center = max(0.0, target_hit_dist + (speed * time_left))
	global_position = target_position + travel_dir * dist_from_center

	if current_time > hit_time and global_position.distance_to(target_position) <= player_node.DEAD_ZONE_RADIUS:
		miss()
		return
	
	if (current_time - hit_time) > player_node.MISS_WINDOW:
		miss()
		return

	_try_deflect_from_shield_overlap()

func _on_area_entered(area: Area2D):
	if not active:
		return
	if area == null or not player_node:
		return
	if not player_node.get("player_cover"):
		return

	if area != player_node.player_cover:
		return
	if not player_node or not player_node.has_method("is_position_in_shield_arc"):
		return
	if not player_node.is_position_in_shield_arc(global_position):
		return

	var dist = global_position.distance_to(target_position)
	if dist > player_node.GOOD_RADIUS:
		return
	if dist < player_node.DEAD_ZONE_RADIUS:
		miss()
		return

	hit_note()

func hit_note():
	if not player_node or not active:
		return

	if not conductor:
		return

	var timing_error = timing_error_abs()
	if timing_error > player_node.MISS_WINDOW:
		return
		
	active = false

	if timing_error <= player_node.PERFECT_WINDOW:
		player_node.register_hit("Perfect")
		animate_hit(Color(0, 1, 0, 1), 1.5)
	elif timing_error <= player_node.GOOD_WINDOW:
		player_node.register_hit("Good")
		animate_hit(Color(1, 1, 0, 1), 1.25) 
	elif timing_error <= player_node.BAD_WINDOW:
		player_node.register_hit("Bad")
		animate_hit(Color(0.5, 0.5, 0.5, 1), 0.7)
	else:
		miss()
		
func animate_hit(target_color: Color, target_scale: float):
	modulate = target_color
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func miss():
	if not active:
		return
	active = false
	
	if player_node:
		player_node.register_hit("Miss")
		
	modulate = Color(0.2, 0.2, 0.2, 1.0) 
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector2(0, 50), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
