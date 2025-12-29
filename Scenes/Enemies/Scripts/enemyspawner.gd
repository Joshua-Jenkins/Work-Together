# EnemySpawner.gd (Godot 4.5.1)
extends Node
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var player_path: NodePath

# Spawn spacing
@export var min_enemy_separation: float = 40.0   # distance between enemies (try 32–64)
@export var min_x_separation: float = 40.0       # distance between spawn X markers

# Avoid spawning where the camera can see (Brotato feel)
@export var avoid_camera_view: bool = true
@export var camera_padding: float = 120.0

# Optional: assign Arena/Walls CollisionPolygon2D to force spawns inside your octagon
@export var walls_polygon_path: NodePath

@export var spawn_interval: float = 0.8
@export var max_alive: int = 25

# Telegraph ("X") settings
@export var telegraph_time: float = 0.6
@export var x_size: float = 28.0
@export var x_thickness: float = 4.0

# Spawn safety
@export var spawn_inset: float = 24.0           # keep away from edges/walls
@export var min_player_distance: float = 450.0  # recommended higher than 160
@export var tries_per_spawn: int = 80


@export var start_delay: float = 2.0
var _elapsed: float = 0.0


# Map is 1536x1024, centered ON, scale 1.0, position (0,0)
# Top-left = (-768, -512)
const MAP_RECT: Rect2 = Rect2(Vector2(-768, -512), Vector2(1536, 1024))

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cooldown: float = 0.0
var _walls_poly: CollisionPolygon2D

func _ready() -> void:
	_rng.randomize()
	_walls_poly = get_node_or_null(walls_polygon_path) as CollisionPolygon2D

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < start_delay:
		return	
	if enemy_scene == null:
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = spawn_interval

	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		return

	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return

	_spawn_with_telegraph(player)

func _spawn_with_telegraph(player: Node2D) -> void:
	var p: Vector2 = _pick_spawn_point(player)

	# show X marker
	var x := SpawnX.new()
	x.size = x_size
	x.thickness = x_thickness
	x.global_position = p
	get_tree().current_scene.add_child(x)

	# wait telegraph
	await get_tree().create_timer(telegraph_time).timeout

	if is_instance_valid(x):
		x.queue_free()

	# re-check conditions
	if enemy_scene == null:
		return
	if player == null or not is_instance_valid(player):
		return
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		return

	# spawn enemy
	var e := enemy_scene.instantiate() as Node2D
	if e == null:
		return

	get_parent().add_child(e)
	e.global_position = p

	if "player" in e:
		e.player = player

func _pick_spawn_point(player: Node2D) -> Vector2:
	var no_spawn: Rect2 = Rect2()
	if avoid_camera_view:
		no_spawn = _camera_no_spawn_rect()

	# If walls polygon assigned, pick inside polygon
	if _walls_poly != null and _walls_poly.polygon.size() >= 3:
		var poly_global := _get_polygon_global(_walls_poly)
		var bounds := _bounds_from_points(poly_global)

		for _i in range(tries_per_spawn):
			var candidate := _random_point_in_rect(bounds, spawn_inset)

			if avoid_camera_view and no_spawn.has_area() and no_spawn.has_point(candidate):
				continue
			if not Geometry2D.is_point_in_polygon(candidate, poly_global):
				continue
			if candidate.distance_to(player.global_position) < min_player_distance:
				continue
			if not _is_spawn_clear(candidate):
				continue

			return candidate

	# Fallback: spawn inside map rect
	for _i in range(tries_per_spawn):
		var candidate2 := _random_point_in_rect(MAP_RECT, spawn_inset)

		if avoid_camera_view and no_spawn.has_area() and no_spawn.has_point(candidate2):
			continue
		if candidate2.distance_to(player.global_position) < min_player_distance:
			continue
		if not _is_spawn_clear(candidate2):
			continue

		return candidate2

	return MAP_RECT.get_center()

func _random_point_in_rect(r: Rect2, inset: float) -> Vector2:
	var i: float = clampf(inset, 0.0, min(r.size.x, r.size.y) * 0.49)
	return Vector2(
		_rng.randf_range(r.position.x + i, r.position.x + r.size.x - i),
		_rng.randf_range(r.position.y + i, r.position.y + r.size.y - i)
	)

func _get_polygon_global(poly: CollisionPolygon2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly.polygon:
		out.append(poly.to_global(p))
	return out

func _bounds_from_points(points: PackedVector2Array) -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for p in points:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _is_spawn_clear(p: Vector2) -> bool:
	var min_enemy_d2 := min_enemy_separation * min_enemy_separation
	var min_x_d2 := min_x_separation * min_x_separation

	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e == null:
			continue
		if e.global_position.distance_squared_to(p) < min_enemy_d2:
			return false

	for n in get_tree().get_nodes_in_group("spawn_markers"):
		var x := n as Node2D
		if x == null:
			continue
		if x.global_position.distance_squared_to(p) < min_x_d2:
			return false

	return true

func _camera_no_spawn_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()

	var view_px := get_viewport().get_visible_rect().size
	var view_world := view_px * cam.zoom
	return Rect2(cam.global_position - view_world * 0.5, view_world).grow(camera_padding)

# --- Simple "X" indicator drawn in code ---
class SpawnX:
	extends Node2D

	var size: float = 28.0
	var thickness: float = 4.0

	func _ready() -> void:
		add_to_group("spawn_markers")
		z_index = 5
		queue_redraw()

	func _draw() -> void:
		var h := size * 0.5
		var col := Color(1, 0.2, 0.2, 0.95)
		draw_line(Vector2(-h, -h), Vector2(h, h), col, thickness, true)
		draw_line(Vector2(-h, h), Vector2(h, -h), col, thickness, true)
