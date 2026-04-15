extends SceneTree

const LevelMapGeneratorScript = preload("res://Scripts/database/LevelMapGenerator.gd")
const RUNS_PER_LEVEL := 100

func _init() -> void:
	randomize()
	var failures: Array[String] = []
	
	for level in [1, 2, 3]:
		for attempt in range(RUNS_PER_LEVEL):
			var generator = LevelMapGeneratorScript.new()
			if not generator.generate_level(level):
				failures.append("Level %d run %d: generation failed" % [level, attempt + 1])
				continue
			
			var validation_error = _validate_generator(level, generator)
			if validation_error != "":
				failures.append("Level %d run %d: %s" % [level, attempt + 1, validation_error])
	
	if failures.is_empty():
		print("[validate_level_map_generator] PASS")
		quit(0)
		return
	
	print("[validate_level_map_generator] FAIL")
	for failure in failures:
		print(failure)
	quit(1)


func _validate_generator(level: int, generator) -> String:
	var grid: Dictionary = generator.grid
	var room_count = grid.size()
	var expected_room_count = generator.CONFIG.rooms_per_level[level]
	if room_count != expected_room_count:
		return "room count mismatch: got %d expected %d" % [room_count, expected_room_count]
	
	var edge_sum := 0
	var non_start_t := 0
	var non_start_cross := 0
	for pos in grid.keys():
		var neighbor_count = generator._count_neighbors(pos)
		edge_sum += neighbor_count
		if pos != generator.start_node.grid_position:
			if neighbor_count == 3:
				non_start_t += 1
			elif neighbor_count == 4:
				non_start_cross += 1
		
		var node = grid[pos]
		if node.theme == generator.RoomTheme.BOSS_ROOM or \
		   node.theme == generator.RoomTheme.SHOP or \
		   node.theme == generator.RoomTheme.HR_DEPT:
			if neighbor_count != 1:
				return "special dead-end room is not dead-end at %s" % [str(pos)]
		
		if node.theme == generator.RoomTheme.PANTRY and neighbor_count >= 3:
			return "pantry placed on branch node at %s" % [str(pos)]
		
		if pos != generator.start_node.grid_position and neighbor_count >= 3:
			if node.theme == generator.RoomTheme.BOSS_ROOM or \
			   node.theme == generator.RoomTheme.SHOP or \
			   node.theme == generator.RoomTheme.HR_DEPT or \
			   node.theme == generator.RoomTheme.PANTRY:
				return "special room occupies non-start branch node at %s" % [str(pos)]
	
	if edge_sum / 2 != room_count - 1:
		return "graph is not a tree"
	
	match level:
		1:
			if non_start_t != 0:
				return "level 1 has non-start T nodes: %d" % non_start_t
			if non_start_cross != 0:
				return "level 1 has non-start cross nodes: %d" % non_start_cross
		2:
			if non_start_t < 1:
				return "level 2 missing non-start T node"
			if non_start_cross != 0:
				return "level 2 has non-start cross nodes: %d" % non_start_cross
		3:
			if non_start_cross < 1:
				return "level 3 missing non-start cross node"
	
	return ""
