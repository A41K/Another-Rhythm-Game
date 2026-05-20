extends Area2D

@export var speed: float = 200.0
var target_position: Vector2 = Vector2.ZERO
var player_node: Node2D
var active: bool = true

func _ready():
    player_node = get_tree().get_first_node_in_group("Player")
    if player_node:
        target_position = player_node.global_position
        
    mouse_entered.connect(_on_mouse_entered)

func _process(delta):
    if not active or not player_node:
        return
        
    var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.1
    scale = Vector2(pulse, pulse)
        
    var direction = (target_position - global_position).normalized()
    global_position += direction * speed * delta
    
    var dist = global_position.distance_to(target_position)
    if dist < 10.0:
        miss()

func _on_mouse_entered():
    if active:
        hit_note()

func hit_note():
    if not player_node or not active:
        return
        
    active = false
    var dist = global_position.distance_to(target_position)
    
    if dist <= player_node.PERFECT_RADIUS:
        player_node.register_hit("Perfect")
        animate_hit(Color(0, 1, 0, 1), 1.5)
    elif dist <= player_node.GOOD_RADIUS:
        player_node.register_hit("Good")
        animate_hit(Color(1, 1, 0, 1), 1.25) 
    else:
        player_node.register_hit("Bad")
        animate_hit(Color(0.5, 0.5, 0.5, 1), 0.7) 
        
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