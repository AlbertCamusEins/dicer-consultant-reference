extends Node
class_name LevelMapGenerator

enum RoomTheme {
	OFFICE,
	CORRIDOR,
	PANTRY,
	HR_DEPT,
	FRONT_DESK,
	BOSS_ROOM,
	SOLITARY,
	SHOP
}

enum Direction { UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3 }

const ENABLE_GENERATION_LOGS := false

const CONFIG = {
	"max_width": 9,
	"max_height": 7,
	"rooms_per_level": {
		1: 10,  # 第一层房间数
		2: 15,  # 第二层房间数
		3: 19,  # 第三层房间数，略增以容纳非前台十字路口
		4: 22  # 第四层房间数
	},
	"min_dead_ends": {
		1: 3,   # 第一层最少3条死路
		2: 4,   # 第二层最少4条死路
		3: 5,   # 第三层最少5条死路
		4: 5
	},
	"max_dead_ends": {
		1: 4,   # 第一层最多4条死路
		2: 5,   # 第二层最多5条死路
		3: 7,   # 第三层放宽上限以适配十字路口骨架
		4: 6
	},
	"required_non_start_t": {
		1: 0,
		2: 1,
		3: 0,
		4: 0
	},
	"required_non_start_cross": {
		1: 0,
		2: 0,
		3: 1,
		4: 0
	},
	"elite_chance": 100 # 精英战斗生成概率
}

class MapNode:
	var theme: RoomTheme = RoomTheme.OFFICE
	var position: Vector2
	var grid_position: Vector2i
	var distance_from_start: int = 0
	var contents: Dictionary = {
		"enemy_type": "NONE",
		"has_shop": false
	}
	
	func _init(n_theme: RoomTheme, grid_pos: Vector2i):
		theme = n_theme
		grid_position = grid_pos
		position = Vector2(grid_pos.x * 112 + 500, grid_pos.y * 112 + 300)

	func to_dict() -> Dictionary:
		return {
			"theme": int(theme),
			"contents": contents,
			"distance_from_start": distance_from_start,
			"position": {"x": position.x, "y": position.y},
			"grid_position": {"x": grid_position.x, "y": grid_position.y}
		}

var grid: Dictionary = {}  # Vector2i -> MapNode
var start_node: MapNode
var boss_node: MapNode
var current_level: int = 1
var current_dead_ends: Array = []  # 当前的死路节点列表
var reserved_branch_nodes: Array = []  # 受保护的非前台分叉节点，特殊房间不可占用

func _log_generation(args: Array) -> void:
	if not ENABLE_GENERATION_LOGS:
		return
	var parts: Array[String] = []
	for arg in args:
		parts.append(str(arg))
	print(" ".join(parts))

func serialize_grid() -> Dictionary:
	var serialized = {}
	for key in grid.keys():
		var key_str = str(key.x) + "_" + str(key.y)
		serialized[key_str] = grid[key].to_dict()
	return serialized


func generate_level(level: int) -> bool:
	_log_generation(["=== Starting map generation for level", level, "==="])
	current_level = level
	
	var max_retries = 10
	for attempt in range(max_retries):
		_log_generation(["Generation attempt", attempt + 1, "/", max_retries])
		grid.clear()
		current_dead_ends.clear()
		reserved_branch_nodes.clear()
		boss_node = null
		
		var center = Vector2i(CONFIG.max_width / 2, CONFIG.max_height / 2)
		start_node = MapNode.new(RoomTheme.FRONT_DESK, center)
		start_node.distance_from_start = 0
		grid[center] = start_node
		
		if _generate_rooms():
			_log_generation(["Successfully generated rooms"])
			var longest_dead_end = _find_longest_dead_end()
			if longest_dead_end:
				longest_dead_end.theme = RoomTheme.BOSS_ROOM
				longest_dead_end.contents["enemy_type"] = "BOSS"
				boss_node = longest_dead_end
				_log_generation(["Placed boss room at", longest_dead_end.grid_position])
				
				_assign_themes_and_contents()
				return true
		else:
			_log_generation(["Failed to generate rooms in attempt", attempt + 1])
	
	_log_generation(["Failed to generate map after", max_retries, "attempts"])
	return false


