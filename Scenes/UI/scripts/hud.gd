# HUD.gd (Godot 4.5.1)
extends CanvasLayer
class_name HUD

@export var player_health_path: NodePath

@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var bar: ProgressBar = $MarginContainer/PanelContainer/VBoxContainer/HealthBar
@onready var label: Label = $MarginContainer/PanelContainer/VBoxContainer/HealthLabel



var health: PlayerHealth
var _display_hp: float = 0.0

func _ready() -> void:
	health = _find_player_health()
	if health == null:
		label.text = "HP: ?"
		return

	# Remove default percent text if it still shows
	bar.show_percentage = false

	_display_hp = float(health.hp)
	_apply_ui(health.hp, health.max_hp, true)


	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)

func _process(delta: float) -> void:
	if health == null:
		return

	# Smooth the bar value toward current HP
	var target := float(health.hp)
	_display_hp = lerpf(_display_hp, target, clampf(12.0 * delta, 0.0, 1.0))
	bar.value = _display_hp

func _find_player_health() -> PlayerHealth:
	if player_health_path != NodePath():
		return get_node_or_null(player_health_path) as PlayerHealth

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	var p := players[0] as Node
	return p.get_node_or_null("PlayerHealth") as PlayerHealth

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_apply_ui(hp, max_hp, false)
	_hit_flash()

func _apply_ui(hp: int, max_hp: int, instant: bool) -> void:
	bar.max_value = max_hp
	if instant:
		_display_hp = float(hp)
		bar.value = hp
	label.text = "HP %d / %d" % [hp, max_hp]

func _hit_flash() -> void:
	# Quick flash the panel when taking damage
	var t := create_tween()
	panel.modulate = Color(1, 0.6, 0.6, 1)  # light red tint
	t.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.18)

func _on_died() -> void:
	label.text = "HP 0 / %d" % int(bar.max_value)
