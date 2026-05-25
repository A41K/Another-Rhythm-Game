extends Node2D

const DEAD_ZONE_RADIUS: float = 40.0
const PERFECT_RADIUS: float = 70.0
const GOOD_RADIUS: float = 100.0
const PERFECT_WINDOW: float = 0.050
const GOOD_WINDOW: float = 0.100
const BAD_WINDOW: float = 0.160
const MISS_WINDOW: float = 0.220
const SCORE_PERFECT: int = 1000
const SCORE_GOOD: int = 700
const SCORE_BAD: int = 300
const SCORE_MISS_PENALTY: int = 500
const COVER_RADIUS_FROM_CENTER: float = 35.0
const SHIELD_ARC_DEGREES: float = 165.0
const SHIELD_HITBOX_RADIUS: float = 24.0

var combo: int = 0
var highest_combo: int = 0
var last_cover_dir: Vector2 = Vector2.UP
var score: int = 0
var miss_count: int = 0

var total_notes: int = 0
var total_accuracy_score: float = 0.0

@onready var eyes: Sprite2D = $Eyes
@onready var player_cover: Area2D = $PlayerCover
@onready var cover_sprite: Sprite2D = $PlayerCover/CoverSprite
@onready var cover_hitbox: CollisionShape2D = $PlayerCover/CollisionShape2D
const EYES_MAX_DIST: float = 15.0
const EYES_SPEED: float = 15.0

@onready var accuracy_label: Label = get_parent().get_node_or_null("Percentage")
@onready var combo_label: Label = get_parent().get_node_or_null("Combo")
@onready var score_label: Label = get_parent().get_node_or_null("ScoreValue")
var combo_tween: Tween
var original_combo_pos: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("Player")
	if player_cover:
		player_cover.monitoring = true
		player_cover.monitorable = true
		player_cover.collision_layer = 1
		player_cover.collision_mask = 1
		player_cover.add_to_group("Deflector")
	if cover_hitbox and cover_hitbox.shape is CircleShape2D:
		(cover_hitbox.shape as CircleShape2D).radius = SHIELD_HITBOX_RADIUS
	queue_redraw()
	
	if combo_label:
		original_combo_pos = combo_label.position
		combo_label.text = "0"
		
	update_accuracy_label()
	update_score_label()

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var offset = (mouse_pos - global_position)

	var cover_dir = offset.normalized()
	if cover_dir == Vector2.ZERO:
		cover_dir = last_cover_dir
	else:
		last_cover_dir = cover_dir

	var target_cover_pos = cover_dir * COVER_RADIUS_FROM_CENTER
	if player_cover:
		player_cover.position = target_cover_pos
	if cover_sprite:
		cover_sprite.rotation = target_cover_pos.angle() + PI * 0.5
	
	offset = offset * 0.05 
	
	if offset.length() > EYES_MAX_DIST:
		offset = offset.normalized() * EYES_MAX_DIST
		
	if eyes:
		eyes.position = eyes.position.lerp(offset, EYES_SPEED * delta)

func is_position_in_shield_arc(world_pos: Vector2) -> bool:
	if not player_cover:
		return false

	var shield_forward = player_cover.position.normalized()
	if shield_forward == Vector2.ZERO:
		shield_forward = Vector2.UP

	var note_dir = (world_pos - global_position).normalized()
	if note_dir == Vector2.ZERO:
		return false

	var half_arc_rad = deg_to_rad(SHIELD_ARC_DEGREES * 0.5)
	var cos_threshold = cos(half_arc_rad)
	return shield_forward.dot(note_dir) >= cos_threshold

func try_hit_note(dir: int):
	var notes = get_tree().get_nodes_in_group("Notes")
	var best_note = null
	var best_score = 9999.0
	
	for note in notes:
		if note.active and is_note_in_direction(note, dir):
			if not note.conductor:
				continue

			var time_delta = float(note.hit_time) - float(note.conductor.song_position)
			var time_error = abs(time_delta)
			if time_error > MISS_WINDOW:
				continue

			var score = time_error + (0.015 if time_delta > 0.0 else 0.0)
			if score < best_score:
				best_score = score
				best_note = note
				
	if best_note:
		best_note.hit_note()

