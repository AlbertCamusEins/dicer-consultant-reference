extends Node

const DEFAULT_OFFER_COUNT: int = 3

func _ready() -> void:
	if QuestProgressBus and not QuestProgressBus.quest_event.is_connected(_on_quest_event):
		QuestProgressBus.quest_event.connect(_on_quest_event)
	_initialize_offers_if_needed()

func _get_run() -> RunData:
	return GameManager.current_run

func _initialize_offers_if_needed() -> void:
	var run = _get_run()
	if run == null:
		return
	var has_task_history = not run.active_tasks.is_empty() \
		or not run.completed_tasks.is_empty() \
		or not run.failed_tasks.is_empty()
	if has_task_history:
		return
	if not run.task_offers.is_empty():
		return
	refresh_task_offers(DEFAULT_OFFER_COUNT)

func get_offer_quests() -> Array:
	var run = _get_run()
	if run == null:
		return []
	return run.task_offers.duplicate(true)

func get_active_tasks() -> Dictionary:
	var run = _get_run()
	if run == null:
		return {}
	return run.active_tasks.duplicate(true)

func get_completed_tasks() -> Dictionary:
	var run = _get_run()
	if run == null:
		return {}
	return run.completed_tasks.duplicate(true)

func is_active_task_variant_satisfied(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.active_tasks.has(quest_id):
		return false
	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false
	return _are_variants_satisfied_for_progress(quest_id, quest_data)

func can_accept_quest(quest_id: String) -> bool:
	if quest_id == "":
		return false
	var run = _get_run()
	if run == null:
		return false
	if run.active_tasks.has(quest_id):
		return false
	if run.completed_tasks.has(quest_id):
		return false
	if run.failed_tasks.has(quest_id):
		return false
	if not _check_prerequisites(quest_id, run):
		return false
	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false
	return _can_satisfy_variants_on_accept(quest_data)

func refresh_task_offers(count: int = DEFAULT_OFFER_COUNT) -> Array:
	var run = _get_run()
	if run == null:
		return []
	var available_ids: Array = []
	for quest_id in GameDataManager.quests.keys():
		var quest_id_str = str(quest_id)
		if run.completed_tasks.has(quest_id_str):
			continue
		if run.failed_tasks.has(quest_id_str):
			continue
		if run.active_tasks.has(quest_id_str):
			continue
		if not _check_prerequisites(quest_id_str, run):
			continue
		var quest_data = GameDataManager.get_quest_data(quest_id_str)
		if quest_data.is_empty():
			continue
		if not _can_satisfy_variants_on_accept(quest_data):
			continue
		available_ids.append(quest_id_str)

	available_ids.shuffle()
	var take_count = min(max(0, count), available_ids.size())
	run.task_offers.clear()
	for i in range(take_count):
		run.task_offers.append(available_ids[i])
	return run.task_offers.duplicate(true)

func accept_quest(quest_id: String) -> bool:
	if not can_accept_quest(quest_id):
		return false
	var run = _get_run()
	if run == null:
		return false
	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false

	var requirements = quest_data.get("requirements", [])
	var progress_map: Dictionary = {}
	var target_map: Dictionary = {}
	for req in requirements:
		if typeof(req) != TYPE_DICTIONARY:
			continue
		var req_key = _requirement_key(req)
		if req_key == "":
			continue
		progress_map[req_key] = 0
		target_map[req_key] = int(req.get("count", 1))

	run.active_tasks[quest_id] = {
		"quest_id": quest_id,
		"accepted_at_floor": int(run.current_floor),
		"status": "active",
		"progress": progress_map,
		"targets": target_map,
		"time_elapsed": 0,
		"variant_runtime": {},
		"reward_claimed": false
	}
	if not _apply_variants_on_accept(quest_id):
		run.active_tasks.erase(quest_id)
		return false
	run.task_offers.erase(quest_id)
	return true

func fail_quest(quest_id: String, reason: String = "") -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.active_tasks.has(quest_id):
		return false
	var task_state = run.active_tasks[quest_id]
	task_state["status"] = "failed"
	if reason != "":
		task_state["reason"] = reason
	_apply_variants_on_task_end(quest_id, task_state, false)
	run.failed_tasks[quest_id] = task_state
	run.active_tasks.erase(quest_id)
	return true

func complete_quest(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.active_tasks.has(quest_id):
		return false
	var task_state = run.active_tasks[quest_id]
	task_state["status"] = "completed"
	task_state["completed_at_floor"] = int(run.current_floor)
	_apply_variants_on_task_end(quest_id, task_state, true)
	run.completed_tasks[quest_id] = task_state
	run.active_tasks.erase(quest_id)
	_emit_quest_event("quest_completed", {
		"count": 1,
		"quest_id": quest_id
	})
	return true

func submit_quest(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.active_tasks.has(quest_id):
		return false
	var state = run.active_tasks[quest_id]
	if not _is_quest_done(state):
		return false
	return complete_quest(quest_id)

func claim_quest_reward(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.completed_tasks.has(quest_id):
		return false
	var state = run.completed_tasks[quest_id]
	if bool(state.get("reward_claimed", false)):
		return false

	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false
	var rewards = quest_data.get("rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		run.gain_gold(int(rewards.get("gold", 0)))
	state["reward_claimed"] = true
	run.completed_tasks[quest_id] = state
	_emit_quest_event("quest_reward_claimed", {
		"count": 1,
		"quest_id": quest_id
	})
	return true

func is_quest_completed(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	return run.completed_tasks.has(quest_id)

func get_claimable_completed_ids() -> Array:
	var run = _get_run()
	if run == null:
		return []
	var result: Array = []
	for quest_id in run.completed_tasks.keys():
		var state = run.completed_tasks[quest_id]
		if not bool(state.get("reward_claimed", false)):
			result.append(str(quest_id))
	return result

func _on_quest_event(event_id: String, payload: Dictionary) -> void:
	_update_task_counters(event_id, payload)
	_update_active_quest_progress(event_id, payload)
	_update_active_quest_time_limits(event_id, payload)

func _update_task_counters(event_id: String, payload: Dictionary) -> void:
	var run = _get_run()
	if run == null:
		return
	if not run.task_counters.has(event_id):
		run.task_counters[event_id] = 0
	var increment = int(payload.get("count", 1))
	run.task_counters[event_id] = int(run.task_counters[event_id]) + max(1, increment)

func _update_active_quest_progress(event_id: String, payload: Dictionary) -> void:
	var run = _get_run()
	if run == null:
		return
	var completed_ids: Array = []

	for quest_id in run.active_tasks.keys():
		var state = run.active_tasks[quest_id]
		var quest_data = GameDataManager.get_quest_data(str(quest_id))
		if quest_data.is_empty():
			continue
		if not _are_variants_satisfied_for_progress(str(quest_id), quest_data):
			continue
		var requirements = quest_data.get("requirements", [])
		var progress_map = state.get("progress", {})
		var targets_map = state.get("targets", {})
		var touched = false

		for req in requirements:
			if typeof(req) != TYPE_DICTIONARY:
				continue
			if not _is_requirement_matched(req, event_id, payload):
				continue
			var req_key = _requirement_key(req)
			if req_key == "":
				continue
			if not progress_map.has(req_key):
				progress_map[req_key] = 0
			var req_inc = int(req.get("count_per_event", payload.get("count", 1)))
			progress_map[req_key] = int(progress_map[req_key]) + max(1, req_inc)
			touched = true

		if touched:
			state["progress"] = progress_map
			state["targets"] = targets_map
			run.active_tasks[quest_id] = state

		if _is_quest_done(state):
			completed_ids.append(str(quest_id))

	for quest_id in completed_ids:
		complete_quest(quest_id)

func _update_active_quest_time_limits(event_id: String, payload: Dictionary) -> void:
	var run = _get_run()
	if run == null:
		return
	var failed_ids: Array = []

	for quest_id in run.active_tasks.keys():
		var quest_id_str = str(quest_id)
		var state = run.active_tasks[quest_id]
		var quest_data = GameDataManager.get_quest_data(quest_id_str)
		if quest_data.is_empty():
			continue
		var time_limit = quest_data.get("time_limit", {})
		if typeof(time_limit) != TYPE_DICTIONARY or time_limit.is_empty():
			continue
		var limit_type = str(time_limit.get("type", ""))
		if limit_type == "" or limit_type != event_id:
			continue
		var limit_count = int(time_limit.get("count", 0))
		if limit_count <= 0:
			continue
		var elapsed = int(state.get("time_elapsed", 0))
		var increment = int(payload.get("count", 1))
		elapsed += max(1, increment)
		state["time_elapsed"] = elapsed
		run.active_tasks[quest_id] = state
		if elapsed > limit_count:
			failed_ids.append(quest_id_str)

	for failed_id in failed_ids:
		fail_quest(failed_id, "time_limit_exceeded")

func _is_quest_done(state: Dictionary) -> bool:
	var progress_map = state.get("progress", {})
	var targets_map = state.get("targets", {})
	for key in targets_map.keys():
		var target_val = int(targets_map[key])
		var current_val = int(progress_map.get(key, 0))
		if current_val < target_val:
			return false
	return not targets_map.is_empty()

func _is_requirement_matched(req: Dictionary, event_id: String, payload: Dictionary) -> bool:
	var req_type = str(req.get("type", ""))
	if req_type == "":
		return false
	if req_type != event_id:
		return false
	var req_filters = req.get("filters", {})
	if typeof(req_filters) != TYPE_DICTIONARY:
		return true
	for filter_key in req_filters.keys():
		if payload.get(filter_key, null) != req_filters[filter_key]:
			return false
	return true

func _requirement_key(req: Dictionary) -> String:
	var req_type = str(req.get("type", ""))
	if req_type == "":
		return ""
	var req_filters = req.get("filters", {})
	if typeof(req_filters) != TYPE_DICTIONARY or req_filters.is_empty():
		return req_type
	var key_parts: Array = [req_type]
	var filter_keys = req_filters.keys()
	filter_keys.sort()
	for filter_key in filter_keys:
		key_parts.append(str(filter_key) + "=" + str(req_filters[filter_key]))
	return "|".join(key_parts)

func _check_prerequisites(quest_id: String, run: RunData) -> bool:
	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false
	var prerequisites = quest_data.get("prerequisites", [])
	for prereq in prerequisites:
		if typeof(prereq) == TYPE_STRING:
			if not run.completed_tasks.has(str(prereq)):
				return false
		elif typeof(prereq) == TYPE_DICTIONARY:
			var prereq_type = str(prereq.get("type", ""))
			match prereq_type:
				"quest_completed":
					var target_quest_id = str(prereq.get("quest_id", ""))
					if target_quest_id == "" or not run.completed_tasks.has(target_quest_id):
						return false
				"min_floor":
					if int(run.current_floor) < int(prereq.get("floor", 1)):
						return false
				"inventory_contains":
					var face_type = str(prereq.get("face_type", ""))
					var face_id = str(prereq.get("face_id", ""))
					var minimum_faces = int(prereq.get("minimum_faces", 1))
					if minimum_faces <= 0:
						minimum_faces = 1
					var owned_count = _count_inventory_matching_faces(run, face_type, face_id)
					if owned_count < minimum_faces:
						return false
				_:
					return false
	return true

func consume_encounter_override(default_enemies: Array, battle_type: String) -> Array:
	var run = _get_run()
	if run == null:
		return default_enemies
	for quest_id in run.active_tasks.keys():
		var quest_id_str = str(quest_id)
		var task_state = run.active_tasks[quest_id]
		var quest_data = GameDataManager.get_quest_data(quest_id_str)
		if quest_data.is_empty():
			continue
		var variants = quest_data.get("variants", [])
		if typeof(variants) != TYPE_ARRAY:
			continue
		var runtime = task_state.get("variant_runtime", {})
		for i in range(variants.size()):
			var variant = variants[i]
			if typeof(variant) != TYPE_DICTIONARY:
				continue
			if str(variant.get("type", "")) != "encounter_override":
				continue
			var allowed_types = variant.get("battle_types", ["normal", "elite"])
			if typeof(allowed_types) == TYPE_ARRAY and not allowed_types.is_empty() and not allowed_types.has(battle_type):
				continue
			var key = "encounter_override_%d" % i
			if not runtime.has(key):
				runtime[key] = {"remaining": int(variant.get("next_battles", 0))}
			var state = runtime[key]
			var remaining = int(state.get("remaining", 0))
			if remaining <= 0:
				continue
			var enemy_ids = variant.get("enemy_ids", [])
			if typeof(enemy_ids) != TYPE_ARRAY or enemy_ids.is_empty():
				continue
			remaining -= 1
			state["remaining"] = remaining
			runtime[key] = state
			task_state["variant_runtime"] = runtime
			run.active_tasks[quest_id] = task_state
			return enemy_ids.duplicate(true)
	return default_enemies

func _emit_quest_event(event_id: String, payload: Dictionary = {}) -> void:
	if QuestProgressBus:
		QuestProgressBus.emit_event(event_id, payload)

func _can_satisfy_variants_on_accept(quest_data: Dictionary) -> bool:
	var variants = quest_data.get("variants", [])
	if typeof(variants) != TYPE_ARRAY:
		return true
	var run = _get_run()
	if run == null:
		return false
	for variant in variants:
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var variant_type = str(variant.get("type", ""))
		match variant_type:
			"build_constraint":
				if not _check_build_constraint(variant):
					return false
			"loan_item":
				var item_id = str(variant.get("item_id", ""))
				if item_id == "" or GameDataManager.get_item_data(item_id).is_empty():
					return false
			"collateral":
				var when = str(variant.get("when", "accept"))
				if when != "accept":
					continue
				if not _can_pay_collateral(variant, run):
					return false
			_:
				pass
	return true

func _apply_variants_on_accept(quest_id: String) -> bool:
	var run = _get_run()
	if run == null:
		return false
	if not run.active_tasks.has(quest_id):
		return false
	var task_state = run.active_tasks[quest_id]
	var quest_data = GameDataManager.get_quest_data(quest_id)
	if quest_data.is_empty():
		return false
	var variants = quest_data.get("variants", [])
	if typeof(variants) != TYPE_ARRAY or variants.is_empty():
		return true
	var runtime = task_state.get("variant_runtime", {})
	var applied_indices: Array = []
	for i in range(variants.size()):
		var variant = variants[i]
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var variant_type = str(variant.get("type", ""))
		match variant_type:
			"build_constraint":
				if not _check_build_constraint(variant):
					_rollback_variants_on_accept(variants, runtime, applied_indices)
					return false
			"encounter_override":
				runtime["encounter_override_%d" % i] = {
					"remaining": int(variant.get("next_battles", 0))
				}
				applied_indices.append(i)
			"loan_item":
				if not _grant_loan_item(variant, runtime, i):
					_rollback_variants_on_accept(variants, runtime, applied_indices)
					return false
				applied_indices.append(i)
			"collateral":
				if not _apply_collateral_variant(variant, runtime, i):
					_rollback_variants_on_accept(variants, runtime, applied_indices)
					return false
				applied_indices.append(i)
			_:
				pass
	task_state["variant_runtime"] = runtime
	run.active_tasks[quest_id] = task_state
	return true

func _apply_variants_on_task_end(_quest_id: String, task_state: Dictionary, _was_completed: bool) -> void:
	var run = _get_run()
	if run == null:
		return
	var quest_data = GameDataManager.get_quest_data(str(task_state.get("quest_id", "")))
	if quest_data.is_empty():
		return
	var variants = quest_data.get("variants", [])
	if typeof(variants) != TYPE_ARRAY or variants.is_empty():
		return
	var runtime = task_state.get("variant_runtime", {})
	for i in range(variants.size()):
		var variant = variants[i]
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var variant_type = str(variant.get("type", ""))
		match variant_type:
			"loan_item":
				var revoke_on = str(variant.get("revoke_on", "task_end"))
				if revoke_on == "task_end":
					_revoke_loan_item(variant, runtime, i)
			"collateral":
				if bool(variant.get("temporary", false)):
					_restore_collateral(runtime, i)
			_:
				pass

func _are_variants_satisfied_for_progress(_quest_id: String, quest_data: Dictionary) -> bool:
	var variants = quest_data.get("variants", [])
	if typeof(variants) != TYPE_ARRAY:
		return true
	for variant in variants:
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		if str(variant.get("type", "")) == "build_constraint":
			if not _check_build_constraint(variant):
				return false
	return true

func _check_build_constraint(variant: Dictionary) -> bool:
	var dice_type = _normalize_face_type(str(variant.get("dice_type", "equipment")))
	var face_id = str(variant.get("face_id", ""))
	var minimum_faces = int(variant.get("minimum_faces", 1))
	if minimum_faces <= 0:
		minimum_faces = 1
	if face_id == "":
		return true
	var face_map: Dictionary = EmbeddedDiceFaces.get_dice_faces(dice_type)
	var matched_count = 0
	for face in face_map.values():
		if face == null:
			continue
		if _is_face_match(face, face_id, dice_type):
			matched_count += 1
			if matched_count >= minimum_faces:
				return true
	return matched_count >= minimum_faces

func _grant_loan_item(variant: Dictionary, runtime: Dictionary, index: int) -> bool:
	var run = _get_run()
	if run == null:
		return false
	var item_id = str(variant.get("item_id", ""))
	if item_id == "":
		return false
	var item_data = GameDataManager.get_item_data(item_id)
	if item_data.is_empty():
		return false
	var had_item_before = run.inventory.has_item(item_id)
	if not had_item_before:
		run.inventory.add_item(item_id, item_data)
	runtime["loan_item_%d" % index] = {
		"item_id": item_id,
		"granted_new": not had_item_before
	}
	return true

func _revoke_loan_item(_variant: Dictionary, runtime: Dictionary, index: int) -> void:
	var run = _get_run()
	if run == null:
		return
	var key = "loan_item_%d" % index
	if not runtime.has(key):
		return
	var item_id = str(runtime[key].get("item_id", ""))
	var granted_new = bool(runtime[key].get("granted_new", false))
	if item_id != "" and granted_new:
		run.inventory.remove_item(item_id)

func _apply_collateral_variant(variant: Dictionary, runtime: Dictionary, index: int) -> bool:
	var run = _get_run()
	if run == null:
		return false
	var lose_type = str(variant.get("lose_type", variant.get("lose", "")))
	var target_id = str(variant.get("id", ""))
	var when = str(variant.get("when", "accept"))
	if when != "accept":
		return true
	if lose_type == "" or target_id == "":
		return false
	var stash = {}
	match lose_type:
		"item":
			if not run.inventory.has_item(target_id):
				return false
			var item_obj = run.inventory.get_item_data(target_id)
			if item_obj == null:
				return false
			stash = {"lose_type": "item", "id": target_id, "data": item_obj.to_dict()}
			run.inventory.remove_item(target_id)
		"character":
			stash = _stash_character_by_name(target_id)
			if stash.is_empty():
				return false
		"equipment":
			stash = _stash_equipment_by_id(target_id)
			if stash.is_empty():
				return false
		"hex":
			stash = _stash_hex_by_id(target_id)
			if stash.is_empty():
				return false
		_:
			return false
	runtime["collateral_%d" % index] = stash
	return true

func _can_pay_collateral(variant: Dictionary, run: RunData) -> bool:
	var lose_type = str(variant.get("lose_type", variant.get("lose", "")))
	var target_id = str(variant.get("id", ""))
	if lose_type == "" or target_id == "":
		return false
	match lose_type:
		"item":
			return run.inventory.has_item(target_id)
		"character":
			for face in run.inventory.frien_faces.values():
				if face != null and str(face.character_name) == target_id:
					return true
			return false
		"equipment":
			for face in run.inventory.equipment_faces.values():
				if face == null:
					continue
				if str(face.id) == target_id:
					return true
				if GameDataManager.get_equipment_id_by_name(str(face.equipment_name)) == target_id:
					return true
			return false
		"hex":
			for face in run.inventory.hex_faces.values():
				if face == null:
					continue
				if str(face.id) == target_id:
					return true
				if GameDataManager.get_hex_id_by_name(str(face.hex_name)) == target_id:
					return true
			return false
		_:
			return false

func _restore_collateral(runtime: Dictionary, index: int) -> void:
	var run = _get_run()
	if run == null:
		return
	var key = "collateral_%d" % index
	if not runtime.has(key):
		return
	var stash = runtime[key]
	if typeof(stash) != TYPE_DICTIONARY:
		return
	var lose_type = str(stash.get("lose_type", ""))
	var data = stash.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	match lose_type:
		"item":
			var item_id = str(stash.get("id", ""))
			if item_id != "" and not data.is_empty():
				run.inventory.add_item(item_id, data)
		"character":
			var face_id = str(stash.get("face_id", ""))
			if face_id != "" and not data.is_empty():
				run.inventory.add_face("frien", face_id, data)
		"equipment":
			var equip_face_id = str(stash.get("face_id", ""))
			if equip_face_id != "" and not data.is_empty():
				run.inventory.add_face("equipment", equip_face_id, data)
		"hex":
			var hex_face_id = str(stash.get("face_id", ""))
			if hex_face_id != "" and not data.is_empty():
				run.inventory.add_face("hex2", hex_face_id, data)

func _rollback_variants_on_accept(variants: Array, runtime: Dictionary, applied_indices: Array) -> void:
	for i in range(applied_indices.size() - 1, -1, -1):
		var variant_index = int(applied_indices[i])
		if variant_index < 0 or variant_index >= variants.size():
			continue
		var variant = variants[variant_index]
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var variant_type = str(variant.get("type", ""))
		match variant_type:
			"loan_item":
				_revoke_loan_item(variant, runtime, variant_index)
			"collateral":
				_restore_collateral(runtime, variant_index)
			_:
				pass

func _stash_character_by_name(character_name: String) -> Dictionary:
	var run = _get_run()
	if run == null:
		return {}
	for face_id in run.inventory.frien_faces.keys():
		var face = run.inventory.frien_faces[face_id]
		if face == null:
			continue
		if str(face.character_name) != character_name:
			continue
		var data = {
			"character_name": face.character_name,
			"texture_path": face.texture_path,
			"health": face.health,
			"traits": face.traits,
			"countdown": face.countdown,
			"prime_hex_id": face.prime_hex_id,
			"peak_hex_id": face.peak_hex_id,
			"soul_hex_id": face.soul_hex_id,
			"experience": face.experience
		}
		run.inventory.remove_face("frien", str(face_id))
		return {"lose_type": "character", "face_id": str(face_id), "id": character_name, "data": data}
	return {}

func _stash_equipment_by_id(equipment_id: String) -> Dictionary:
	var run = _get_run()
	if run == null:
		return {}
	for face_id in run.inventory.equipment_faces.keys():
		var face = run.inventory.equipment_faces[face_id]
		if face == null:
			continue
		var face_id_match = str(face.id) == equipment_id
		var name_id_match = GameDataManager.get_equipment_id_by_name(str(face.equipment_name)) == equipment_id
		if not face_id_match and not name_id_match:
			continue
		var data = {
			"id": face.id,
			"equipment_name": face.equipment_name,
			"texture_path": face.texture_path,
			"slot_limit": face.slot_limit,
			"attack_bonus": face.attack_bonus,
			"defense_bonus": face.defense_bonus,
			"traits": face.traits,
			"trait_descs": face.trait_descs
		}
		run.inventory.remove_face("equipment", str(face_id))
		return {"lose_type": "equipment", "face_id": str(face_id), "id": equipment_id, "data": data}
	return {}

func _stash_hex_by_id(hex_id: String) -> Dictionary:
	var run = _get_run()
	if run == null:
		return {}
	for face_id in run.inventory.hex_faces.keys():
		var face = run.inventory.hex_faces[face_id]
		if face == null:
			continue
		var face_id_match = str(face.id) == hex_id
		var name_id_match = GameDataManager.get_hex_id_by_name(str(face.hex_name)) == hex_id
		if not face_id_match and not name_id_match:
			continue
		var data = face.to_dict()
		run.inventory.remove_face("hex2", str(face_id))
		return {"lose_type": "hex", "face_id": str(face_id), "id": hex_id, "data": data}
	return {}

func _normalize_face_type(face_type: String) -> String:
	match face_type:
		"hex":
			return "hex2"
		"friend", "character":
			return "frien"
		_:
			return face_type

func _count_inventory_matching_faces(run: RunData, face_type: String, face_id: String) -> int:
	var normalized_type = _normalize_face_type(face_type)
	if face_id == "":
		return 0
	var count = 0
	match normalized_type:
		"frien":
			for face in run.inventory.frien_faces.values():
				if face != null and _is_face_match(face, face_id, normalized_type):
					count += 1
		"equipment":
			for face in run.inventory.equipment_faces.values():
				if face != null and _is_face_match(face, face_id, normalized_type):
					count += 1
		"hex2":
			for face in run.inventory.hex_faces.values():
				if face != null and _is_face_match(face, face_id, normalized_type):
					count += 1
	return count

func _is_face_match(face, target_id: String, face_type: String) -> bool:
	var normalized_type = _normalize_face_type(face_type)
	match normalized_type:
		"frien":
			if "id" in face and str(face.id) == target_id:
				return true
			if "character_name" in face:
				var char_id = GameDataManager.get_character_id_by_name(str(face.character_name))
				if char_id == target_id or str(face.character_name) == target_id:
					return true
		"equipment":
			if "id" in face and str(face.id) == target_id:
				return true
			if "equipment_name" in face:
				var equip_id = GameDataManager.get_equipment_id_by_name(str(face.equipment_name))
				if equip_id == target_id or str(face.equipment_name) == target_id:
					return true
		"hex2":
			if "id" in face and str(face.id) == target_id:
				return true
			if "hex_name" in face:
				var hex_id = GameDataManager.get_hex_id_by_name(str(face.hex_name))
				if hex_id == target_id or str(face.hex_name) == target_id:
					return true
	return false
