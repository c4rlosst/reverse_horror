class_name HouseGraph
extends RefCounted
## Walkable graph of the house. Rooms are convex rectangles, so a straight
## line inside one room is always clear; between rooms we route via doorways.

const ROOMS := {
	&"living": Rect2(-7.0, -5.0, 9.0, 5.0),
	&"kitchen": Rect2(2.0, -5.0, 5.0, 5.0),
	&"bedroom": Rect2(-7.0, 0.0, 7.0, 5.0),
	&"hall": Rect2(0.0, 0.0, 7.0, 5.0),
}

var _astar := AStar3D.new()
var _ids: Dictionary = {}
var _positions: Dictionary = {}
var _rooms: Dictionary = {}

func add_node(id: StringName, position: Vector3, rooms: Array[StringName]) -> void:
	var index := _ids.size()
	_ids[id] = index
	_positions[id] = position
	_rooms[id] = rooms
	_astar.add_point(index, position)

func link(a: StringName, b: StringName) -> void:
	_astar.connect_points(_ids[a], _ids[b])

func position_of(id: StringName) -> Vector3:
	return _positions[id]

func room_at(position: Vector3) -> StringName:
	var best: StringName = &"hall"
	var best_distance := INF
	for room in ROOMS:
		var rect: Rect2 = ROOMS[room]
		var point := Vector2(position.x, position.z)
		if rect.has_point(point):
			return room
		var centre := rect.get_center()
		var distance := centre.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = room
	return best

func nearest(position: Vector3) -> StringName:
	var room := room_at(position)
	var best: StringName = &""
	var best_distance := INF
	for id in _positions:
		if not (_rooms[id] as Array).has(room):
			continue
		var distance := (_positions[id] as Vector3).distance_to(position)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best

## Waypoints from `from` to `to`, starting with the first node (not `from`).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if room_at(from) != room_at(to):
		var a := _ids[nearest(from)] as int
		var b := _ids[nearest(to)] as int
		for point in _astar.get_point_path(a, b):
			result.append(point)
	result.append(to)
	return result

## Walking distance between two points through the house, so noise does not
## travel through walls.
func path_length(from: Vector3, to: Vector3) -> float:
	var total := 0.0
	var previous := from
	for point in path(from, to):
		total += previous.distance_to(point)
		previous = point
	return total
