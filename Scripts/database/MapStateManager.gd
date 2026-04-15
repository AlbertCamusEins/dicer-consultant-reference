extends Node

# 单例，管理地图状态
var cleared_rooms: Array[Vector2i] = []
var revealed_rooms: Array[Vector2i] = []
var current_room_position: Vector2i
var current_map_data: Dictionary = {}
var cleared_enemies: Array[Vector2i] = []

func _room_key(pos: Vector2i) -> String:
	return str(pos.x) + "_" + str(pos.y)

func mark_room_as_cleared(pos: Vector2i) -> void:
	if not cleared_rooms.has(pos):
		cleared_rooms.append(pos)
		reveal_neighbors(pos)

func mark_room_as_explored(pos: Vector2i) -> void:
	reveal_room(pos)
	reveal_neighbors(pos)

func reveal_neighbors(pos: Vector2i) -> void:
	var directions = [
		Vector2i(0, -1), # UP
		Vector2i(0, 1),  # DOWN
		Vector2i(-1, 0), # LEFT
		Vector2i(1, 0)   # RIGHT
	]
	
	for dir in directions:
		var neighbor_pos = pos + dir
		# Check if neighbor exists in the map data (keys are strings "x_y")
		var key_str = str(neighbor_pos.x) + "_" + str(neighbor_pos.y)
		if current_map_data.has(key_str):
			reveal_room(neighbor_pos)

func reveal_room(pos: Vector2i) -> void:
	if not revealed_rooms.has(pos):
		revealed_rooms.append(pos)

func is_room_revealed(pos: Vector2i) -> bool:
	return revealed_rooms.has(pos)

func is_room_cleared(pos: Vector2i) -> bool:
	return cleared_rooms.has(pos)

func set_current_room(pos: Vector2i) -> void:
	current_room_position = pos

func get_current_room() -> Vector2i:
	return current_room_position

func is_enemy_cleared(pos: Vector2i) -> bool:
	return cleared_enemies.has(pos)

func mark_enemy_cleared(pos: Vector2i) -> void:
	if not cleared_enemies.has(pos):
		cleared_enemies.append(pos)

func save_map_data(data: Dictionary) -> void:
	current_map_data = data

func get_map_data() -> Dictionary:
	return current_map_data

func get_room_data(pos: Vector2i) -> Dictionary:
	var key_str = _room_key(pos)
	if current_map_data.has(key_str) and current_map_data[key_str] is Dictionary:
		return current_map_data[key_str]
	return {}

func set_room_data(pos: Vector2i, room_data: Dictionary) -> void:
	current_map_data[_room_key(pos)] = room_data

func get_room_shop_state(pos: Vector2i) -> Dictionary:
	var room_data = get_room_data(pos)
	if room_data.has("shop_state") and room_data["shop_state"] is Dictionary:
		return room_data["shop_state"]
	return {}

func set_room_shop_state(pos: Vector2i, shop_state: Dictionary) -> void:
	var room_data = get_room_data(pos)
	room_data["shop_state"] = shop_state
	set_room_data(pos, room_data)

func get_room_battle_state(pos: Vector2i) -> Dictionary:
	var room_data = get_room_data(pos)
	if room_data.has("battle_state") and room_data["battle_state"] is Dictionary:
		return room_data["battle_state"]
	return {}

func set_room_battle_state(pos: Vector2i, battle_state: Dictionary) -> void:
	var room_data = get_room_data(pos)
	room_data["battle_state"] = battle_state
	set_room_data(pos, room_data)

func clear_room_battle_state(pos: Vector2i) -> void:
	var room_data = get_room_data(pos)
	if room_data.has("battle_state"):
		room_data.erase("battle_state")
		set_room_data(pos, room_data)

func get_room_battle_result_state(pos: Vector2i) -> Dictionary:
	var room_data = get_room_data(pos)
	if room_data.has("battle_result_state") and room_data["battle_result_state"] is Dictionary:
		return room_data["battle_result_state"]
	return {}

func set_room_battle_result_state(pos: Vector2i, battle_result_state: Dictionary) -> void:
	var room_data = get_room_data(pos)
	room_data["battle_result_state"] = battle_result_state
	set_room_data(pos, room_data)

func clear_room_battle_result_state(pos: Vector2i) -> void:
	var room_data = get_room_data(pos)
	if room_data.has("battle_result_state"):
		room_data.erase("battle_result_state")
		set_room_data(pos, room_data)

func get_room_incoming_enemies(pos: Vector2i) -> Array:
	var room_data = get_room_data(pos)
	var incoming = room_data.get("incoming_enemies", [])
	if typeof(incoming) == TYPE_ARRAY:
		return incoming.duplicate(true)
	return []

