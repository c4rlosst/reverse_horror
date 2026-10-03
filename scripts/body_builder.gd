class_name BodyBuilder
extends RefCounted
## Low-poly people made from primitives: the family, and the thing in the
## house, which is the same build stretched and darkened.

static func person(color: Color, height: float = 1.75, lanky: bool = false, emission: Color = Color.BLACK) -> Node3D:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.0
	var scale_y := height / 1.75
	var arm_length := 0.8 * scale_y * (1.5 if lanky else 1.0)
	for side in [-1.0, 1.0]:
		_capsule(root, material, Vector3(side * 0.1, 0.43 * scale_y, 0.0), 0.09, 0.86 * scale_y)
		_capsule(root, material, Vector3(side * 0.28, 1.35 * scale_y - arm_length * 0.45, 0.0), 0.055, arm_length)
	var torso := _capsule(root, material, Vector3(0.0, 1.17 * scale_y, 0.0), 0.19, 0.72 * scale_y)
	torso.scale = Vector3(1.0, 1.0, 0.65)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.3 if lanky else 0.24
	head.mesh = sphere
	head.material_override = material
	head.position = Vector3(0.0, 1.62 * scale_y, 0.0)
	root.add_child(head)
	return root

static func _capsule(parent: Node3D, material: Material, position: Vector3, radius: float, height: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	mesh_instance.mesh = capsule
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance
