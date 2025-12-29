# Player.gd (Godot 4.5.1)
# Top-down Brotato-style movement: snappy accel + decel, supports keyboard + gamepad.
extends CharacterBody2D


@export var max_speed: float = 360.0
@export var acceleration: float = 2600.0   # how fast you reach max speed
@export var deceleration: float = 3200.0   # how fast you stop when no input
@export var input_deadzone: float = 0.15   # for analog sticks
@onready var sprite: Sprite2D = $Sprite2D
@export var flip_when_idle : bool = true

@onready var health: PlayerHealth = $PlayerHealth

# Optional: if you want to keep player inside a rectangle (leave empty to disable)
@export var clamp_to_rect: bool = false
@export var world_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080))

var move_dir: Vector2 = Vector2.ZERO      # current input direction (normalized)
var facing_dir: Vector2 = Vector2.RIGHT   # last non-zero move direction (useful for aiming visuals)


	
func _ready() -> void:
	$PlayerHealth.hp_changed.connect(_on_hp_changed)
	pass

func _physics_process(delta: float) -> void:
	_read_move_input()
	_apply_topdown_movement(delta)
	_apply_optional_clamp()
	_update_sprite_flip()

func _read_move_input() -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down", input_deadzone)
	move_dir = raw.normalized() if raw.length() > 0.0 else Vector2.ZERO

	if move_dir != Vector2.ZERO:
		facing_dir = move_dir

func _apply_topdown_movement(delta: float) -> void:
	if move_dir != Vector2.ZERO:
		# Accelerate toward target velocity
		var target := move_dir * max_speed
		velocity = velocity.move_toward(target, acceleration * delta)
	else:
		# Decelerate to a stop
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	move_and_slide()

func _apply_optional_clamp() -> void:
	if not clamp_to_rect:
		return
	global_position.x = clampf(global_position.x, world_rect.position.x, world_rect.position.x + world_rect.size.x)
	global_position.y = clampf(global_position.y, world_rect.position.y, world_rect.position.y + world_rect.size.y)

func _update_sprite_flip() -> void:
	# Flip based on last facing direction (or only when moving)
	var dir := facing_dir if flip_when_idle else move_dir
	if dir == Vector2.ZERO:
		return
	if abs(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0

func _on_hp_changed(hp: int, max_hp: int) -> void:
	print("HP UI:", hp, "/", max_hp)
