# Gun.gd (Godot 4.5.1)
extends Node2D
class_name Gun

@export var gun_texture: Texture2D

@export var fire_interval: float = 0.30
@export var aim_range: float = 600.0

@export var orbit_radius: float = 24.0       # where the gun sits from player center
@export var muzzle_distance: float = 34.0    # where bullets spawn from player center (along aim dir)

@export var bullet_speed: float = 800.0
@export var bullet_damage: int = 2
@export var bullet_lifetime: float = 1.0
@export var bullet_radius: float = 3.0

@export var smooth_rotate: float = 0.0 # 0 = instant; try 18 for smoothing

@onready var pivot: Node2D = $Pivot
@onready var gun_sprite: Sprite2D = $Pivot/GunSprite
@onready var muzzle: Marker2D = $Pivot/Muzzle

var _cooldown: float = 0.0

func _ready() -> void:
	# Apply texture if provided
	if gun_texture != null:
		gun_sprite.texture = gun_texture

	# Keep sprite + muzzle positioned correctly from exports
	gun_sprite.position = Vector2(orbit_radius, 0)
	muzzle.position = Vector2(muzzle_distance, 0)

func _process(delta: float) -> void:
	var player := owner as Node2D
	if player == null:
		return

	var aim_dir := _get_aim_dir(player)
	_aim_at(aim_dir, delta)

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = fire_interval

	_spawn_bullet(aim_dir)

func _get_aim_dir(player: Node2D) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_d2 := INF
	var p := player.global_position
	var r2 := aim_range * aim_range

	for n in enemies:
		var e := n as Node2D
		if e == null: continue
		var d2 := p.distance_squared_to(e.global_position)
		if d2 < best_d2 and d2 <= r2:
			best_d2 = d2
			best = e

	if best != null:
		return (best.global_position - p).normalized()

	# fallback: player's facing_dir if you have it
	if "facing_dir" in player:
		var fd: Vector2 = player.facing_dir
		if fd.length() > 0.001:
			return fd.normalized()

	return Vector2.RIGHT

func _aim_at(dir: Vector2, delta: float) -> void:
	if dir.length() < 0.001:
		return

	var target_rot := dir.angle()

	if smooth_rotate > 0.0:
		pivot.rotation = lerp_angle(pivot.rotation, target_rot, clampf(smooth_rotate * delta, 0.0, 1.0))
	else:
		pivot.rotation = target_rot

	# Optional: keep gun from being upside down (uncomment if you want)
	# var a := wrapf(pivot.rotation, -PI, PI)
	# pivot.scale.y = -1.0 if abs(a) > PI * 0.5 else 1.0

func _spawn_bullet(dir: Vector2) -> void:
	var b := Bullet.new()
	b.global_position = muzzle.global_position
	b.dir = dir
	b.speed = bullet_speed
	b.damage = bullet_damage
	b.life = bullet_lifetime
	b.radius = bullet_radius
	get_tree().current_scene.add_child(b)

class Bullet:
	extends Area2D

	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 800.0
	var damage: int = 2
	var life: float = 1.0
	var radius: float = 3.0

	func _ready() -> void:
		monitoring = true
		monitorable = true

		# Bullet on Layer 4, detects Enemy Layer 2
		collision_layer = 1 << 3   # Layer 4
		collision_mask  = 1 << 1   # Layer 2 (enemies)

		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = radius
		cs.shape = shape
		add_child(cs)

		body_entered.connect(_on_body_entered)
		queue_redraw()

	func _draw() -> void:
		# simple visible bullet
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 0.2, 1.0))

	func _physics_process(delta: float) -> void:
		global_position += dir * speed * delta
		life -= delta
		if life <= 0.0:
			queue_free()

	func _on_body_entered(body: Node) -> void:
		if body != null and body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
