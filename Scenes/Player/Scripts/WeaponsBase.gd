extends Node2D
class_name WeaponBase

enum TargetMode { NEAREST_ENEMY, FACING_DIR_ONLY }

@export var target_mode: TargetMode = TargetMode.NEAREST_ENEMY
@export var enemy_group: StringName = &"enemies"

@export var fire_interval: float = 0.30
@export var aim_range: float = 650.0
@export var max_targets_checked: int = 60  # perf cap
@export var start_delay : float = 0.0
# Visual/orbit offsets (assumes gun art faces RIGHT by default)
@export var orbit_radius: float = 24.0
@export var muzzle_distance: float = 34.0

# Aim behavior
@export var smooth_rotate: float = 0.0   # 0 = instant; try 18 for smoothing
@export var keep_upright: bool = true    # prevents upside-down gun when aiming left

# Default bullet stats (you can override _do_fire for custom patterns)
@export var bullet_speed: float = 850.0
@export var bullet_damage: int = 2
@export var bullet_lifetime: float = 1.0
@export var bullet_radius: float = 3.0

# Node paths (override if your weapon scene uses different names)
@export var pivot_path: NodePath = ^"Pivot"
@export var sprite_path: NodePath = ^"Pivot/Sprite2D"
@export var muzzle_path: NodePath = ^"Pivot/Muzzle"

@export var knockback_force: float = 260.0


var _cooldown: float = 0.0

@onready var pivot: Node2D = get_node(pivot_path) as Node2D
@onready var gun_sprite: Sprite2D = get_node(sprite_path) as Sprite2D
@onready var muzzle: Marker2D = get_node(muzzle_path) as Marker2D

func _ready() -> void:
	# Keep sprite/muzzle aligned with exported offsets (easy tuning)
	if gun_sprite:
		gun_sprite.position = Vector2(orbit_radius, 0.0)
	if muzzle:
		muzzle.position = Vector2(muzzle_distance, 0.0)
	_cooldown = start_delay

func _process(delta: float) -> void:
	var player := owner as Node2D
	if player == null:
		return

	var aim_dir := _get_aim_dir(player)
	_apply_aim(aim_dir, delta)

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = fire_interval

	_do_fire(aim_dir)

# --- Aiming / targeting ---

func _get_aim_dir(player: Node2D) -> Vector2:
	if target_mode == TargetMode.FACING_DIR_ONLY:
		return _fallback_dir(player)

	# NEAREST_ENEMY
	var enemies := get_tree().get_nodes_in_group(enemy_group)
	var best: Node2D = null
	var best_d2 := INF
	var p := player.global_position
	var r2 := aim_range * aim_range

	var checked := 0
	for n in enemies:
		var e := n as Node2D
		if e == null:
			continue
		checked += 1
		if checked > max_targets_checked:
			break

		var d2 := p.distance_squared_to(e.global_position)
		if d2 <= r2 and d2 < best_d2:
			best_d2 = d2
			best = e

	if best != null:
		var dir := (best.global_position - p)
		if dir.length() > 0.001:
			return dir.normalized()

	return _fallback_dir(player)

func _fallback_dir(player: Node2D) -> Vector2:
	if "facing_dir" in player:
		var fd: Vector2 = player.facing_dir
		if fd.length() > 0.001:
			return fd.normalized()
	return Vector2.RIGHT

func _apply_aim(dir: Vector2, delta: float) -> void:
	if pivot == null or dir.length() < 0.001:
		return

	var target_rot := dir.angle()

	# Keep upright by flipping vertically when aiming left
	if keep_upright:
		var a: float = wrapf(target_rot, -PI, PI)
		var aiming_left: bool = abs(a) > (PI * 0.5)

		pivot.scale.y = -1.0 if aiming_left else 1.0
	else:
		pivot.scale.y = 1.0

	if smooth_rotate > 0.0:
		pivot.rotation = lerp_angle(pivot.rotation, target_rot, clampf(smooth_rotate * delta, 0.0, 1.0))
	else:
		pivot.rotation = target_rot

# --- Firing ---

# Override this in child weapons for shotgun bursts, spread, beams, etc.
func _do_fire(aim_dir: Vector2) -> void:
	_spawn_bullet(muzzle.global_position if muzzle else global_position, aim_dir, bullet_speed, bullet_damage, bullet_lifetime, bullet_radius)

func _spawn_bullet(pos: Vector2, dir: Vector2, speed: float, damage: int, life: float, radius: float) -> void:
	var b := Bullet.new()
	b.global_position = pos
	b.dir = dir
	b.speed = speed
	b.damage = damage
	b.life = life
	b.radius = radius
	b.knockback_force = knockback_force
	get_tree().current_scene.add_child(b)

# Simple built-in bullet. Later you can swap to a Bullet.tscn.
class Bullet:
	extends Area2D

	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 850.0
	var damage: int = 2
	var life: float = 1.0
	var radius: float = 3.0
	var knockback_force : float = 0.0

	func _ready() -> void:
		monitoring = true
		monitorable = true

		# Bullet on Layer 4, detects Enemy Layer 2
		collision_layer = 1 << 3
		collision_mask  = 1 << 1

		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		cs.shape = shape
		add_child(cs)

		body_entered.connect(_on_body_entered)
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 0.2, 1.0))

	func _physics_process(delta: float) -> void:
		global_position += dir * speed * delta
		life -= delta
		if life <= 0.0:
			queue_free()

	func _on_body_entered(body: Node) -> void:
		if body != null:
			if body.has_method("on_hit") and knockback_force > 0.0:
				body.on_hit(dir, knockback_force)
			if body.has_method("take_damage"):
				body.take_damage(damage)
		queue_free()
