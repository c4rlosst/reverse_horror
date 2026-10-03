class_name FlickeringLight
extends OmniLight3D
## A room light that can be switched, dimmed on a tween, and made to flicker
## when something frightening is close.

@export var base_energy: float = 1.0
@export var ambient_flicker: float = 0.0

var flicker_amount: float = 0.0
var level: float = 1.0
var switched_on: bool = true

func _process(_delta: float) -> void:
	var jitter := 1.0
	var amount := maxf(flicker_amount, ambient_flicker)
	if amount > 0.01 and randf() < amount * 0.6:
		jitter = randf_range(0.0, 0.6)
	light_energy = base_energy * level * jitter

func switch(on: bool, seconds: float = 0.2) -> void:
	switched_on = on
	create_tween().tween_property(self, "level", 1.0 if on else 0.0, seconds)

func dim_to(target: float, seconds: float) -> void:
	create_tween().tween_property(self, "level", target, seconds)
