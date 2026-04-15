extends Node

const TRAIT_DEBUG_ENABLED := true

func _trait_debug(message: String, payload = null) -> void:
	if not TRAIT_DEBUG_ENABLED:
		return
	if payload == null:
		print("[TraitManager][Debug] ", message)
		return
	print("[TraitManager][Debug] ", message, " | ", payload)

func _summarize_targets_by_index(targets_by_index: Dictionary) -> Dictionary:
	var summary := {}
	for key in targets_by_index.keys():
		var entries = targets_by_index.get(key, [])
		var names: Array[String] = []
		if typeof(entries) == TYPE_ARRAY:
			for entry in entries:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var target_name := str(entry.get("name", ""))
				if target_name == "":
					continue
				names.append(target_name)
		summary[key] = names
	return summary

func process_event(event_name: String, context: Dictionary = {}) -> void:
	match event_name:
		"rolled":
			trigger_rolled(context)
		"character_damage_taken":
			trigger_character_damage_taken(context)
		"reinforce":
			trigger_reinforce(context)
		"ally_spell_resolved_after":
			trigger_ally_spell_resolved_after(context)
		"rally":
			trigger_rally(context)
		"ambush":
			trigger_ambush(context)
		"endure":
			trigger_endure(context)
		"deploy":
			trigger_deploy(context)
		"chosen":
			trigger_chosen(context)

