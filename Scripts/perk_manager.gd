# perk_manager.gd (Godot 4.5.1)
extends Node
class_name PerkManager

signal perk_choices_ready(ids: Array[String])
signal perk_applied(id: String, new_stack: int)

@export var choices_count: int = 4

# --- Perk list (dictionary-driven) ---
const PERKS: Dictionary = {
	"damage_up": {"title":"Damage Up","desc":"+15% weapon damage","weight":10.0,"max_stacks":10,"mods":{"weapon_damage_mult":1.15}},
	"fire_rate_up": {"title":"Overclock","desc":"+12% fire rate","weight":10.0,"max_stacks":10,"mods":{"weapon_fire_rate_mult":1.12}},
	"move_speed_up": {"title":"Light Feet","desc":"+10% move speed","weight":9.0,"max_stacks":8,"mods":{"move_speed_mult":1.10}},
	"max_hp_up": {"title":"Toughness","desc":"+5 max HP","weight":8.0,"max_stacks":6,"mods":{"max_hp_add":5}},
	"regen": {"title":"Regeneration","desc":"+0.3 HP/sec","weight":7.0,"max_stacks":8,"mods":{"regen_add":0.3}},
	"armor": {"title":"Armor","desc":"Take 8% less damage","weight":7.0,"max_stacks":8,"mods":{"damage_taken_mult":0.92}},
	"knockback_up": {"title":"Heavy Rounds","desc":"+20% knockback dealt","weight":7.0,"max_stacks":8,"mods":{"knockback_mult":1.20}},
	"bullet_speed_up": {"title":"High Velocity","desc":"+18% bullet speed","weight":7.0,"max_stacks":8,"mods":{"bullet_speed_mult":1.18}},
	"pickup_range_up": {"title":"Magnet","desc":"+20% pickup range","weight":8.0,"max_stacks":8,"mods":{"pickup_range_mult":1.20}},
	"materials_up": {"title":"Lucky Finds","desc":"+12% materials gained","weight":6.0,"max_stacks":8,"mods":{"materials_mult":1.12}},
}

var stacks: Dictionary = {} # id -> int
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func can_take(id: String) -> bool:
	var perk: Dictionary = _get_perk(id)
	if perk.is_empty():
		return false
	var s: int = int(stacks.get(id, 0))
	var max_s: int = int(perk.get("max_stacks", 1))
	return s < max_s

func roll_choices() -> Array[String]:
	var pool: Array[String] = []
	for k in PERKS.keys():
		var id: String = str(k)
		if can_take(id):
			pool.append(id)

	var picks: Array[String] = []
	var want: int = min(choices_count, pool.size())

	for i in range(want):
		var chosen: String = _weighted_pick(pool)
		if chosen == "":
			break
		picks.append(chosen)
		pool.erase(chosen)

	return picks

func apply_perk(id: String, stats: Node) -> void:
	# stats should be your PlayerStats node (or any node with those properties)
	if stats == null:
		return

	var perk: Dictionary = _get_perk(id)
	if perk.is_empty():
		return
	if not can_take(id):
		return

	var s: int = int(stacks.get(id, 0)) + 1
	stacks[id] = s

	var mods: Dictionary = perk.get("mods", {}) as Dictionary
	for key_v in mods.keys():
		var key: String = str(key_v)
		var v: Variant = mods.get(key)

		if not stats.has_method("get") or not stats.has_method("set"):
			continue

		var cur: Variant = stats.get(key)

		# Multipliers end with _mult
		if key.ends_with("_mult"):
			stats.set(key, float(cur) * float(v))
		else:
			# Additives (int or float)
			if typeof(cur) == TYPE_INT:
				stats.set(key, int(cur) + int(v))
			else:
				stats.set(key, float(cur) + float(v))

	emit_signal("perk_applied", id, s)

# --- helpers ---

func _get_perk(id: String) -> Dictionary:
	var perk_v: Variant = PERKS.get(id, {})
	if perk_v is Dictionary:
		return perk_v as Dictionary
	return {}

func _weighted_pick(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""

	var total: float = 0.0
	for id in pool:
		var perk: Dictionary = _get_perk(id)
		total += float(perk.get("weight", 1.0))

	if total <= 0.0:
		return pool[0]

	var r: float = _rng.randf() * total
	var acc: float = 0.0
	for id in pool:
		var perk2: Dictionary = _get_perk(id)
		acc += float(perk2.get("weight", 1.0))
		if r <= acc:
			return id

	return pool[pool.size() - 1]
