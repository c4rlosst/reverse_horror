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

## The thing in the house. Stooped, too tall, too thin, with arms that reach
## the floor. Joints are pivots stored under the "parts" meta so
## CreatureAnimator can pose them.
static func creature() -> Node3D:
	var root := Node3D.new()
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.05, 0.055, 0.07)
	skin.roughness = 0.3
	skin.emission_enabled = true
	skin.emission = Color(0.025, 0.035, 0.055)
	skin.rim_enabled = true
	skin.rim = 0.9
	skin.rim_tint = 0.7
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.5, 0.52, 0.5)
	bone.roughness = 0.5
	bone.emission_enabled = true
	bone.emission = Color(0.08, 0.09, 0.1)
	var hollow := StandardMaterial3D.new()
	hollow.albedo_color = Color(0.0, 0.0, 0.0)
	hollow.roughness = 1.0
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.7, 0.8, 0.9)
	eye.emission_enabled = true
	eye.emission = Color(0.8, 0.92, 1.0)
	eye.emission_energy_multiplier = 2.2

	var parts := {}
	var hips := _pivot(root, Vector3(0, 0.95, 0))
	parts["hips"] = hips
	for side in [-1.0, 1.0]:
		var tag := "l" if side < 0.0 else "r"
		var thigh := _pivot(hips, Vector3(side * 0.11, 0, 0))
		_capsule(thigh, skin, Vector3(0, -0.26, 0), 0.055, 0.56)
		var knee := _pivot(thigh, Vector3(0, -0.52, 0))
		_capsule(knee, skin, Vector3(0, -0.27, 0), 0.04, 0.6)
		_box(knee, skin, Vector3(0, -0.57, -0.07), Vector3(0.07, 0.03, 0.24))
		parts["thigh_" + tag] = thigh
		parts["knee_" + tag] = knee

	var spine := _pivot(hips, Vector3(0, 0.05, 0))
	parts["spine"] = spine
	var torso := _capsule(spine, skin, Vector3(0, 0.38, 0), 0.16, 0.8)
	torso.scale = Vector3(1.0, 1.0, 0.6)
	for i in 6:
		var rib := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.135
		torus.outer_radius = 0.175
		torus.rings = 12
		torus.ring_segments = 6
		rib.mesh = torus
		rib.material_override = bone
		rib.position = Vector3(0, 0.12 + i * 0.1, 0)
		rib.scale = Vector3(1.0, 0.5, 0.62)
		spine.add_child(rib)

	for side in [-1.0, 1.0]:
		var tag := "l" if side < 0.0 else "r"
		var shoulder := _pivot(spine, Vector3(side * 0.25, 0.7, 0))
		shoulder.rotation.z = side * 0.1
		_capsule(shoulder, skin, Vector3(0, -0.28, 0), 0.042, 0.6)
		var elbow := _pivot(shoulder, Vector3(0, -0.56, 0))
		_capsule(elbow, skin, Vector3(0, -0.37, 0), 0.033, 0.78)
		var hand := _pivot(elbow, Vector3(0, -0.74, 0))
		_box(hand, skin, Vector3(0, -0.05, 0), Vector3(0.07, 0.1, 0.03))
		for f in 4:
			var finger := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.01
			cylinder.bottom_radius = 0.003
			cylinder.height = 0.34
			finger.mesh = cylinder
			finger.material_override = bone
			finger.position = Vector3(-0.027 + f * 0.018, -0.27, 0)
			finger.rotation.z = (f - 1.5) * 0.08
			hand.add_child(finger)
		parts["shoulder_" + tag] = shoulder
		parts["elbow_" + tag] = elbow
		parts["hand_" + tag] = hand

	var neck := _pivot(spine, Vector3(0, 0.8, -0.02))
	neck.rotation.x = -0.3
	_capsule(neck, skin, Vector3(0, 0.2, 0), 0.04, 0.46)
	var head := _pivot(neck, Vector3(0, 0.4, 0))
	var skull := MeshInstance3D.new()
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.12
	skull_mesh.height = 0.24
	skull.mesh = skull_mesh
	skull.material_override = skin
	skull.position = Vector3(0, 0.1, 0)
	skull.scale = Vector3(0.82, 1.5, 1.0)
	head.add_child(skull)
	for side in [-1.0, 1.0]:
		_sphere(head, hollow, Vector3(side * 0.05, 0.14, -0.1), 0.034)
		_sphere(head, eye, Vector3(side * 0.05, 0.14, -0.125), 0.014)
	var jaw := _pivot(head, Vector3(0, 0.0, -0.02))
	_box(jaw, hollow, Vector3(0, -0.035, -0.06), Vector3(0.08, 0.045, 0.12))
	for t in 7:
		var tooth := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.008
		cone.height = 0.05
		tooth.mesh = cone
		tooth.material_override = bone
		tooth.position = Vector3(-0.036 + t * 0.012, 0.005, -0.115)
		jaw.add_child(tooth)
		var upper := MeshInstance3D.new()
		upper.mesh = cone
		upper.material_override = bone
		upper.position = Vector3(-0.036 + t * 0.012, 0.0, -0.105)
		upper.rotation.x = PI
		head.add_child(upper)
	parts["neck"] = neck
	parts["head"] = head
	parts["jaw"] = jaw
	root.set_meta("parts", parts)
	return root

static func _pivot(parent: Node3D, position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = position
	parent.add_child(pivot)
	return pivot

static func _box(parent: Node3D, material: Material, position: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance

static func _sphere(parent: Node3D, material: Material, position: Vector3, radius: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance
