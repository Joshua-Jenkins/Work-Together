# RunTimer.gd
extends Node
class_name RunTimer

@export var perk_interval_sec: float = 10.0
signal perk_time

var t := 0.0
var next_t := 0.0

func _ready() -> void:
	next_t = perk_interval_sec

func _process(delta: float) -> void:
	t += delta
	if t >= next_t:
		next_t += perk_interval_sec
		emit_signal("perk_time")
