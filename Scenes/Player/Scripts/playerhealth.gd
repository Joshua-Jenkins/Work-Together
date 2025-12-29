# PlayerHealth.gd (Godot 4.5.1)
extends Node
class_name PlayerHealth

@export var max_hp: int = 20
@export var contact_damage: int = 1
@export var i_frame_time: float = 0.45
@export var contact_cooldown: float = 0.35  # tweak 0.25–0.6
var _hurt_cd: float = 0.0

@export var hurtbox_path: NodePath = "../HurtBox"
signal hp_changed(hp: int, max_hp: int)
signal died

var hp: int
var _invuln: float = 0.0

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var hurtbox: Area2D = get_node(hurtbox_path) as Area2D

func _ready() -> void:
	hp = max_hp
	if player:
		player.add_to_group("player")

	# Hurtbox detects enemies (Layer 2)
	if hurtbox:
		hurtbox.collision_layer = 0
		hurtbox.collision_mask = 1 << 1
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	emit_signal("hp_changed", hp, max_hp)

func _process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)

func _on_hurtbox_body_entered(body: Node) -> void:
	if _invuln > 0.0:
		return
	if body == null or not body.is_in_group("enemies"):
		return
	if _hurt_cd > 0.0:
		return
	take_damage(contact_damage)
	print("Hurtbox touched:", body.name, " groups:", body.get_groups())


func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	_invuln = i_frame_time
	emit_signal("hp_changed", hp, max_hp)
	print("Player HP:", hp)

	if hp <= 0:
		emit_signal("died")
		get_tree().call_deferred("reload_current_scene")