func is_note_in_direction(note, dir: int) -> bool:
	if note.has_method("time_until_hit"):
		return int(note.direction) == dir

	var note_dir = (note.spawn_position - global_position).normalized()
	var expected_dir = Vector2.ZERO
	if dir == 0: expected_dir = Vector2(0, -1)
	elif dir == 1: expected_dir = Vector2(1, 0)
	elif dir == 2: expected_dir = Vector2(0, 1)
	elif dir == 3: expected_dir = Vector2(-1, 0)
	return note_dir.dot(expected_dir) > 0.5

func _draw():
	# Draw good circle (Yellow)
	draw_circle(Vector2.ZERO, GOOD_RADIUS, Color(1, 1, 0, 0.2))
	# Draw dead zone (Red)
	draw_circle(Vector2.ZERO, DEAD_ZONE_RADIUS, Color(1, 0.1, 0.1, 0.5))

func register_hit(quality: String):
	total_notes += 1
	var combo_increased = false
	var score_delta := 0
	
	if quality == "Perfect":
		combo += 1
		combo_increased = true
		total_accuracy_score += 1.0
		score_delta = SCORE_PERFECT
		if combo > highest_combo:
			highest_combo = combo
	elif quality == "Good":
		combo += 1
		combo_increased = true
		total_accuracy_score += 0.75
		score_delta = SCORE_GOOD
		if combo > highest_combo:
			highest_combo = combo
	elif quality == "Bad":
		combo = 0
		total_accuracy_score += 0.25
		score_delta = SCORE_BAD
	else: # Miss
		combo = 0
		total_accuracy_score += 0.0
		score_delta = -SCORE_MISS_PENALTY
		miss_count += 1

	score = max(0, score + score_delta)
		
	update_accuracy_label()
	update_combo_label(combo_increased)
	update_score_label()

func update_combo_label(increased: bool):
	if not combo_label:
		combo_label = get_parent().get_node_or_null("Combo")
		if not combo_label: return
		if original_combo_pos == Vector2.ZERO:
			original_combo_pos = combo_label.position
			
	combo_label.text = str(combo)
	combo_label.pivot_offset = combo_label.size / 2.0
	
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	
	if increased:
		combo_label.position = original_combo_pos
		combo_label.modulate = Color(1, 1, 1, 1)
		
		combo_label.scale = Vector2(1.6, 1.6)
		combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		combo_label.scale = Vector2(1.0, 1.0)
		combo_label.modulate = Color(1, 0.2, 0.2, 1)
		
		combo_tween.tween_property(combo_label, "position:x", original_combo_pos.x + 10, 0.05)
		combo_tween.tween_property(combo_label, "position:x", original_combo_pos.x - 10, 0.05)
		combo_tween.tween_property(combo_label, "position:x", original_combo_pos.x + 8, 0.05)
		combo_tween.tween_property(combo_label, "position:x", original_combo_pos.x - 8, 0.05)
		combo_tween.tween_property(combo_label, "position:x", original_combo_pos.x, 0.05)
		
		var color_tween = create_tween()
		color_tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.5)

func update_accuracy_label():
	if accuracy_label == null:
		accuracy_label = get_parent().get_node_or_null("Percentage")
		if accuracy_label == null: return
		
	if total_notes == 0:
		accuracy_label.text = "100.0%"
	else:
		var pct = (total_accuracy_score / float(total_notes)) * 100.0
		accuracy_label.text = "%.1f" % snapped(pct, 0.1) + "%"

func update_score_label():
	if score_label == null:
		score_label = get_parent().get_node_or_null("ScoreValue")
		if score_label == null:
			return

	score_label.text = str(score)

func get_final_score() -> int:
	return score

func get_miss_count() -> int:
	return miss_count