func _assign_themes_and_contents() -> void:
	var available_dead_ends = []
	for pos in current_dead_ends:
		if grid[pos] != boss_node:
			available_dead_ends.append(pos)
	
	available_dead_ends.shuffle()

	var pantry_candidates = []
	var pantry_fallback_by_distance = {}
	for pos in grid:
		var node = grid[pos]
		if node == start_node or node == boss_node:
			continue
		if reserved_branch_nodes.has(pos):
			continue
		if _count_neighbors(pos) >= 3:
			continue
		
		var dist = (pos - start_node.grid_position).abs()
		var manhattan_distance = dist.x + dist.y
		if manhattan_distance == 2:
			pantry_candidates.append(pos)
		if not pantry_fallback_by_distance.has(manhattan_distance):
			pantry_fallback_by_distance[manhattan_distance] = []
		pantry_fallback_by_distance[manhattan_distance].append(pos)
	
	var pantry_pos: Variant = null
	if pantry_candidates.size() > 0:
		pantry_pos = pantry_candidates.pick_random()
	else:
		var fallback_distances = pantry_fallback_by_distance.keys()
		fallback_distances.sort()
		if fallback_distances.size() > 0:
			pantry_pos = pantry_fallback_by_distance[fallback_distances[0]].pick_random()
	
	if pantry_pos != null:
		grid[pantry_pos].theme = RoomTheme.PANTRY
		grid[pantry_pos].contents["has_rest"] = true
		grid[pantry_pos].contents["enemy_type"] = "NONE"
		grid[pantry_pos].contents["has_shop"] = false
		available_dead_ends.erase(pantry_pos)
		_log_generation(["Placed Pantry at:", pantry_pos])

	if available_dead_ends.size() > 0:
		var shop_pos = available_dead_ends.pop_front()
		grid[shop_pos].theme = RoomTheme.SHOP
		grid[shop_pos].contents["has_shop"] = true
		grid[shop_pos].contents["enemy_type"] = "NONE"
		_log_generation(["Placed Shop at:", shop_pos])

	if available_dead_ends.size() > 0:
		var hr_pos = available_dead_ends.pop_front()
		grid[hr_pos].theme = RoomTheme.HR_DEPT
		grid[hr_pos].contents["enemy_type"] = "NONE"
		grid[hr_pos].contents["has_shop"] = false
		_log_generation(["Placed HR Dept at:", hr_pos])

	for pos in grid:
		var node = grid[pos]
		
		if node == start_node or node == boss_node or \
		   node.theme == RoomTheme.PANTRY or \
		   node.theme == RoomTheme.SHOP or \
		   node.theme == RoomTheme.SOLITARY or \
		   node.theme == RoomTheme.HR_DEPT:
			continue
		
		var neighbor_count = _count_neighbors(pos)
		
		if neighbor_count >= 2:
			node.theme = RoomTheme.CORRIDOR
		else:
			if randf() < 0.3:
				node.theme = RoomTheme.CORRIDOR
			else:
				node.theme = RoomTheme.OFFICE
		
		if node.theme == RoomTheme.OFFICE:
			node.contents["enemy_type"] = "NORMAL"
		
		if node.theme == RoomTheme.CORRIDOR:
			node.contents["has_shop"] = false
			node.contents["enemy_type"] = "NORMAL"


func _count_neighbors(pos: Vector2i) -> int:
	var count = 0
	for dir in Direction.values():
		var check_pos = _get_next_position(pos, dir)
		if grid.has(check_pos):
			count += 1
	return count


