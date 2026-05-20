extends Node2D

const PERFECT_RADIUS: float = 40.0
const GOOD_RADIUS: float = 90.0

var combo: int = 0
var highest_combo: int = 0

var total_notes: int = 0
var total_accuracy_score: float = 0.0

@onready var eyes: Sprite2D = $Eyes
const EYES_MAX_DIST: float = 15.0
const EYES_SPEED: float = 15.0

@onready var accuracy_label: Label = get_parent().get_node_or_null("Percentage")
@onready var combo_label: Label = get_parent().get_node_or_null("Combo")
var combo_tween: Tween
var original_combo_pos: Vector2 = Vector2.ZERO

func _ready():
    add_to_group("Player")
    queue_redraw()
    
    if combo_label:
        original_combo_pos = combo_label.position
        combo_label.text = "0"
        
    update_accuracy_label()

func _process(delta):
    var mouse_pos = get_global_mouse_position()
    var offset = (mouse_pos - global_position)
    
    offset = offset * 0.05 
    
    if offset.length() > EYES_MAX_DIST:
        offset = offset.normalized() * EYES_MAX_DIST
        
    if eyes:
        eyes.position = eyes.position.lerp(offset, EYES_SPEED * delta)

func _draw():
    # Draw perfect circle (Green)
    draw_circle(Vector2.ZERO, PERFECT_RADIUS, Color(0, 1, 0, 0.3))
    # Draw good circle (Yellow)
    draw_circle(Vector2.ZERO, GOOD_RADIUS, Color(1, 1, 0, 0.3))

func register_hit(quality: String):
    total_notes += 1
    var combo_increased = false
    
    if quality == "Perfect":
        combo += 1
        combo_increased = true
        total_accuracy_score += 1.0
        if combo > highest_combo:
            highest_combo = combo
    elif quality == "Good":
        combo += 1
        combo_increased = true
        total_accuracy_score += 0.75
        if combo > highest_combo:
            highest_combo = combo
    elif quality == "Bad":
        combo = 0
        total_accuracy_score += 0.25
    else: # Miss
        combo = 0
        total_accuracy_score += 0.0
        
    update_accuracy_label()
    update_combo_label(combo_increased)

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