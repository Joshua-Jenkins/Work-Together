# Enemy.gd (Godot 4.5.1) — paste whole script
extends CharacterBody2D
class_name Enemy


@onready var sprite: Sprite2D = $Sprite2D
@export var move_speed: float = 150.0
@export var max_hp: int = 6

# --- Keep enemies from sitting ON the player ---
@export var stop_distance: float = 18.0              # enemy stops trying to move closer than this
@export var player_repulsion_radius: float = 28.0    # if closer than this, push away
@export var player_repulsion_strength: float = 360.0

# --- Keep enemies from becoming one blob (light separation) ---
@export var enemy_repulsion_radius: float = 26.0
@export var enemy_repulsion_strength: float = 220.0
@export var max_neighbors_checked: int = 10          # cap for performance

# Smoothness (optional)
@export var steering: float = 2200.0   # higher = snappier velocity changes

@export var hit_flash_time: float = 0.08
@export var knockback_decay: float = 1400.0  # how fast knockback fades (px/sec^2)

var knockback_vel: Vector2 = Vector2.ZERO
var _flash_tween: Tween



var hp: int
var player: Node2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

	# Layers (recommended setup)
	# Layer 1 = Player, Layer 2 = Enemies, Layer 3 = Walls
	collision_layer = 1 << 1                 # Enemy on Layer 2
	collision_mask  = (1 << 1) | (1 << 2)    # Collide with Enemies + Walls (NOT Player)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = velocity.move_toward(Vector2.ZERO, steering * delta)
		velocity += knockback_vel
		# decay knockback
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, knockback_decay * delta)
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir_to_player := to_player / dist if dist > 0.001 else Vector2.ZERO

	# 1) Chase, but don't try to occupy the same point as the player
	var chase_dir := Vector2.ZERO
	if dist > stop_distance:
		chase_dir = dir_to_player

	# 2) Repel if too close (prevents "sticking" / riding the player)
	var repel_player := Vector2.ZERO
	if dist < player_repulsion_radius and dist > 0.001:
		var t := 1.0 - (dist / player_repulsion_radius)  # 0..1
		repel_player = -dir_to_player * t

	# 3) Light separation from nearby enemies (prevents clumping)
	var repel_enemies := Vector2.ZERO
	var checked := 0
	var rr2 := enemy_repulsion_radius * enemy_repulsion_radius

	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self:
			continue
		var e := n as Node2D
		if e == null:
			continue

		checked += 1
		if checked > max_neighbors_checked:
			break

		var away := global_position - e.global_position
		var d2 := away.length_squared()
		if d2 > 0.0001 and d2 < rr2:
			var d := sqrt(d2)
			var t2 := 1.0 - (d / enemy_repulsion_radius)
			repel_enemies += (away / d) * t2

	# Combine forces
	var desired := chase_dir * move_speed
	desired += repel_player * player_repulsion_strength
	desired += repel_enemies * enemy_repulsion_strength

	# Cap speed
	if desired.length() > move_speed:
		desired = desired.normalized() * move_speed

	velocity = velocity.move_toward(desired, steering * delta)
	move_and_slide()
	
	
func on_hit(push_dir: Vector2, force: float) -> void:
	# 1) Flash
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()

	sprite.modulate = Color(1, 1, 1, 1)  # base
	sprite.self_modulate = Color(2.2, 2.2, 2.2, 1)  # bright pop
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "self_modulate", Color(1, 1, 1, 1), hit_flash_time)

	# 2) Knockback impulse
	if push_dir.length() > 0.001:
		knockback_vel += push_dir.normalized() * force
	

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