func _generate_rooms() -> bool:
	var rooms_to_generate = CONFIG.rooms_per_level[current_level]
	_log_generation(["Starting room generation. Need", rooms_to_generate, "rooms"])
	
	if not _generate_required_topology_skeleton():
		_log_generation(["Failed to generate required topology skeleton"])
		return false
	
	var rooms_created = grid.size()
	var expansion_positions = _build_initial_expansion_positions()
	
	while rooms_created < rooms_to_generate and not expansion_positions.is_empty():
		var current_pos = expansion_positions.pop_front()
		_log_generation(["Processing position:", current_pos])

		if not _is_expandable_position(current_pos):
			_log_generation(["Current position is invalid, skipping"])
			continue
		
		var available_directions = _get_available_directions(current_pos)
		_log_generation(["Available directions:", available_directions])
		available_directions.shuffle()

		var max_children = _determine_fill_children_count(current_pos, available_directions.size())
		if max_children <= 0:
			continue

		var expansions_from_this_node = 0

		for direction in available_directions:
			if expansions_from_this_node >= max_children or rooms_created >= rooms_to_generate:
				break

			var next_pos = _get_next_position(current_pos, direction)
			_log_generation(["Trying to place room at:", next_pos])
			if not _can_place_room(next_pos):
				continue
			
			var extra_allowance = 0
			if current_pos != start_node.grid_position and expansions_from_this_node >= 1:
				extra_allowance = 1
			if _would_exceed_max_dead_ends(next_pos, extra_allowance):
				_log_generation(["Would exceed max dead ends, skipping"])
				continue
			
			if not _place_room(next_pos, current_pos):
				continue
			
			rooms_created += 1
			expansions_from_this_node += 1
			_log_generation(["Room placed. Total rooms:", rooms_created])
			
			_queue_expandable_position(expansion_positions, next_pos)
		
		if current_pos == start_node.grid_position and _can_start_expand_more():
			_queue_expandable_position(expansion_positions, current_pos)
		
		if current_dead_ends.size() >= CONFIG.min_dead_ends[current_level]:
			for pos in current_dead_ends:
				_queue_expandable_position(expansion_positions, pos)

	_log_generation(["Room generation finished"])
	_log_generation(["Rooms created:", rooms_created])
	_log_generation(["Dead ends:", current_dead_ends.size()])
	_log_generation(["Dead ends required:", CONFIG.min_dead_ends[current_level], "-", CONFIG.max_dead_ends[current_level]])
	
	var final_dead_ends = current_dead_ends.size()
	var min_dead = CONFIG.min_dead_ends[current_level]
	var max_dead = CONFIG.max_dead_ends[current_level]
	
	if rooms_created != rooms_to_generate:
		_log_generation(["Generation failed: room count mismatch."])
		return false
	
	if final_dead_ends < min_dead:
		_log_generation(["Generation failed: Too few dead ends."])
		return false
	if final_dead_ends > max_dead:
		_log_generation(["Generation failed: Too many dead ends."])
		return false
	if not _validate_generated_topology():
		_log_generation(["Generation failed: topology validation failed."])
		return false
	
	return true


func _generate_required_topology_skeleton() -> bool:
	match current_level:
		1:
			return _generate_level_one_skeleton()
		2:
			return _generate_required_branch_skeleton(2)
		3:
			return _generate_required_branch_skeleton(3)
		_:
			return true


func _generate_level_one_skeleton() -> bool:
	var directions = Direction.values()
	directions.shuffle()
	var children_to_place = min(3, directions.size())
	for i in range(children_to_place):
		var dir = directions[i]
		var next_pos = _get_next_position(start_node.grid_position, dir)
		if not _place_room(next_pos, start_node.grid_position):
			return false
	return true


func _generate_required_branch_skeleton(required_children: int) -> bool:
	var main_directions = Direction.values()
	main_directions.shuffle()
	
	var best_main_direction: Variant = null
	var best_priority := -1
	for dir in main_directions:
		var priority = _get_branch_skeleton_priority(dir)
		if priority > best_priority:
			best_priority = priority
			best_main_direction = dir
	
	if best_main_direction == null:
		return false
	
	var transition_pos = _get_next_position(start_node.grid_position, best_main_direction)
	if not _place_room(transition_pos, start_node.grid_position):
		return false
	
	var branch_pos = _get_next_position(transition_pos, best_main_direction)
	if not _place_room(branch_pos, transition_pos):
		return false
	
	var branch_dirs = _get_branch_child_directions(branch_pos, best_main_direction)
	if branch_dirs.size() < required_children:
		return false
	
	reserved_branch_nodes.append(branch_pos)
	branch_dirs.shuffle()
	for i in range(required_children):
		var child_dir = branch_dirs[i]
		var child_pos = _get_next_position(branch_pos, child_dir)
		if not _place_room(child_pos, branch_pos):
			return false
	
	return true


func _get_branch_skeleton_priority(main_direction: Direction) -> int:
	var transition_pos = _get_next_position(start_node.grid_position, main_direction)
	var branch_pos = _get_next_position(transition_pos, main_direction)
	if not _can_place_room(transition_pos) or not _can_place_room(branch_pos):
		return -1
	
	var branch_dirs = _get_branch_child_directions(branch_pos, main_direction)
	var priority = branch_dirs.size()
	if current_level == 3 and branch_dirs.size() >= 3:
		priority += 10
	return priority


func _get_branch_child_directions(branch_pos: Vector2i, main_direction: Direction) -> Array:
	var branch_dirs = []
	var blocked_direction = _get_opposite_direction(main_direction)
	for dir in Direction.values():
		if dir == blocked_direction:
			continue
		var child_pos = _get_next_position(branch_pos, dir)
		if _can_place_room(child_pos):
			branch_dirs.append(dir)
	return branch_dirs


func _build_initial_expansion_positions() -> Array:
	var positions = [start_node.grid_position]
	for pos in current_dead_ends:
		_queue_expandable_position(positions, pos)
	return positions