func append_room_incoming_enemy(pos: Vector2i, enemy_payload: Dictionary) -> void:
	if enemy_payload.is_empty():
		return
	var room_data = get_room_data(pos)
	var incoming = room_data.get("incoming_enemies", [])
	if typeof(incoming) != TYPE_ARRAY:
		incoming = []
	incoming.append(enemy_payload.duplicate(true))
	room_data["incoming_enemies"] = incoming
	set_room_data(pos, room_data)

func consume_room_incoming_enemies(pos: Vector2i) -> Array:
	var room_data = get_room_data(pos)
	var incoming = room_data.get("incoming_enemies", [])
	if typeof(incoming) != TYPE_ARRAY:
		incoming = []
	if room_data.has("incoming_enemies"):
		room_data.erase("incoming_enemies")
		set_room_data(pos, room_data)
	return incoming.duplicate(true)

func get_room_escape_markers(pos: Vector2i) -> Array:
	var room_data = get_room_data(pos)
	var markers = room_data.get("escape_markers", [])
	if typeof(markers) == TYPE_ARRAY:
		return markers.duplicate(true)
	return []

func add_room_escape_marker(pos: Vector2i, marker_payload: Dictionary) -> void:
	if marker_payload.is_empty():
		return
	var room_data = get_room_data(pos)
	var markers = room_data.get("escape_markers", [])
	if typeof(markers) != TYPE_ARRAY:
		markers = []
	markers.append(marker_payload.duplicate(true))
	room_data["escape_markers"] = markers
	set_room_data(pos, room_data)

func clear_room_escape_markers(pos: Vector2i) -> void:
	var room_data = get_room_data(pos)
	if room_data.has("escape_markers"):
		room_data.erase("escape_markers")
		set_room_data(pos, room_data)

func has_room_escape_marker(pos: Vector2i) -> bool:
	return not get_room_escape_markers(pos).is_empty()

func find_nearest_uncleared_normal_battle_room(origin: Vector2i) -> Vector2i:
	var best_pos := Vector2i(-999999, -999999)
	var best_distance := 2147483647
	for key_str in current_map_data.keys():
		var room_data = current_map_data[key_str]
		if typeof(room_data) != TYPE_DICTIONARY:
			continue
		var parts = key_str.split("_")
		if parts.size() != 2:
			continue
		var pos := Vector2i(parts[0].to_int(), parts[1].to_int())
		if pos == origin:
			continue
		if is_enemy_cleared(pos):
			continue
		var contents = room_data.get("contents", {})
		if typeof(contents) != TYPE_DICTIONARY:
			continue
		if str(contents.get("enemy_type", "NONE")) != "NORMAL":
			continue
		var distance = absi(pos.x - origin.x) + absi(pos.y - origin.y)
		var is_better = distance < best_distance
		if not is_better and distance == best_distance:
			is_better = pos.x < best_pos.x or (pos.x == best_pos.x and pos.y < best_pos.y)
		if is_better:
			best_distance = distance
			best_pos = pos
	return best_pos

func to_dict() -> Dictionary:
	var serialized_rooms = []
	for room in cleared_rooms:
		serialized_rooms.append({"x": room.x, "y": room.y})
	
	var serialized_revealed = []
	for room in revealed_rooms:
		serialized_revealed.append({"x": room.x, "y": room.y})
	
	# 序列化 cleared enemies
	var serialized_enemies = []
	for room in cleared_enemies:
		serialized_enemies.append({"x": room.x, "y": room.y})
	return {
		"cleared_rooms": serialized_rooms,
		"revealed_rooms": serialized_revealed,
		"cleared_enemies": serialized_enemies,
		"current_room": {
			"x": current_room_position.x,
			"y": current_room_position.y
		},
		"map_data": current_map_data
	}

func from_dict(data: Dictionary) -> void:
	cleared_rooms.clear()
	if data.has("cleared_rooms"):
		for room in data.cleared_rooms:
			cleared_rooms.append(Vector2i(room.x, room.y))
	
	revealed_rooms.clear()
	if data.has("revealed_rooms"):
		for room in data.revealed_rooms:
			revealed_rooms.append(Vector2i(room.x, room.y))
	
	# [新增] 恢复 cleared_enemies
	cleared_enemies.clear()
	if data.has("cleared_enemies"):
		for room in data.cleared_enemies:
			cleared_enemies.append(Vector2i(room.x, room.y))
	
	if data.has("current_room"):
		current_room_position = Vector2i(
			data.current_room.x,
			data.current_room.y
		)
	
	if data.has("map_data"):
		current_map_data = data.map_data

func reset() -> void:
	cleared_rooms.clear()
	revealed_rooms.clear()
	cleared_enemies.clear()
	current_room_position = Vector2i()
	current_map_data.clear()