func process_enemy_event(event_name: String, context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	if actor_id != "":
		trigger_enemy_event_for_actor(actor_id, event_name, context)
	else:
		trigger_enemy_event_for_all(event_name, context)

func trigger_actor_event_for_actor(actor_id: String, event_name: String, context: Dictionary = {}) -> void:
	if actor_id == "":
		return
	if BattleManager.player_data.player_characters.has(actor_id):
		context["actor_side"] = "player"
		_trigger_event_for_player(actor_id, event_name, context)
		return
	if BattleManager.enemy_data.enemy_fiends.has(actor_id):
		context["actor_side"] = "enemy"
		_trigger_event_for_enemy(actor_id, event_name, context)

func trigger_rolled(context: Dictionary = {}) -> void:
	_trigger_event_for_all_players("rolled", context)

func trigger_character_damage_taken(context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	_trigger_event_for_player(actor_id, "character_damage_taken", context)

func trigger_reinforce(context: Dictionary = {}) -> void:
	_trigger_event_for_all_players("reinforce", context)

func trigger_ally_spell_resolved_after(context: Dictionary = {}) -> void:
	_trigger_event_for_all_players("ally_spell_resolved_after", context)

func trigger_rally(context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	_trigger_event_for_player(actor_id, "rally", context)

func trigger_ambush(context: Dictionary = {}) -> void:
	_trigger_event_for_all_players("ambush", context)

func trigger_endure(context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	_trigger_event_for_player(actor_id, "endure", context)

func trigger_deploy(context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	_trigger_event_for_player(actor_id, "deploy", context)

func trigger_chosen(context: Dictionary = {}) -> void:
	var actor_id = str(context.get("actor_id", ""))
	_trigger_event_for_player(actor_id, "chosen", context)

func trigger_enemy_event_for_all(event_name: String, context: Dictionary = {}) -> void:
	var enemy_context = context.duplicate(true)
	enemy_context["actor_side"] = "enemy"
	for actor_id in BattleManager.enemy_data.enemy_fiends.keys():
		_trigger_event_for_enemy(str(actor_id), event_name, enemy_context)

func trigger_enemy_event_for_actor(actor_id: String, event_name: String, context: Dictionary = {}) -> void:
	var enemy_context = context.duplicate(true)
	enemy_context["actor_side"] = "enemy"
	_trigger_event_for_enemy(actor_id, event_name, enemy_context)

func trigger_equipment_traits(equipment_id: String, event_name: String, context: Dictionary = {}) -> void:
	if equipment_id == "":
		return
	var equipment_def = GameDataManager.get_equipment_data(equipment_id)
	if equipment_def.is_empty():
		return
	var trait_ids = equipment_def.get("traits", [])
	if typeof(trait_ids) != TYPE_ARRAY:
		return
	for trait_id in trait_ids:
		var trait_id_str = str(trait_id)
		if trait_id_str == "":
			continue
		var trait_def = GameDataManager.get_trait_data(trait_id_str)
		if trait_def.is_empty() or str(trait_def.get("source_kind", "")) != "equipment":
			continue
		for trigger in trait_def.get("triggers", []):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			if str(trigger.get("event", "")) != event_name:
				continue
			if not _trigger_conditions_match(trigger.get("conditions", {}), context):
				continue
			_execute_equipment_trigger(equipment_id, trait_id_str, trait_def, trigger, context)

func trigger_hex_traits(hex_id: String, event_name: String, context: Dictionary = {}) -> void:
	if hex_id == "":
		return
	var hex_def = GameDataManager.get_hex_data(hex_id)
	if hex_def.is_empty():
		return
	var trait_ids = hex_def.get("traits", [])
	if typeof(trait_ids) != TYPE_ARRAY:
		return
	var actor_side = str(context.get("actor_side", "player"))
	var actor_id = str(context.get("actor_id", ""))
	for trait_id in trait_ids:
		var trait_id_str = str(trait_id)
		if trait_id_str == "":
			continue
		var trait_def = GameDataManager.get_trait_data(trait_id_str)
		if trait_def.is_empty() or str(trait_def.get("source_kind", "")) != "hex":
			continue
		var matched_triggers: Array = []
		for trigger in trait_def.get("triggers", []):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			if str(trigger.get("event", "")) != event_name:
				continue
			if not _trigger_conditions_match(trigger.get("conditions", {}), context, actor_id):
				continue
			matched_triggers.append(trigger)
		for trigger in matched_triggers:
			_execute_hex_trigger(actor_id, actor_side, trait_def, trigger, context)

func _trigger_event_for_all_players(event_name: String, context: Dictionary) -> void:
	var player_context = context.duplicate(true)
	player_context["actor_side"] = "player"
	for actor_id in BattleManager.player_data.player_characters.keys():
		_trigger_event_for_player(actor_id, event_name, player_context)

func _trigger_event_for_player(actor_id: String, event_name: String, context: Dictionary) -> void:
	if actor_id == "" or not BattleManager.player_data.player_characters.has(actor_id):
		return
	var char_state: Dictionary = BattleManager.player_data.player_characters[actor_id]
	if event_name != "last_breath" and int(char_state.get("current_health", 0)) <= 0:
		return

	var trait_ids = char_state.get("traits", [])
	if typeof(trait_ids) == TYPE_STRING:
		trait_ids = [trait_ids]
	if typeof(trait_ids) != TYPE_ARRAY:
		return

	for trait_id in trait_ids:
		var trait_id_str = str(trait_id)
		if trait_id_str == "":
			continue
		var trait_def = GameDataManager.get_trait_data(trait_id_str)
		if trait_def.is_empty() or str(trait_def.get("source_kind", "")) != "character":
			continue
		var matched_triggers: Array = []
		for trigger in trait_def.get("triggers", []):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			if str(trigger.get("event", "")) != event_name:
				continue
			if not _trigger_conditions_match(trigger.get("conditions", {}), context, actor_id):
				continue
			matched_triggers.append(trigger)
		for trigger in matched_triggers:
			_execute_character_trigger(actor_id, trait_id_str, trait_def, trigger, context)

func _trigger_event_for_enemy(actor_id: String, event_name: String, context: Dictionary) -> void:
	if actor_id == "" or not BattleManager.enemy_data.enemy_fiends.has(actor_id):
		return
	var enemy_state: Dictionary = BattleManager.enemy_data.enemy_fiends[actor_id]
	if event_name != "last_breath" and int(enemy_state.get("current_health", 0)) <= 0:
		return

	var trait_ids = enemy_state.get("traits", [])
	if typeof(trait_ids) == TYPE_STRING:
		trait_ids = [trait_ids]
	if typeof(trait_ids) != TYPE_ARRAY:
		return

	for trait_id in trait_ids:
		var trait_id_str = str(trait_id)
		if trait_id_str == "":
			continue
		var trait_def = GameDataManager.get_trait_data(trait_id_str)
		if trait_def.is_empty() or str(trait_def.get("source_kind", "")) != "enemy":
			continue
		var matched_triggers: Array = []
		for trigger in trait_def.get("triggers", []):
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			if str(trigger.get("event", "")) != event_name:
				continue
			if not _trigger_conditions_match(trigger.get("conditions", {}), context, actor_id):
				continue
			matched_triggers.append(trigger)
		for trigger in matched_triggers:
			_execute_enemy_trigger(actor_id, trait_def, trigger, context)

func _execute_character_trigger(actor_id: String, trait_id: String, trait_def: Dictionary, trigger: Dictionary, context: Dictionary) -> void:
	var target_data = trait_def.get("target_data", [])
	if typeof(target_data) != TYPE_ARRAY:
		target_data = []
	var actions = trigger.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return
	var targets_by_index = _resolve_targets(actor_id, target_data, context, "player")
	_trait_debug("Character trigger matched", {
		"event": str(trigger.get("event", "")),
		"actor_id": actor_id,
		"trait_id": trait_id,
		"trait_name": str(trait_def.get("name", trait_id)),
		"targets": _summarize_targets_by_index(targets_by_index),
		"context": context
	})
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		_apply_character_action(action, targets_by_index, context, actor_id, trait_id)

func _execute_enemy_trigger(actor_id: String, trait_def: Dictionary, trigger: Dictionary, context: Dictionary) -> void:
	var target_data = trait_def.get("target_data", [])
	if typeof(target_data) != TYPE_ARRAY:
		target_data = []
	var actions = trigger.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return
	var targets_by_index = _resolve_targets(actor_id, target_data, context, "enemy")
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if str(action.get("type", "")) == "enable_battle_escape":
			BattleManager.enable_battle_escape_for_enemy(actor_id)
			continue
		_apply_character_action(action, targets_by_index)

func _execute_equipment_trigger(equipment_id: String, trait_id: String, trait_def: Dictionary, trigger: Dictionary, context: Dictionary) -> void:
	var target_data = trait_def.get("target_data", [])
	if typeof(target_data) != TYPE_ARRAY:
		target_data = []
	var actor_side := "enemy" if bool(context.get("equipment_is_enemy", false)) else "player"
	var targets_by_index = _resolve_targets("", target_data, context, actor_side)
	var actions = trigger.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return
	var action_results: Array = []
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			action_results.append(false)
			continue
		if _is_equipment_target_action(action):
			action_results.append(_apply_equipment_target_action(equipment_id, trait_id, action, targets_by_index, context, action_results))
			continue
		action_results.append(_apply_equipment_action(equipment_id, trait_id, trait_def, action, context, action_results))

func _execute_hex_trigger(actor_id: String, actor_side: String, trait_def: Dictionary, trigger: Dictionary, context: Dictionary) -> void:
	var target_data = trait_def.get("target_data", [])
	if typeof(target_data) != TYPE_ARRAY:
		target_data = []
	var actions = trigger.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return
	var targets_by_index = _resolve_targets(actor_id, target_data, context, actor_side)
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		_apply_character_action(action, targets_by_index)

func _resolve_targets(actor_id: String, target_data: Array, context: Dictionary, actor_side: String) -> Dictionary:
	var targets_by_index: Dictionary = {}
	for i in range(target_data.size()):
		var td = target_data[i]
		if typeof(td) != TYPE_DICTIONARY:
			continue
		var idx = int(td.get("index", i))
		targets_by_index[idx] = _resolve_single_target(actor_id, td, context, actor_side)
	return targets_by_index

func _resolve_single_target(actor_id: String, td: Dictionary, context: Dictionary, actor_side: String) -> Array:
	var targets: Array = []
	var target_type = int(td.get("type", 0))
	if target_type != 0:
		return targets

	var team = int(td.get("team", 0))
	var condition = td.get("condition", {})
	if typeof(condition) != TYPE_DICTIONARY:
		condition = {}

	var selector = str(condition.get("selector", ""))
	if condition.get("self", false) or selector == "self":
		return _filter_targets_by_status(_build_actor_target_list([actor_id], actor_side), condition)
	if BattleManager.supports_character_target_selector(selector):
		var selector_target_ids := BattleManager.get_character_target_ids_by_selector(
			selector,
			actor_side == "enemy",
			str(condition.get("status_id", ""))
		)
		var selector_side := _get_selector_target_side(selector, actor_side)
		return _filter_targets_by_status(_build_actor_target_list(selector_target_ids, selector_side), condition)

	match selector:
		"context_character_targets":
			var context_target_ids = context.get("character_target_ids", [])
			if typeof(context_target_ids) != TYPE_ARRAY:
				return []
			var filtered_ids: Array = []
			for raw_target_id in context_target_ids:
				var context_target_id = str(raw_target_id)
				if context_target_id == "":
					continue
				if actor_side == "player":
					if team == 0 and BattleManager.player_data.player_characters.has(context_target_id):
						filtered_ids.append(context_target_id)
					elif team == 1 and BattleManager.enemy_data.enemy_fiends.has(context_target_id):
						filtered_ids.append(context_target_id)
				else:
					if team == 0 and BattleManager.player_data.player_characters.has(context_target_id):
						filtered_ids.append(context_target_id)
					elif team == 1 and BattleManager.enemy_data.enemy_fiends.has(context_target_id):
						filtered_ids.append(context_target_id)
			var target_side = "enemy" if team == 1 else "player"
			return _filter_targets_by_status(_build_actor_target_list(filtered_ids, target_side), condition)
		"enemy_ally_all":
			if team == 1:
				return _filter_targets_by_status(_build_actor_target_list(BattleManager.enemy_data.enemy_fiends.keys(), "enemy"), condition)
		"enemy_ally_other":
			if actor_side == "enemy":
				var other_enemy_ids: Array = []
				for enemy_id in BattleManager.enemy_data.enemy_fiends.keys():
					var enemy_id_str = str(enemy_id)
					if enemy_id_str == actor_id:
						continue
					other_enemy_ids.append(enemy_id_str)
				return _filter_targets_by_status(_build_actor_target_list(other_enemy_ids, "enemy"), condition)
		"front_player":
			var front_player_id = _get_front_player_id()
			if front_player_id != "":
				return _filter_targets_by_status([{"name": front_player_id}], condition)
			return []
		"front_enemy":
			var front_enemy_id = _get_front_enemy_id()
			if front_enemy_id != "":
				return _filter_targets_by_status([{"name": front_enemy_id}], condition)
			return []
		"damage_source":
			var damage_source_id = _resolve_damage_source_target(context)
			if damage_source_id != "":
				return _filter_targets_by_status([{"name": damage_source_id}], condition)
			return []
		"front_equipment":
			var equipment_target = _get_face_up_equipment_target(team)
			if not equipment_target.is_empty():
				return _filter_targets_by_status([equipment_target], condition)
			return []
		"front_hex":
			var hex_target = _get_face_up_hex_target(team)
			if not hex_target.is_empty():
				return _filter_targets_by_status([hex_target], condition)
			return []

	var dice_reference = condition.get("dice_reference", {})
	if typeof(dice_reference) == TYPE_DICTIONARY and int(dice_reference.get("type", -1)) == 0 and int(dice_reference.get("face", -1)) == 0:
		if actor_side == "player" and team == 1:
			var enemy_id = _get_front_enemy_id()
			if enemy_id != "":
				targets.append({"name": enemy_id})
			return _filter_targets_by_status(targets, condition)
		if actor_side == "enemy" and team == 0:
			var player_id = _get_front_player_id()
			if player_id != "":
				targets.append({"name": player_id})
			return _filter_targets_by_status(targets, condition)
		if actor_side == "enemy" and team == 1:
			var ally_enemy_id = _get_front_enemy_id()
			if ally_enemy_id != "":
				targets.append({"name": ally_enemy_id})
			return _filter_targets_by_status(targets, condition)

	var target_id = str(context.get("target_id", ""))
	if target_id != "":
		if actor_side == "player":
			if team == 0 and BattleManager.player_data.player_characters.has(target_id):
				targets.append({"name": target_id})
				return _filter_targets_by_status(targets, condition)
			if team == 1 and BattleManager.enemy_data.enemy_fiends.has(target_id):
				targets.append({"name": target_id})
				return _filter_targets_by_status(targets, condition)
		else:
			if team == 0 and BattleManager.player_data.player_characters.has(target_id):
				targets.append({"name": target_id})
				return _filter_targets_by_status(targets, condition)
			if team == 1 and BattleManager.enemy_data.enemy_fiends.has(target_id):
				targets.append({"name": target_id})
				return _filter_targets_by_status(targets, condition)

	if actor_side == "player" and team == 0 and BattleManager.player_data.player_characters.has(actor_id):
		targets.append({"name": actor_id})
	elif actor_side == "enemy" and team == 1 and BattleManager.enemy_data.enemy_fiends.has(actor_id):
		targets.append({"name": actor_id})
	return _filter_targets_by_status(targets, condition)

func _build_actor_target_list(actor_ids: Array, actor_side: String) -> Array:
	var targets: Array = []
	for raw_actor_id in actor_ids:
		var resolved_actor_id = str(raw_actor_id)
		if resolved_actor_id == "":
			continue
		if not _actor_exists_on_side(resolved_actor_id, actor_side):
			continue
		targets.append({"name": resolved_actor_id})
	return targets

func _filter_targets_by_status(target_list: Array, condition: Dictionary) -> Array:
	var required_status_id = str(condition.get("has_status_id", ""))
	var excluded_status_id = str(condition.get("lacks_status_id", ""))
	if required_status_id == "" and excluded_status_id == "":
		return target_list
	var filtered: Array = []
	for target in target_list:
		if typeof(target) != TYPE_DICTIONARY:
			continue
		if required_status_id != "" and not BattleManager.has_status_on_target(target, required_status_id, ""):
			continue
		if excluded_status_id != "" and BattleManager.has_status_on_target(target, excluded_status_id, ""):
			continue
		filtered.append(target)
	return filtered

func _resolve_damage_source_target(context: Dictionary) -> String:
	var source_id = str(context.get("source_id", ""))
	if source_id != "":
		if BattleManager.player_data.player_characters.has(source_id) or BattleManager.enemy_data.enemy_fiends.has(source_id):
			return source_id
	return ""

func _actor_exists_on_side(actor_id: String, actor_side: String) -> bool:
	if actor_side == "enemy":
		return BattleManager.enemy_data.enemy_fiends.has(actor_id)
	return BattleManager.player_data.player_characters.has(actor_id)

func _get_face_up_enemy_id() -> String:
	return BattleManager.get_face_up_enemy_id()

func _get_face_up_player_id() -> String:
	return BattleManager.get_face_up_character_owner_id()

func _get_front_enemy_id() -> String:
	return BattleManager.get_front_enemy_id()

func _get_front_player_id() -> String:
	return BattleManager.get_front_character_owner_id()

func _get_selector_target_side(selector: String, actor_side: String) -> String:
	match selector:
		"front_ally", "back_ally", "lowest_health_ally", "highest_health_ally", "status_ally":
			return actor_side
		"front_enemy", "back_enemy", "lowest_health_enemy", "highest_health_enemy", "status_enemy":
			return "player" if actor_side == "enemy" else "enemy"
	return actor_side

func _get_face_up_equipment_target(team: int) -> Dictionary:
	var dice_type = "enemy_equipment" if team == 1 else "equipment"
	return BattleManager.get_face_up_dice_face_target(dice_type)

func _get_face_up_hex_target(team: int) -> Dictionary:
	var dice_type = "enemy_hex2" if team == 1 else "hex2"
	return BattleManager.get_face_up_dice_face_target(dice_type)

func _apply_character_action(action: Dictionary, targets_by_index: Dictionary, context: Dictionary = {}, actor_id: String = "", trait_id: String = "") -> void:
	var raw_action_type = action.get("type", -1)
	var action_type = int(raw_action_type) if typeof(raw_action_type) == TYPE_INT or typeof(raw_action_type) == TYPE_FLOAT else -1
	var action_type_name = str(raw_action_type) if typeof(raw_action_type) == TYPE_STRING else ""
	if action_type == -1 and action_type_name == "":
		return
	if action_type_name == "negate_status_apply_once":
		if actor_id == "" or trait_id == "":
			return
		var state = BattleManager.get_character_trait_state(actor_id, trait_id, {"used": false})
		if bool(state.get("used", false)):
			return
		state["used"] = true
		BattleManager.set_character_trait_state(actor_id, trait_id, state)
		context["negate_status_apply"] = true
		return
	var target_indices = action.get("target_index", [])
	if typeof(target_indices) != TYPE_ARRAY:
		target_indices = [target_indices]
	for target_index in target_indices:
		var idx = int(target_index)
		var targets = targets_by_index.get(idx, [])
		if typeof(targets) != TYPE_ARRAY:
			_trait_debug("Action target index missing", {
				"actor_id": actor_id,
				"trait_id": trait_id,
				"action_type": action_type_name if action_type_name != "" else action_type,
				"target_index": idx
			})
			continue
		if targets.is_empty():
			_trait_debug("Action resolved no targets", {
				"actor_id": actor_id,
				"trait_id": trait_id,
				"action_type": action_type_name if action_type_name != "" else action_type,
				"target_index": idx,
				"context": context
			})
		for target in targets:
			if typeof(target) != TYPE_DICTIONARY:
				continue
			var target_id = str(target.get("name", ""))
			var target_ref = target
			var target_label = target_id
			if target_label == "" and target.has("dice_type") and target.has("face_index"):
				target_label = "%s:%d" % [str(target.get("dice_type", "")), int(target.get("face_index", -1))]
			if target_id == "" and not (target.has("dice_type") and target.has("face_index")):
				continue
			_trait_debug("Applying character action", {
				"actor_id": actor_id,
				"trait_id": trait_id,
				"action_type": action_type_name if action_type_name != "" else action_type,
				"target_id": target_label,
				"target_index": idx,
				"action": action
			})
			match action_type:
				0:
					if target_id == "":
						continue
					var health_delta := int(action.get("value", 0))
					if health_delta > 0:
						BattleManager.apply_sourced_healing(target_id, health_delta, actor_id)
					else:
						BattleManager.update_character_health(target_id, health_delta)
				1:
					_apply_status_action(target_ref, action)
				3:
					if target_id == "":
						continue
					BattleManager.update_character_shield(target_id, int(action.get("value", 0)))
				_:
					match action_type_name:
						"health_change":
							if target_id == "":
								continue
							var named_health_delta := int(action.get("value", 0))
							if named_health_delta > 0:
								BattleManager.apply_sourced_healing(target_id, named_health_delta, actor_id)
							else:
								BattleManager.update_character_health(target_id, named_health_delta)
						"status_apply":
							_apply_status_action(target_ref, action)
						"shield_change":
							if target_id == "":
								continue
							BattleManager.update_character_shield(target_id, int(action.get("value", 0)))
						"modify_countdown":
							if target_id == "":
								continue
							BattleManager.modify_character_countdown(
								target_id,
								int(action.get("value", action.get("delta", 0))),
								bool(action.get("reset_to_base", false))
							)
						"retreat":
							if target_id == "":
								continue
							BattleManager.retreat_unit(target_id, int(action.get("steps", 0)))
						"advance":
							if target_id == "":
								continue
							BattleManager.advance_unit(target_id, int(action.get("steps", 0)))
						"remove_status":
							_remove_status_action(target_ref, action)
						"status_extend":
							_extend_status_action(target_ref, action)

func _apply_equipment_action(equipment_id: String, trait_id: String, trait_def: Dictionary, action: Dictionary, _context: Dictionary, action_results: Array) -> bool:
	var state = BattleManager.get_equipment_trait_state(equipment_id, trait_id, trait_def.get("runtime_defaults", {}))
	var action_type = str(action.get("type", ""))
	match action_type:
		"runtime_adjust":
			if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
				return false
			var key = str(action.get("key", ""))
			if key == "":
				return false
			if action.get("require_positive", false) and int(state.get(key, 0)) <= 0:
				return false
			var new_value = int(state.get(key, 0)) + int(action.get("delta", 0))
			new_value = max(new_value, int(action.get("min", -999999)))
			var max_key = str(action.get("max_key", ""))
			if max_key != "" and state.has(max_key):
				new_value = min(new_value, int(state.get(max_key, new_value)))
			state[key] = new_value
			BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
			return true
		"runtime_set":
			var set_key = str(action.get("key", ""))
			if set_key == "":
				return false
			var set_value = action.get("value")
			state[set_key] = set_value
			if set_key == "armed":
				if bool(set_value):
					state["armed_sequence_id"] = BattleManager.get_runtime_sequence_id()
				else:
					state["armed_sequence_id"] = -1
			BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
			return true
		"deal_front_enemy_damage":
			if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
				return false
			var target_id = BattleManager.get_front_enemy_id()
			if target_id == "":
				return false
			BattleManager.apply_equipment_trait_damage(equipment_id, target_id, int(action.get("value", 0)))
			return true
		"apply_equipment_status":
			if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
				return false
			var equipment_target := _build_face_up_equipment_status_target()
			if equipment_target.is_empty():
				return false
			_apply_status_action(equipment_target, action)
			return true
		"apply_face_up_equipment_status":
			if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
				return false
			var target_side := str(action.get("target_side", "ally"))
			var equipment_target := _build_face_up_equipment_status_target(target_side == "enemy")
			if equipment_target.is_empty():
				return false
			_apply_status_action(equipment_target, action)
			return true
		"remove_equipment_status":
			if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
				return false
			var equipment_target := _build_face_up_equipment_status_target()
			if equipment_target.is_empty():
				return false
			return _remove_status_action(equipment_target, action)
		"consume_ammo_or_reload":
			var ammo = int(state.get("ammo", 0))
			if ammo > 0:
				state["reloaded_sequence_id"] = -1
				state["ammo"] = ammo - 1
				BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
				var enemy_id = BattleManager.get_face_up_enemy_id()
				if enemy_id != "":
					var damage = int(action.get("damage", 0)) + BattleManager.get_equipment_forged_bonus_damage(equipment_id, "ammo")
					BattleManager.apply_equipment_trait_damage(equipment_id, enemy_id, damage)
					return true
				return false
			state["ammo"] = min(int(state.get("max_ammo", 0)), ammo + 1)
			state["reloaded_sequence_id"] = BattleManager.get_runtime_sequence_id()
			BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
			return true
		"consume_ammo_and_damage":
			if int(state.get("reloaded_sequence_id", -1)) == BattleManager.get_runtime_sequence_id():
				state["reloaded_sequence_id"] = -1
				BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
				return false
			var current_ammo = int(state.get("ammo", 0))
			if current_ammo <= 0:
				return false
			state["reloaded_sequence_id"] = -1
			state["ammo"] = current_ammo - 1
			BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
			var front_enemy_id = BattleManager.get_face_up_enemy_id()
			if front_enemy_id == "":
				return false
			var front_damage = int(action.get("damage", 0)) + BattleManager.get_equipment_forged_bonus_damage(equipment_id, "ammo")
			BattleManager.apply_equipment_trait_damage(equipment_id, front_enemy_id, front_damage)
			return true
		"negate_damage_if_armed":
			if not bool(state.get("armed", false)):
				return false
			if int(state.get("armed_sequence_id", -1)) != BattleManager.get_runtime_sequence_id():
				return false
			state["armed"] = false
			state["armed_sequence_id"] = -1
			BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
			BattleManager.negate_pending_enemy_action_damage()
			return true
	return false

func _is_equipment_target_action(action: Dictionary) -> bool:
	var action_type = str(action.get("type", ""))
	match action_type:
		"health_change", "status_apply", "shield_change", "modify_countdown", "retreat", "advance", "remove_status", "status_extend", "cycle_status_apply":
			return true
	return false

func _apply_equipment_target_action(equipment_id: String, trait_id: String, action: Dictionary, targets_by_index: Dictionary, context: Dictionary, action_results: Array) -> bool:
	if action.get("require_previous_action", false) and (action_results.is_empty() or not bool(action_results[-1])):
		return false
	var action_type := str(action.get("type", ""))
	if action_type == "cycle_status_apply":
		return _apply_equipment_cycle_status_action(equipment_id, trait_id, action, targets_by_index, context)
	var applied := false
	var target_indices = action.get("target_index", [])
	if typeof(target_indices) != TYPE_ARRAY:
		target_indices = [target_indices]
	for target_index in target_indices:
		var idx = int(target_index)
		var targets = targets_by_index.get(idx, [])
		if typeof(targets) != TYPE_ARRAY:
			continue
		for target in targets:
			if typeof(target) != TYPE_DICTIONARY:
				continue
			var target_id := str(target.get("name", ""))
			match action_type:
				"health_change":
					if target_id == "":
						continue
					var equipment_health_delta := int(action.get("value", 0))
					if equipment_health_delta > 0:
						BattleManager.apply_sourced_healing(target_id, equipment_health_delta, equipment_id)
					else:
						BattleManager.update_character_health(target_id, equipment_health_delta)
					applied = true
				"status_apply":
					_apply_status_action(target, action)
					applied = true
				"shield_change":
					if target_id == "":
						continue
					BattleManager.update_character_shield(target_id, int(action.get("value", 0)))
					applied = true
				"modify_countdown":
					if target_id == "":
						continue
					BattleManager.modify_character_countdown(
						target_id,
						int(action.get("value", action.get("delta", 0))),
						bool(action.get("reset_to_base", false))
					)
					applied = true
				"retreat":
					if target_id == "":
						continue
					BattleManager.retreat_unit(target_id, int(action.get("steps", 0)))
					applied = true
				"advance":
					if target_id == "":
						continue
					BattleManager.advance_unit(target_id, int(action.get("steps", 0)))
					applied = true
				"remove_status":
					if _remove_status_action(target, action):
						applied = true
				"status_extend":
					_extend_status_action(target, action)
					applied = true
	return applied

func _apply_equipment_cycle_status_action(equipment_id: String, trait_id: String, action: Dictionary, targets_by_index: Dictionary, context: Dictionary) -> bool:
	var key := str(action.get("key", ""))
	var threshold := int(action.get("threshold", 0))
	if key == "" or threshold <= 0:
		return false
	var trait_def = GameDataManager.get_trait_data(trait_id)
	var state = BattleManager.get_equipment_trait_state(equipment_id, trait_id, trait_def.get("runtime_defaults", {}))
	var next_value := int(state.get(key, 0)) + int(action.get("delta", 1))
	var should_apply := next_value >= threshold
	if should_apply:
		next_value = int(action.get("reset_to", next_value - threshold))
	else:
		next_value = max(next_value, int(action.get("min", 0)))
	state[key] = next_value
	BattleManager.set_equipment_trait_state(equipment_id, trait_id, state)
	if not should_apply:
		return false
	var apply_action := action.duplicate(true)
	apply_action["type"] = "status_apply"
	return _apply_equipment_target_action(equipment_id, trait_id, apply_action, targets_by_index, context, [])

func _build_face_up_equipment_status_target(is_enemy: bool = false) -> Dictionary:
	return BattleManager.get_face_up_dice_face_target("enemy_equipment" if is_enemy else "equipment")

func _apply_status_action(target_ref, action: Dictionary) -> void:
	var status_id = str(action.get("status_id", ""))
	if status_id == "":
		_trait_debug("status_apply aborted: missing status_id", {"target_id": str(target_ref), "action": action})
		return
	var status_data = GameDataManager.get_status_data(status_id)
	if status_data.is_empty():
		_trait_debug("status_apply aborted: status data not found", {"target_id": str(target_ref), "status_id": status_id})
		return
	var status_info = status_data.duplicate(true)
	if action.has("duration"):
		var duration_override := int(action.get("duration", status_info.get("duration", 0)))
		var target_already_has_status := BattleManager.has_status_on_target(target_ref, status_id, "")
		# In trait data, duration=0 is used by stack-only refreshes such as Burn spread.
		# Preserve that behavior only when the target already has the status.
		if duration_override != 0 or target_already_has_status:
			status_info["duration"] = duration_override
	if action.has("stack_count"):
		status_info["stack_count"] = int(action.get("stack_count", status_info.get("stack_count", 1)))
	if action.has("max_stacks"):
		status_info["max_stacks"] = int(action.get("max_stacks", status_info.get("max_stacks", -1)))
	_trait_debug("status_apply resolved", {
		"target_id": str(target_ref),
		"status_id": status_id,
		"status_name": str(status_info.get("status_name", "")),
		"duration": int(status_info.get("duration", 0)),
		"stack_count": int(status_info.get("stack_count", 1)),
		"max_stacks": int(status_info.get("max_stacks", -1))
	})
	var effect = {"status_info": status_info}
	BattleManager.apply_status(effect, [target_ref])

func _remove_status_action(target_ref, action: Dictionary) -> bool:
	var status_id = str(action.get("status_id", ""))
	var status_name = str(action.get("status_name", ""))
	return BattleManager.remove_status_from_target(target_ref, status_name, status_id)

func _extend_status_action(target_ref, action: Dictionary) -> void:
	var status_id = str(action.get("status_id", ""))
	if status_id == "":
		_trait_debug("status_extend aborted: missing status_id", {"target_id": str(target_ref), "action": action})
		return
	var duration_delta = int(action.get("duration", action.get("delta", 0)))
	if duration_delta <= 0:
		_trait_debug("status_extend aborted: non-positive duration", {
			"target_id": str(target_ref),
			"status_id": status_id,
			"duration": duration_delta
		})
		return
	var changed = BattleManager.extend_status_on_target(target_ref, status_id, duration_delta)
	_trait_debug("status_extend resolved", {
		"target_id": str(target_ref),
		"status_id": status_id,
		"duration": duration_delta,
		"changed": changed
	})

func _trigger_conditions_match(raw_conditions, context: Dictionary, actor_id: String = "") -> bool:
	if typeof(raw_conditions) != TYPE_DICTIONARY:
		return true
	var status_id = str(raw_conditions.get("status_id", ""))
	if status_id != "" and str(context.get("status_id", "")) != status_id:
		return false
	if raw_conditions.has("status_type") and int(context.get("status_type", -9999)) != int(raw_conditions.get("status_type", -9998)):
		return false
	var target_team = str(raw_conditions.get("target_team", ""))
	if target_team != "" and str(context.get("target_team", "")) != target_team:
		return false
	var hex_id = str(raw_conditions.get("hex_id", ""))
	if hex_id != "" and str(context.get("hex_id", "")) != hex_id:
		return false
	var actor_side = str(raw_conditions.get("actor_side", ""))
	if actor_side != "" and str(context.get("actor_side", "")) != actor_side:
		return false
	if raw_conditions.has("trigger_face") and int(context.get("trigger_face", -9999)) != int(raw_conditions.get("trigger_face", -9998)):
		return false
	if raw_conditions.has("effect_type"):
		var effect = context.get("effect", {})
		if typeof(effect) != TYPE_DICTIONARY or int(effect.get("type", -9999)) != int(raw_conditions.get("effect_type", -9998)):
			return false
	if raw_conditions.has("effect_index") and int(context.get("effect_index", -9999)) != int(raw_conditions.get("effect_index", -9998)):
		return false
	var damage_kind = str(raw_conditions.get("damage_kind", ""))
	if damage_kind != "" and str(context.get("damage_kind", "")) != damage_kind:
		return false
	var excluded_damage_kind = str(raw_conditions.get("exclude_damage_kind", ""))
	if excluded_damage_kind != "" and str(context.get("damage_kind", "")) == excluded_damage_kind:
		return false
	if raw_conditions.has("is_direct_spell_damage") and bool(context.get("is_direct_spell_damage", false)) != bool(raw_conditions.get("is_direct_spell_damage", false)):
		return false
	if raw_conditions.has("is_resonance_damage") and bool(context.get("is_resonance_damage", false)) != bool(raw_conditions.get("is_resonance_damage", false)):
		return false
	if actor_id != "":
		if bool(raw_conditions.get("self_cast_only", false)) and str(context.get("actor_id", "")) != actor_id:
			return false
		if bool(raw_conditions.get("battle_escape_not_triggered_for_self", false)) and BattleManager.has_battle_escape_triggered_for_enemy(actor_id):
			return false
		if raw_conditions.has("self_health_ratio_lte"):
			var max_health = float(context.get("max_health", 0))
			if max_health <= 0.0:
				return false
			var new_health = float(context.get("new_health", max_health))
			if (new_health / max_health) > float(raw_conditions.get("self_health_ratio_lte", 1.0)):
				return false
		var requires_status_id = str(raw_conditions.get("self_has_status_id", ""))
		if requires_status_id != "" and not _actor_has_status(actor_id, requires_status_id):
			return false
		var excludes_status_id = str(raw_conditions.get("self_lacks_status_id", ""))
		if excludes_status_id != "" and _actor_has_status(actor_id, excludes_status_id):
			return false
	else:
		var equipment_requires_status_id = str(raw_conditions.get("self_has_status_id", ""))
		var is_enemy_equipment := bool(context.get("equipment_is_enemy", false))
		if equipment_requires_status_id != "" and not BattleManager.has_status_on_target(_build_face_up_equipment_status_target(is_enemy_equipment), equipment_requires_status_id, ""):
			return false
		var equipment_excludes_status_id = str(raw_conditions.get("self_lacks_status_id", ""))
		if equipment_excludes_status_id != "" and BattleManager.has_status_on_target(_build_face_up_equipment_status_target(is_enemy_equipment), equipment_excludes_status_id, ""):
			return false
	return true

func _actor_has_status(actor_id: String, status_id: String) -> bool:
	if actor_id == "" or status_id == "":
		return false
	return BattleManager.has_character_status(actor_id, status_id, "")