func _queue_expandable_position(positions: Array, pos: Vector2i) -> void:
	if positions.has(pos):
		return
	if _is_expandable_position(pos):
		positions.append(pos)


func _is_expandable_position(pos: Vector2i) -> bool:
	if pos == start_node.grid_position:
		return _can_start_expand_more()
	if not grid.has(pos):
		return false
	if not _is_dead_end(pos):
		return false
	return _get_available_directions(pos).size() > 0


func _can_start_expand_more() -> bool:
	return _count_neighbors(start_node.grid_position) < _get_start_max_children()


func _get_start_max_children() -> int:
	return 4


func _determine_fill_children_count(current_pos: Vector2i, available_direction_count: int) -> int:
	if available_direction_count <= 0:
		return 0
	
	if current_pos == start_node.grid_position:
		var remaining_capacity = _get_start_max_children() - _count_neighbors(current_pos)
		if remaining_capacity <= 0:
			return 0
		return randi_range(1, min(remaining_capacity, available_direction_count))
	
	var non_start_limit = 1 if current_level == 1 else 2
	return randi_range(1, min(non_start_limit, available_direction_count))


func _place_room(new_pos: Vector2i, parent_pos: Vector2i) -> bool:
	if not _can_place_room(new_pos):
		return false
	var new_node = MapNode.new(RoomTheme.OFFICE, new_pos)
	var parent_distance = int(grid[parent_pos].distance_from_start)
	new_node.distance_from_start = parent_distance + 1
	grid[new_pos] = new_node
	_update_dead_ends(new_pos)
	return true


func _count_non_start_t_nodes() -> int:
	var count = 0
	for pos in grid.keys():
		if pos == start_node.grid_position:
			continue
		if _count_neighbors(pos) == 3:
			count += 1
	return count


func _count_non_start_cross_nodes() -> int:
	var count = 0
	for pos in grid.keys():
		if pos == start_node.grid_position:
			continue
		if _count_neighbors(pos) == 4:
			count += 1
	return count


func _validate_generated_topology() -> bool:
	var non_start_t = _count_non_start_t_nodes()
	var non_start_cross = _count_non_start_cross_nodes()
	var required_t = CONFIG.required_non_start_t.get(current_level, 0)
	var required_cross = CONFIG.required_non_start_cross.get(current_level, 0)
	
	if non_start_t < required_t:
		return false
	if non_start_cross < required_cross:
		return false
	if current_level <= 2 and non_start_cross > 0:
		return false
	if current_level == 1 and non_start_t > 0:
		return false
	return true


func _would_exceed_max_dead_ends(new_pos: Vector2i, extra_allowance: int = 0) -> bool:
	var temp_dead_ends = current_dead_ends.duplicate()
	_log_generation(["Checking dead ends for position:", new_pos])
	_log_generation(["Current dead ends:", temp_dead_ends.size()])
	
	for direction in Direction.values():
		var check_pos = _get_next_position(new_pos, direction)
		if grid.has(check_pos) and _is_dead_end(check_pos):
			temp_dead_ends.erase(check_pos)
			_log_generation(["Removed dead end at:", check_pos])
	
	if _would_be_dead_end(new_pos):
		temp_dead_ends.append(new_pos)
		_log_generation(["Position would be new dead end"])
	_log_generation(["Projected dead ends:", temp_dead_ends.size()])
	return temp_dead_ends.size() > CONFIG.max_dead_ends[current_level] + extra_allowance


func _would_be_dead_end(pos: Vector2i) -> bool:
	var connected_count = 0
	for direction in Direction.values():
		var check_pos = _get_next_position(pos, direction)
		if grid.has(check_pos):
			connected_count += 1
	return connected_count == 1


func _update_dead_ends(new_pos: Vector2i) -> void:
	_log_generation(["Updating dead ends"])
	var removed = []
	for pos in current_dead_ends.duplicate():
		if not _is_dead_end(pos):
			current_dead_ends.erase(pos)
			removed.append(pos)
	
	if removed:
		_log_generation(["Removed dead ends:", removed])
	
	if _is_dead_end(new_pos) and not current_dead_ends.has(new_pos):
		current_dead_ends.append(new_pos)
		_log_generation(["Added new dead end:", new_pos])


func _filter_dead_end_positions(positions: Array) -> Array:
	var filtered = []
	for pos in positions:
		if _is_dead_end(pos):
			filtered.append(pos)
	return filtered


