# PlayerStats.gd (Godot 4.5.1)
extends Node
class_name PlayerStats

# Multipliers (start at 1.0)
var weapon_damage_mult: float = 1.0
var weapon_fire_rate_mult: float = 1.0
var move_speed_mult: float = 1.0
var bullet_speed_mult: float = 1.0
var knockback_mult: float = 1.0
var pickup_range_mult: float = 1.0
var materials_mult: float = 1.0
var damage_taken_mult: float = 1.0

# Additive stats
var max_hp_add: int = 0
var regen_add: float = 0.0

func reset() -> void:
	weapon_damage_mult = 1.0
	weapon_fire_rate_mult = 1.0
	move_speed_mult = 1.0
	bullet_speed_mult = 1.0
	knockback_mult = 1.0
	pickup_range_mult = 1.0
	materials_mult = 1.0
	damage_taken_mult = 1.0
	max_hp_add = 0
	regen_add = 0.0