func _get_available_directions(pos: Vector2i) -> Array:
	var directions = []
	for direction in Direction.values():
		var next_pos = _get_next_position(pos, direction)
		if _can_place_room(next_pos) and not _would_create_loop(next_pos):
			directions.append(direction)
	return directions


func _would_create_loop(pos: Vector2i) -> bool:
	var adjacent_rooms = 0
	for direction in Direction.values():
		var check_pos = _get_next_position(pos, direction)
		if grid.has(check_pos):
			adjacent_rooms += 1
			if adjacent_rooms > 1:
				return true
	return false


func _can_place_room(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < CONFIG.max_width and \
		pos.y >= 0 and pos.y < CONFIG.max_height and \
		not grid.has(pos)


func _get_next_position(current: Vector2i, direction: Direction) -> Vector2i:
	match direction:
		Direction.UP:
			return Vector2i(current.x, current.y - 1)
		Direction.RIGHT:
			return Vector2i(current.x + 1, current.y)
		Direction.DOWN:
			return Vector2i(current.x, current.y + 1)
		Direction.LEFT:
			return Vector2i(current.x - 1, current.y)
	return current


func _get_opposite_direction(direction: Direction) -> Direction:
	match direction:
		Direction.UP:
			return Direction.DOWN
		Direction.RIGHT:
			return Direction.LEFT
		Direction.DOWN:
			return Direction.UP
		Direction.LEFT:
			return Direction.RIGHT
	return Direction.UP


func _is_dead_end(pos: Vector2i) -> bool:
	if grid[pos].theme == RoomTheme.FRONT_DESK:
		return false
	
	var connected_rooms = 0
	for direction in Direction.values():
		var check_pos = _get_next_position(pos, direction)
		if grid.has(check_pos):
			connected_rooms += 1
	
	return connected_rooms == 1


func _find_longest_dead_end() -> MapNode:
	var longest_length = -1
	var longest_dead_end = null
	
	for pos in current_dead_ends:
		var length = int(grid[pos].distance_from_start)
		if length > longest_length:
			longest_length = length
			longest_dead_end = grid[pos]
	
	return longest_dead_end


func _calculate_path_length(end_pos: Vector2i) -> int:
	var length = 0
	var current_pos = end_pos
	var visited = {}
	
	while true:
		visited[current_pos] = true
		
		if grid[current_pos].theme == RoomTheme.FRONT_DESK:
			break
		
		var found_next = false
		for direction in Direction.values():
			var next_pos = _get_next_position(current_pos, direction)
			if grid.has(next_pos) and not visited.has(next_pos):
				current_pos = next_pos
				length += 1
				found_next = true
				break
		
		if not found_next:
			return 0
	
	return length


func _are_nodes_neighbors(node_a: MapNode, node_b: MapNode) -> bool:
	var diff = (node_a.grid_position - node_b.grid_position).abs()
	return (diff.x + diff.y) == 1


func _get_corridor_shape(pos: Vector2i) -> String:
	var connected_directions = []
	
	for direction in Direction.values():
		var neighbor_pos = _get_next_position(pos, direction)
		if grid.has(neighbor_pos):
			connected_directions.append(direction)
	
	if connected_directions.size() != 2:
		return "Other"
	
	var dir1 = connected_directions[0]
	var dir2 = connected_directions[1]
	if abs(dir1 - dir2) == 2:
		return "Straight"
	return "L_Shape"


func get_node_scene(node: MapNode) -> String:
	var contents = node.contents
	var pos = node.grid_position

	if node.theme == RoomTheme.FRONT_DESK:
		var current_floor := 1
		if GameManager != null and GameManager.current_run != null:
			current_floor = int(GameManager.current_run.current_floor)
		if current_floor <= 1 and not MapStateManager.is_room_cleared(pos):
			return "res://Scenes/Frontdesk.tscn"
		return ""

	if node.theme == RoomTheme.BOSS_ROOM:
		if not MapStateManager.is_enemy_cleared(pos):
			return "res://Scenes/battle_scene.tscn"
		return ""

	if node.theme == RoomTheme.SHOP:
		return "res://Scenes/shop_scene.tscn"

	if node.theme == RoomTheme.HR_DEPT:
		return "res://Scenes/hr_dept_scene.tscn"

	if node.theme == RoomTheme.PANTRY:
		return "res://Scenes/pantry_scene.tscn"
	
	var enemy_type = contents.get("enemy_type", "NONE")
	if enemy_type != "NONE":
		if not MapStateManager.is_enemy_cleared(pos):
			return "res://Scenes/battle_scene.tscn"
	
	if contents.get("has_shop", false):
		return "res://Scenes/shop_scene.tscn"
	
	return ""
