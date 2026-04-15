extends Node

signal allied_health_changed(amount)
signal enemy_health_changed(amount)
signal allied_shield_changed(player_character, remaining_shield)
signal enemy_shield_changed(enemy_character, remaining_shield)
signal battle_won
signal dice_status_changed(dice_type, effects)
signal face_status_changed(dice_type, face_index, effects)
signal character_status_changed
signal character_countdown_changed(target_id, countdown)
signal on_tick_after(context)
signal on_frien_roll_after(context)
signal on_self_action_before(context)
signal on_countdown_before(context)
signal on_damage_dealt(context)
signal on_damage_taken(context)
signal on_self_show(context)
signal on_self_perform(context)
signal on_character_death(context)
signal health_queue_flushed
signal battle_escape_state_changed(is_available, enemy_id)
signal enemy_timed_escape(enemy_id, enemy_name)
signal battle_layout_changed
signal spell_visual_requested(payload)
signal battle_simulation_completed(summary: Dictionary)

var player_data = PlayerData.new()
var enemy_data = EnemyTeam.new()
var rolled_dice: Array =[]
var battle_result: String = ""


var is_test_mode: bool = false
var is_simulation_mode: bool = false
var simulation_fast_mode: bool = false
var is_tutorial_battle: bool = false
var test_reroll_count: int = 0  
var test_player_state: Dictionary = {}
var test_enemy_state: Dictionary = {}
var simulation_context: Dictionary = {}
var current_battle_stats: Dictionary = {}
var last_battle_summary: Dictionary = {}

# Status Storage for non-character targets
var dice_statuses: Dictionary = {} # { "dice_type": { "status_name": { ... } } }
var face_statuses: Dictionary = {} # { "dice_type": { face_index: { "status_name": { ... } } } }
var _last_face_up: Dictionary = {}
var _last_face_down: Dictionary = {}
var _tick_control_flags: Dictionary = {}
var equipment_trait_states: Dictionary = {}
var _pending_enemy_action_damage_negated: bool = false

var current_caster = null
var last_target = null
var _forced_equipment_context: Dictionary = {}
var countdown_zero_context: Dictionary = {}
var _last_roll_context: Dictionary = {}
var _runtime_sequence_id: int = 0
var _status_apply_order_counter: int = 0
var _current_spell_context: Dictionary = {}
var _swift_hex_skip_context: Dictionary = {}
const HEALTH_QUEUE_INTERVAL: float = 0.5
var _health_change_queue: Array = []
var _health_queue_processing: bool = false
var _battle_end_scene_transition_requested: bool = false
const INVALID_ROOM_POS := Vector2i(-999999, -999999)
const TIMED_ESCAPE_MARKER_DEFAULT := "pipeling"
const TIMED_ESCAPE_MODE_TICK := "tick"
const TIMED_ESCAPE_MODE_ACTION_STATUS := "action_status"
const BATTLE_LAYOUT_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const BATTLE_LAYOUT_SAFE_MARGIN_X := 48.0
const BATTLE_LAYOUT_TOP_MARGIN := 56.0
const BATTLE_LAYOUT_BOTTOM_MARGIN := 56.0
const BATTLE_LAYOUT_BASELINE_Y := 600.0
const BATTLE_LAYOUT_ALLY_REGION := Rect2(BATTLE_LAYOUT_SAFE_MARGIN_X, 0.0, 780.0, BATTLE_LAYOUT_VIEWPORT_SIZE.y)
const BATTLE_LAYOUT_ENEMY_REGION := Rect2(1092.0, 0.0, 780.0, BATTLE_LAYOUT_VIEWPORT_SIZE.y)
const BATTLE_LAYOUT_DEFAULT_GAP := 8.0
const BATTLE_LAYOUT_MIN_GAP := 4.0
const BATTLE_LAYOUT_MIN_SCALE_FACTOR := 0.72
const BATTLE_LAYOUT_HEALTH_BAR_WIDTH_SCALE := 1.08
const ROLL_BIAS_STRENGTH := 0.9
const ROLL_BIAS_MEMORY_DECAY := 0.82
const ROLL_BIAS_MIN_MULTIPLIER := 0.2
const BATTLE_LAYOUT_MIN_STATUS_WIDTH := 180.0
const BATTLE_LAYOUT_MAX_STATUS_WIDTH := 200.0
const FRONT_UNIT_MOVE_DURATION := 0.2
const BATTLE_LAYOUT_TRANSITION_GAP := 0.1
var _special_battle_state: Dictionary = {
	"escape_available": false,
	"escape_source_enemy_id": "",
	"escape_triggered_enemy_ids": {}
}
var _battle_layout_refresh_queued: bool = false
var _battle_layout_transition_tween: Tween = null
var _battle_layout_position_lock: bool = false
var _ally_display_order: Array[String] = []
var _enemy_display_order: Array[String] = []
var _roll_bias_state: Dictionary = {}

var current_battle_type: BattleType = BattleType.BATTLE

enum BattleType {BATTLE, ELITE_BATTLE, BOSS_BATTLE}
enum TargetTeam { ALLY, ENEMY }
enum TargetType { CHARACTER, DICEFACE, DICE }
enum DiceType { FRIEND, ACTION, HEX }
enum DiceFace { UP, DOWN, SIDE }

enum EffectType { HEALTH_CHANGE, STATUS_APPLY, SPECIAL, SHIELD_CHANGE }
enum StatusType { BUFF, DEBUFF, SPECIAL }
enum Category { DoT, DAMAGE_MOD, CROWD_CONTROL, AGGRO }
enum StatusTarget { CHARACTER, DICE, DICE_FACE }
enum StatusTickPhase { GLOBAL_TICK, AFTER_ACTION }



class PlayerData:
	var player_characters: Dictionary = {}
	func init_characters(char_data: CharacterData):
		var countdown_value = 5
		var char_countdown = char_data.get("countdown")
		if typeof(char_countdown) != TYPE_NIL:
			countdown_value = int(char_countdown)
		var character_state = {
			"name": char_data.character_name,
			"texture_path": str(char_data.texture_path),
			"portrait_texture_path": BattleManager._resolve_player_portrait_texture(char_data.id, char_data.character_name, char_data.texture_path),
			"current_health": char_data.health,
			"max_health": char_data.health,
			"traits": char_data.traits,
			"shield": 0,
			"countdown": countdown_value,
			"base_countdown": countdown_value,
			"status_effects": {}, # { "poison": {"duration": 3, "stacks": 1, "type": StatusType.DEBUFF} }
			"trait_runtime": {}
		}
		player_characters[char_data.character_name] = character_state

class EnemyTeam:
	var enemy_fiends: Dictionary = {}
	func init_enemies(enemy_data: EnemyData):
		var countdown_value = 5
		var enemy_countdown = enemy_data.get("countdown")
		if typeof(enemy_countdown) != TYPE_NIL:
			countdown_value = int(enemy_countdown)
		# Use unique_id if available, otherwise fallback to enemy_name
		var id = enemy_data.unique_id if enemy_data.unique_id != "" else enemy_data.enemy_name
		
		var enemy_state = {
			"name": id,
			"enemy_name": enemy_data.enemy_name, # Store base name for reference
			"enemy_template_id": enemy_data.id,
			"texture_path": enemy_data.texture_path,
			"portrait_texture_path": BattleManager._resolve_enemy_portrait_texture(enemy_data.id, enemy_data.enemy_name, enemy_data.texture_path),
			"current_health": enemy_data.health,
			"max_health": enemy_data.health,
			"traits": enemy_data.traits,
			"equipment": enemy_data.equipment.duplicate(),
			"hexes": enemy_data.hexes.duplicate(),
			"health_per_occupied_face": enemy_data.health_per_occupied_face,
			"shield": 0,
			"countdown": countdown_value,
			"base_countdown": countdown_value,
			"status_effects": {},
			"trait_runtime": {},
			"timed_escape_state": BattleManager._build_initial_timed_escape_state(enemy_data)
		}
		enemy_fiends[id] = enemy_state

# ... (enum definitions remain same) ...

func apply_status(effect: Dictionary, targets: Array, read_targets: Array = []) -> void:
	var status_def = _resolve_status_definition(effect, read_targets)
	if status_def.is_empty():
		print("[BattleManager] Error: Empty or invalid status definition: ", effect)
		return

	var status_name = _get_status_runtime_key(status_def)
	var status_target = int(status_def.get("status_target", StatusTarget.CHARACTER))
	var resolved_targets := _expand_replica_group_targets_for_status(status_def, targets)
	for target in resolved_targets:
		match status_target:
			StatusTarget.CHARACTER:
				var target_id = _resolve_runtime_entity_id(target)
				if target_id == "":
					continue
				var char_state = _get_character_state(target_id)
				if char_state == null:
					continue
				var target_team = "ally" if player_data.player_characters.has(target_id) else "enemy"
				var pre_apply_context := {
					"status_id": str(status_def.get("id", "")),
					"status_name": status_name,
					"status_type": int(status_def.get("status_type", StatusType.DEBUFF)),
					"target_id": target_id,
					"target_team": target_team
				}
				if TraitManager:
					TraitManager.trigger_actor_event_for_actor(target_id, "status_applied_before", pre_apply_context)
				if bool(pre_apply_context.get("negate_status_apply", false)):
					continue
				if not _apply_status_to_map(char_state.status_effects, status_name, status_def):
					continue
				emit_signal("character_status_changed", target_id, char_state.status_effects)
				_handle_character_status_applied(target_id, target_team, status_def)
				trigger_equipment_trait_event("", "status_applied_after", {
					"status_id": str(status_def.get("id", "")),
					"target_id": target_id,
					"target_team": target_team
				})
			StatusTarget.DICE:
				if not target.has("dice_type") or target.has("face_index"):
					continue
				var dice_type = str(target.dice_type)
				if not dice_statuses.has(dice_type):
					dice_statuses[dice_type] = {}
				if not _apply_status_to_map(dice_statuses[dice_type], status_name, status_def):
					continue
				emit_signal("dice_status_changed", dice_type, dice_statuses[dice_type])
			StatusTarget.DICE_FACE:
				if not target.has("dice_type") or not target.has("face_index"):
					continue
				var d_type = str(target.dice_type)
				var face_index = int(target.face_index)
				if not face_statuses.has(d_type):
					face_statuses[d_type] = {}
				if not face_statuses[d_type].has(face_index):
					face_statuses[d_type][face_index] = {}
				if not _apply_status_to_map(face_statuses[d_type][face_index], status_name, status_def):
					continue
				emit_signal("face_status_changed", d_type, face_index, face_statuses[d_type][face_index])

func _resolve_status_apply_stack_count(effect: Dictionary, read_targets: Array, base_stack_count: int) -> int:
	return base_stack_count + _get_effect_read_bonus(effect, read_targets)

func _resolve_status_definition(effect: Dictionary, read_targets: Array = []) -> Dictionary:
	var info = effect.get("status_info", {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var status_id = str(info.get("id", effect.get("status_id", "")))
	var base_data = {}
	if status_id != "":
		base_data = GameDataManager.get_status_data(status_id)
	elif str(info.get("status_name", "")) != "":
		base_data = GameDataManager.get_status_data_by_name(str(info.get("status_name", "")))
		status_id = str(base_data.get("id", ""))
	var resolved = base_data.duplicate(true)
	for key in info.keys():
		resolved[key] = info[key]
	if status_id != "":
		resolved["id"] = status_id
	var duration = resolved.get("duration", 0)
	if not info.has("duration"):
		duration = base_data.get("duration", duration)
	resolved["duration"] = int(duration)
	var stacks = resolved.get("stack_count", 1)
	if not info.has("stack_count"):
		stacks = base_data.get("stack_count", stacks)
	resolved["stack_count"] = _resolve_status_apply_stack_count(effect, read_targets, int(stacks))
	var max_stacks = resolved.get("max_stacks", -1)
	if not info.has("max_stacks"):
		max_stacks = base_data.get("max_stacks", max_stacks)
	resolved["max_stacks"] = int(max_stacks)
	resolved["status_type"] = int(resolved.get("status_type", StatusType.DEBUFF))
	resolved["category"] = int(resolved.get("category", Category.DoT))
	resolved["status_target"] = int(resolved.get("status_target", StatusTarget.CHARACTER))
	if not resolved.has("effects") or typeof(resolved.effects) != TYPE_DICTIONARY:
		resolved["effects"] = {}
	return resolved

func _expand_replica_group_targets_for_status(status_def: Dictionary, targets: Array) -> Array:
	var status_id := str(status_def.get("id", ""))
	if status_id != "st014" and status_id != "st015" and status_id != "st018" and status_id != "st019":
		return targets
	var expanded: Array = []
	var seen_keys: Dictionary = {}
	for target in targets:
		if typeof(target) != TYPE_DICTIONARY:
			_append_unique_status_target(expanded, seen_keys, target)
			continue
		var dice_type := str(target.get("dice_type", ""))
		var face_index := int(target.get("face_index", -1))
		if face_index < 0 or not _status_should_expand_to_replica_group(status_id, dice_type):
			_append_unique_status_target(expanded, seen_keys, target)
			continue
		var content_id := _get_face_content_id(dice_type, face_index)
		if content_id == "":
			_append_unique_status_target(expanded, seen_keys, target)
			continue
		for replica_face_index in _get_matching_face_indices_by_content_id(dice_type, content_id):
			var replica_target: Dictionary = target.duplicate(true)
			replica_target["face_index"] = replica_face_index
			_append_unique_status_target(expanded, seen_keys, replica_target)
	return expanded if not expanded.is_empty() else targets

func _append_unique_status_target(expanded: Array, seen_keys: Dictionary, target) -> void:
	var key := ""
	if typeof(target) == TYPE_DICTIONARY:
		var dice_type := str(target.get("dice_type", ""))
		if dice_type != "" and target.has("face_index"):
			key = "face:%s:%d" % [dice_type, int(target.get("face_index", -1))]
		elif dice_type != "":
			key = "dice:%s" % dice_type
		else:
			key = "entity:%s" % JSON.stringify(target)
	else:
		key = "value:%s" % str(target)
	if seen_keys.has(key):
		return
	seen_keys[key] = true
	expanded.append(target)

func _status_should_expand_to_replica_group(status_id: String, dice_type: String) -> bool:
	match status_id:
		"st014", "st018", "st019":
			return dice_type == "equipment" or dice_type == "enemy_equipment"
		"st015":
			return dice_type == "hex2" or dice_type == "enemy_hex2"
	return false

func _get_status_runtime_key(status_def: Dictionary) -> String:
	var status_id := str(status_def.get("id", ""))
	if status_id != "":
		return status_id
	return str(status_def.get("legacy_name", status_def.get("status_name", "")))

func _is_status_effectively_active(status: Dictionary) -> bool:
	if typeof(status) != TYPE_DICTIONARY or status.is_empty():
		return false
	var duration = int(status.get("duration", 0))
	var stacks = int(status.get("stacks", 1))
	if stacks <= 0:
		return false
	if duration == 0 and duration != -1:
		return false
	return true

func _should_prune_status(status: Dictionary) -> bool:
	return not _is_status_effectively_active(status)

func _apply_status_to_map(status_map: Dictionary, status_name: String, status_def: Dictionary) -> bool:
	if status_name == "":
		return false
	var incoming_duration = int(status_def.get("duration", 0))
	var incoming_stacks = int(status_def.get("stack_count", 1))
	var incoming_max_stacks = int(status_def.get("max_stacks", -1))
	var incoming_effects = status_def.get("effects", {}).duplicate(true)
	var applied_sequence_id = _runtime_sequence_id
	_status_apply_order_counter += 1
	var applied_order = _status_apply_order_counter
	if status_map.has(status_name):
		var existing = status_map[status_name]
		# Keep the original applied_sequence_id when refreshing an existing status.
		# This allows effects like t001 adding Burn stacks to preserve the current
		# tick eligibility of the already-active Burn instance.
		existing.duration = max(int(existing.get("duration", 0)), incoming_duration)
		var next_stacks = int(existing.get("stacks", 1)) + incoming_stacks
		var effective_max_stacks = incoming_max_stacks
		if effective_max_stacks < 0:
			effective_max_stacks = int(existing.get("max_stacks", -1))
		if effective_max_stacks >= 0:
			next_stacks = min(next_stacks, effective_max_stacks)
		existing.stacks = next_stacks
		existing.status_type = int(status_def.get("status_type", existing.get("status_type", StatusType.DEBUFF)))
		existing.category = int(status_def.get("category", existing.get("category", Category.DoT)))
		existing.status_target = int(status_def.get("status_target", existing.get("status_target", StatusTarget.CHARACTER)))
		existing.max_stacks = effective_max_stacks
		if not incoming_effects.is_empty():
			existing.effects = incoming_effects
		existing.id = str(status_def.get("id", existing.get("id", "")))
		existing.applied_order = applied_order
		if _should_prune_status(existing):
			status_map.erase(status_name)
			return false
		return true
	else:
		var initial_stacks = incoming_stacks
		if incoming_max_stacks >= 0:
			initial_stacks = min(initial_stacks, incoming_max_stacks)
		var status_instance = {
			"id": str(status_def.get("id", "")),
			"status_name": status_name,
			"status_type": int(status_def.get("status_type", StatusType.DEBUFF)),
			"category": int(status_def.get("category", Category.DoT)),
			"status_target": int(status_def.get("status_target", StatusTarget.CHARACTER)),
			"duration": incoming_duration,
			"stacks": initial_stacks,
			"max_stacks": incoming_max_stacks,
			"effects": incoming_effects,
			"applied_sequence_id": applied_sequence_id,
			"applied_order": applied_order
		}
		if _is_status_effectively_active(status_instance):
			status_map[status_name] = status_instance
			return true
	return false

func _extend_status_in_map(status_map: Dictionary, status_name: String, duration_delta: int) -> bool:
	if typeof(status_map) != TYPE_DICTIONARY or status_name == "" or duration_delta <= 0:
		return false
	if not status_map.has(status_name):
		return false
	var status = status_map[status_name]
	if not _is_status_effectively_active(status):
		status_map.erase(status_name)
		return false
	var duration = int(status.get("duration", 0))
	if duration < 0:
		return false
	status.duration = duration + duration_delta
	return true

func _should_skip_status_tick_for_context(status: Dictionary, tick_context: Dictionary) -> bool:
	var tick_sequence_id = int(tick_context.get("sequence_id", -1))
	if tick_sequence_id < 0:
		return false
	return int(status.get("applied_sequence_id", -2)) == tick_sequence_id

func _should_defer_countdown_delta_for_target(target_id: String) -> bool:
	if target_id == "":
		return false
	if not countdown_zero_context.has(target_id):
		return false
	var countdown_ctx = countdown_zero_context.get(target_id, {})
	if typeof(countdown_ctx) != TYPE_DICTIONARY:
		return false
	return int(countdown_ctx.get("sequence_id", -1)) == _runtime_sequence_id

func _queue_deferred_countdown_delta(target_id: String, delta: int) -> void:
	if target_id == "" or delta == 0:
		return
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return
	char_state["deferred_countdown_delta"] = int(char_state.get("deferred_countdown_delta", 0)) + delta

func _apply_or_defer_countdown_delta(target_id: String, delta: int) -> void:
	if target_id == "" or delta == 0:
		return
	if _should_defer_countdown_delta_for_target(target_id):
		_queue_deferred_countdown_delta(target_id, delta)
		return
	modify_character_countdown(target_id, delta)

func _consume_deferred_countdown_delta(target_id: String) -> int:
	if target_id == "":
		return 0
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return 0
	var deferred_delta = int(char_state.get("deferred_countdown_delta", 0))
	char_state["deferred_countdown_delta"] = 0
	return deferred_delta

func _handle_character_status_applied(target_id: String, target_team: String, status_def: Dictionary) -> void:
	var effects = status_def.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return
	var self_countdown_delta = int(effects.get("on_apply_self_countdown_delta", 0))
	if self_countdown_delta != 0:
		_apply_or_defer_countdown_delta(target_id, self_countdown_delta)
	var same_team_countdown_delta = int(effects.get("on_apply_same_team_countdown_delta", 0))
	if same_team_countdown_delta == 0:
		return
	var team_dict = player_data.player_characters if target_team == "ally" else enemy_data.enemy_fiends
	for teammate_id in team_dict.keys():
		_apply_or_defer_countdown_delta(str(teammate_id), same_team_countdown_delta)

func _begin_spell_resolution(caster_id: String, is_enemy_spell: bool, hex_data: HexData) -> void:
	var spell_id := ""
	var spell_name := ""
	if hex_data != null:
		spell_id = str(hex_data.id)
		spell_name = str(hex_data.hex_name)
	_current_spell_context = {
		"actor_id": caster_id,
		"is_enemy_spell": is_enemy_spell,
		"spell_id": spell_id,
		"spell_name": spell_name,
		"character_target_ids": [],
		"initial_health_queue_delay_remaining": _get_spell_visual_health_delay(spell_id)
	}

func _build_hex_trait_context(hex_data: HexData, trigger_face: int, caster_is_enemy: bool, extras: Dictionary = {}) -> Dictionary:
	var context = _current_spell_context.duplicate(true)
	if context.is_empty():
		context = {}
		context["actor_id"] = _resolve_runtime_entity_id(current_caster)
		context["is_enemy_spell"] = caster_is_enemy
		context["spell_id"] = str(hex_data.id) if hex_data != null else ""
		context["spell_name"] = str(hex_data.hex_name) if hex_data != null else ""
		context["character_target_ids"] = []
	context["actor_side"] = "enemy" if caster_is_enemy else "player"
	context["hex_id"] = str(hex_data.id) if hex_data != null else str(context.get("spell_id", ""))
	context["hex_name"] = str(hex_data.hex_name) if hex_data != null else str(context.get("spell_name", ""))
	context["trigger_face"] = trigger_face
	context["is_enemy_spell"] = caster_is_enemy
	if not context.has("character_target_ids") or typeof(context.get("character_target_ids", [])) != TYPE_ARRAY:
		context["character_target_ids"] = []
	for key in extras.keys():
		context[key] = extras[key]
	return context

func _trigger_hex_trait_event(hex_data: HexData, event_name: String, trigger_face: int, caster_is_enemy: bool, extras: Dictionary = {}) -> void:
	if hex_data == null:
		return
	var hex_id = str(hex_data.id)
	if hex_id == "":
		return
	TraitManager.trigger_hex_traits(hex_id, event_name, _build_hex_trait_context(hex_data, trigger_face, caster_is_enemy, extras))

func _hex_has_trait(hex_data: HexData, trait_id: String = "", trait_name: String = "") -> bool:
	if hex_data == null:
		return false
	if typeof(hex_data.traits) != TYPE_ARRAY:
		return false
	for raw_trait_id in hex_data.traits:
		var resolved_trait_id = str(raw_trait_id)
		if resolved_trait_id == "":
			continue
		if trait_id != "" and resolved_trait_id == trait_id:
			return true
		if trait_name != "":
			var trait_def = GameDataManager.get_trait_data(resolved_trait_id)
			if not trait_def.is_empty() and str(trait_def.get("name", "")) == trait_name:
				return true
	return false

func _register_swift_hex_skip(actor_id: String, hex_id: String) -> void:
	if actor_id == "" or hex_id == "":
		return
	_swift_hex_skip_context[actor_id] = {
		"hex_id": hex_id,
		"sequence_id": _runtime_sequence_id
	}

func _should_skip_swift_hex_action(actor_id: String, hex_id: String, countdown_ctx) -> bool:
	if actor_id == "" or hex_id == "":
		return false
	if typeof(countdown_ctx) != TYPE_DICTIONARY:
		return false
	if not _swift_hex_skip_context.has(actor_id):
		return false
	var skip_ctx = _swift_hex_skip_context.get(actor_id, {})
	if typeof(skip_ctx) != TYPE_DICTIONARY:
		return false
	if str(skip_ctx.get("hex_id", "")) != hex_id:
		return false
	if int(skip_ctx.get("sequence_id", -1)) != int(countdown_ctx.get("sequence_id", -2)):
		return false
	_swift_hex_skip_context.erase(actor_id)
	return true

func _try_trigger_swift_hex_on_roll(dice_type: String, _face_up_value: int) -> void:
	var is_enemy = dice_type == "enemy_hex2"
	if dice_type != "hex2" and not is_enemy:
		return
	var hex_info = _get_hex_face_up(is_enemy)
	var hex_data = hex_info.get("hex_data", null)
	if hex_data == null or hex_data.hex_name == "":
		return
	if not _hex_has_trait(hex_data, "", "swift"):
		return
	var actor_id = get_front_enemy_id() if is_enemy else get_front_character_owner_id()
	if actor_id == "":
		return
	_register_swift_hex_skip(actor_id, str(hex_data.id))
	if is_enemy:
		await cast_enemy_hex(hex_data, actor_id, DiceFace.UP)
	else:
		var caster_ref = {"character_name": actor_id, "name": actor_id}
		await cast_hex(hex_data, caster_ref, DiceFace.UP)


func _clear_spell_resolution_context() -> void:
	_current_spell_context = {}

func _record_spell_character_target(target_id: String) -> void:
	if _current_spell_context.is_empty():
		return
	if target_id == "":
		return
	if not player_data.player_characters.has(target_id) and not enemy_data.enemy_fiends.has(target_id):
		return
	var character_target_ids = _current_spell_context.get("character_target_ids", [])
	if typeof(character_target_ids) != TYPE_ARRAY:
		character_target_ids = []
	if character_target_ids.has(target_id):
		return
	character_target_ids.append(target_id)
	_current_spell_context["character_target_ids"] = character_target_ids

func _record_spell_character_targets(targets: Array) -> void:
	for target in targets:
		var target_id = _resolve_runtime_entity_id(target)
		if target_id == "":
			continue
		_record_spell_character_target(target_id)

func _finish_enemy_spell_resolution() -> void:
	if _current_spell_context.is_empty():
		return
	if not bool(_current_spell_context.get("is_enemy_spell", false)):
		_clear_spell_resolution_context()
		return
	var character_target_ids = _current_spell_context.get("character_target_ids", [])
	if typeof(character_target_ids) != TYPE_ARRAY or character_target_ids.is_empty():
		_clear_spell_resolution_context()
		return
	_trigger_enemy_trait_event("enemy_spell_resolved_after", _current_spell_context.duplicate(true))
	_consume_face_up_equipment_lockout_status(true)
	_clear_spell_resolution_context()

func _finish_ally_spell_resolution() -> void:
	if _current_spell_context.is_empty():
		return
	if bool(_current_spell_context.get("is_enemy_spell", false)):
		_clear_spell_resolution_context()
		return
	var spell_context := _current_spell_context.duplicate(true)
	if TraitManager:
		var character_target_ids = spell_context.get("character_target_ids", [])
		if typeof(character_target_ids) == TYPE_ARRAY and not character_target_ids.is_empty():
			TraitManager.process_event("ally_spell_resolved_after", spell_context.duplicate(true))
	var current_equipment_id := get_face_up_equipment_owner_id(false)
	if current_equipment_id != "":
		trigger_equipment_trait_event(current_equipment_id, "ally_spell_resolved_after", spell_context)
	_consume_face_up_equipment_lockout_status(false)
	_clear_spell_resolution_context()

func _get_character_ids_with_status(status_id: String = "", status_name: String = "") -> Array:
	var character_ids: Array = []
	for character_id in player_data.player_characters.keys():
		var resolved_id = str(character_id)
		if has_character_status(resolved_id, status_id, status_name):
			character_ids.append(resolved_id)
	for enemy_id in enemy_data.enemy_fiends.keys():
		var resolved_enemy_id = str(enemy_id)
		if has_character_status(resolved_enemy_id, status_id, status_name):
			character_ids.append(resolved_enemy_id)
	return character_ids

func _try_trigger_resonance_before_damage(character_id: String, amount: int, damage_context: Dictionary) -> void:
	if amount >= 0:
		return
	if not bool(damage_context.get("is_direct_spell_damage", false)):
		return
	if bool(damage_context.get("is_resonance_damage", false)):
		return
	if not has_character_status(character_id, "st011", "resonance"):
		return
	var resonant_ids = _get_character_ids_with_status("st011", "resonance")
	if resonant_ids.is_empty():
		return
	for resonant_id in resonant_ids:
		remove_character_status(str(resonant_id), "resonance", "st011")
	var original_spell_damage = int(damage_context.get("original_spell_damage", abs(amount)))
	var resonance_damage = max(int(floor(float(original_spell_damage) / 2.0)), 0)
	if resonance_damage <= 0:
		return
	var resonance_context = damage_context.duplicate(true)
	resonance_context["damage_kind"] = "resonance"
	resonance_context["is_direct_spell_damage"] = false
	resonance_context["is_resonance_damage"] = true
	for resonant_id in resonant_ids:
		var other_id = str(resonant_id)
		if other_id == character_id:
			continue
		update_character_health(other_id, -resonance_damage, resonance_context)

func remove_character_status(target_id: String, status_name: String = "", status_id: String = "") -> bool:
	if target_id == "":
		return false
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return false
	var status_map = char_state.get("status_effects", {})
	if typeof(status_map) != TYPE_DICTIONARY:
		return false
	var removed = false
	if status_name != "" and status_map.has(status_name):
		status_map.erase(status_name)
		removed = true
	elif status_id != "":
		for existing_status_name in status_map.keys():
			var existing_status = status_map[existing_status_name]
			if str(existing_status.get("id", "")) != status_id:
				continue
			status_map.erase(existing_status_name)
			removed = true
			break
	if removed:
		emit_signal("character_status_changed", target_id, status_map)
	return removed

func has_character_status(target_id: String, status_id: String = "", status_name: String = "") -> bool:
	if target_id == "":
		return false
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return false
	var status_map = char_state.get("status_effects", {})
	if typeof(status_map) != TYPE_DICTIONARY:
		return false
	if status_name != "" and status_map.has(status_name):
		return true
	if status_id != "":
		for existing_status_name in status_map.keys():
			var existing_status = status_map[existing_status_name]
			if str(existing_status.get("id", "")) == status_id:
				return true
	return false

func remove_status_from_target(target, status_name: String = "", status_id: String = "") -> bool:
	if typeof(target) == TYPE_DICTIONARY:
		var dice_type = str(target.get("dice_type", ""))
		if dice_type == "":
			return false
		if target.has("face_index"):
			return _remove_status_from_face_target(target, status_name, status_id)
		if not dice_statuses.has(dice_type):
			return false
		var dice_map = dice_statuses[dice_type]
		var removed_dice = _remove_status_from_map(dice_map, status_name, status_id)
		if removed_dice:
			if dice_map.is_empty():
				dice_statuses.erase(dice_type)
			emit_signal("dice_status_changed", dice_type, dice_map)
		return removed_dice
	return remove_character_status(str(target), status_name, status_id)

func has_status_on_target(target, status_id: String = "", status_name: String = "") -> bool:
	if typeof(target) == TYPE_DICTIONARY:
		var dice_type = str(target.get("dice_type", ""))
		if dice_type == "":
			var target_id = _resolve_runtime_entity_id(target)
			if target_id == "":
				return false
			return has_character_status(target_id, status_id, status_name)
		if target.has("face_index"):
			var face_index = int(target.get("face_index", -1))
			if face_index < 0 or not face_statuses.has(dice_type) or not face_statuses[dice_type].has(face_index):
				return false
			return _status_map_has_status(face_statuses[dice_type][face_index], status_id, status_name)
		if not dice_statuses.has(dice_type):
			return false
		return _status_map_has_status(dice_statuses[dice_type], status_id, status_name)
	return has_character_status(str(target), status_id, status_name)

func _status_map_has_status(status_map: Dictionary, status_id: String = "", status_name: String = "") -> bool:
	if typeof(status_map) != TYPE_DICTIONARY:
		return false
	if status_name != "" and status_map.has(status_name) and _is_status_effectively_active(status_map[status_name]):
		return true
	if status_id != "":
		for existing_status_name in status_map.keys():
			var existing_status = status_map[existing_status_name]
			if str(existing_status.get("id", "")) == status_id and _is_status_effectively_active(existing_status):
				return true
	return false

func extend_status_on_target(target, status_id: String, duration_delta: int) -> bool:
	if status_id == "" or duration_delta <= 0:
		return false
	var status_data = GameDataManager.get_status_data(status_id)
	if status_data.is_empty():
		return false
	var status_name = _get_status_runtime_key(status_data)
	if status_name == "":
		return false
	if typeof(target) == TYPE_DICTIONARY:
		var dice_type = str(target.get("dice_type", ""))
		if dice_type == "":
			var target_id = _resolve_runtime_entity_id(target)
			if target_id == "":
				return false
			var char_state_from_dict = _get_character_state(target_id)
			if char_state_from_dict == null:
				return false
			var char_status_map_from_dict = char_state_from_dict.get("status_effects", {})
			if typeof(char_status_map_from_dict) != TYPE_DICTIONARY:
				return false
			var changed_from_dict = _extend_status_in_map(char_status_map_from_dict, status_name, duration_delta)
			if changed_from_dict:
				emit_signal("character_status_changed", target_id, char_status_map_from_dict)
			return changed_from_dict
		if target.has("face_index"):
			var face_index = int(target.get("face_index", -1))
			if face_index < 0 or not face_statuses.has(dice_type) or not face_statuses[dice_type].has(face_index):
				return false
			var face_map = face_statuses[dice_type][face_index]
			var changed_face = _extend_status_in_map(face_map, status_name, duration_delta)
			if changed_face:
				emit_signal("face_status_changed", dice_type, face_index, face_map)
			return changed_face
		if not dice_statuses.has(dice_type):
			return false
		var dice_map = dice_statuses[dice_type]
		var changed_dice = _extend_status_in_map(dice_map, status_name, duration_delta)
		if changed_dice:
			emit_signal("dice_status_changed", dice_type, dice_map)
		return changed_dice
	var target_id = str(target)
	if target_id == "":
		return false
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return false
	var status_map = char_state.get("status_effects", {})
	if typeof(status_map) != TYPE_DICTIONARY:
		return false
	var changed = _extend_status_in_map(status_map, status_name, duration_delta)
	if changed:
		emit_signal("character_status_changed", target_id, status_map)
	return changed

func _remove_status_from_map(status_map: Dictionary, status_name: String = "", status_id: String = "") -> bool:
	if typeof(status_map) != TYPE_DICTIONARY:
		return false
	if status_name != "" and status_map.has(status_name):
		status_map.erase(status_name)
		return true
	if status_id != "":
		for existing_status_name in status_map.keys():
			var existing_status = status_map[existing_status_name]
			if str(existing_status.get("id", "")) != status_id:
				continue
			status_map.erase(existing_status_name)
			return true
	return false

func _remove_status_from_face_target(target: Dictionary, status_name: String = "", status_id: String = "") -> bool:
	var dice_type := str(target.get("dice_type", ""))
	var face_index := int(target.get("face_index", -1))
	if dice_type == "" or face_index < 0:
		return false
	var target_face_indices: Array = [face_index]
	var resolved_status_id := status_id
	if resolved_status_id == "" and status_name != "":
		var status_data_by_name := GameDataManager.get_status_data_by_name(status_name)
		if not status_data_by_name.is_empty():
			resolved_status_id = str(status_data_by_name.get("id", ""))
	if resolved_status_id != "" and _status_should_expand_to_replica_group(resolved_status_id, dice_type):
		var content_id := _get_face_content_id(dice_type, face_index)
		if content_id != "":
			target_face_indices = _get_matching_face_indices_by_content_id(dice_type, content_id)
	var removed_any := false
	for raw_face_index in target_face_indices:
		var current_face_index := int(raw_face_index)
		if not face_statuses.has(dice_type) or not face_statuses[dice_type].has(current_face_index):
			continue
		var face_map = face_statuses[dice_type][current_face_index]
		var removed_face = _remove_status_from_map(face_map, status_name, status_id)
		if not removed_face:
			continue
		removed_any = true
		if face_map.is_empty():
			face_statuses[dice_type].erase(current_face_index)
			if face_statuses[dice_type].is_empty():
				face_statuses.erase(dice_type)
		emit_signal("face_status_changed", dice_type, current_face_index, face_map)
	return removed_any

func get_character_trait_state(character_id: String, trait_id: String, defaults: Dictionary = {}) -> Dictionary:
	if character_id == "" or trait_id == "":
		return defaults.duplicate(true)
	var char_state = _get_character_state(character_id)
	if char_state == null:
		return defaults.duplicate(true)
	if not char_state.has("trait_runtime") or typeof(char_state.get("trait_runtime", {})) != TYPE_DICTIONARY:
		char_state["trait_runtime"] = {}
	if not char_state["trait_runtime"].has(trait_id):
		char_state["trait_runtime"][trait_id] = defaults.duplicate(true)
	return char_state["trait_runtime"][trait_id]

func set_character_trait_state(character_id: String, trait_id: String, state: Dictionary) -> void:
	if character_id == "" or trait_id == "":
		return
	var char_state = _get_character_state(character_id)
	if char_state == null:
		return
	if not char_state.has("trait_runtime") or typeof(char_state.get("trait_runtime", {})) != TYPE_DICTIONARY:
		char_state["trait_runtime"] = {}
	char_state["trait_runtime"][trait_id] = state

func _get_character_state(target_id: String):
	if player_data.player_characters.has(target_id):
		return player_data.player_characters[target_id]
	if enemy_data.enemy_fiends.has(target_id):
		return enemy_data.enemy_fiends[target_id]
	return null

func _resolve_runtime_entity_id(entity) -> String:
	if entity == null:
		return ""
	if typeof(entity) == TYPE_STRING:
		return str(entity)
	if typeof(entity) == TYPE_DICTIONARY:
		var dict_entity: Dictionary = entity
		return str(dict_entity.get("name", dict_entity.get("character_name", dict_entity.get("enemy_name", ""))))
	if typeof(entity) == TYPE_OBJECT:
		if "name" in entity:
			return str(entity.name)
		if "character_name" in entity:
			return str(entity.character_name)
		if "unique_id" in entity and str(entity.unique_id) != "":
			return str(entity.unique_id)
		if "enemy_name" in entity:
			return str(entity.enemy_name)
	return ""

func _get_timed_escape_trait_config_from_traits(trait_ids) -> Dictionary:
	var resolved_trait_ids = trait_ids
	if typeof(resolved_trait_ids) == TYPE_STRING:
		resolved_trait_ids = [resolved_trait_ids]
	if typeof(resolved_trait_ids) != TYPE_ARRAY:
		return {}
	for raw_trait_id in resolved_trait_ids:
		var trait_id = str(raw_trait_id)
		if trait_id == "":
			continue
		var trait_def = GameDataManager.get_trait_data(trait_id)
		if trait_def.is_empty():
			continue
		var timed_escape = trait_def.get("timed_escape", {})
		if typeof(timed_escape) == TYPE_DICTIONARY and not timed_escape.is_empty():
			return timed_escape.duplicate(true)
	return {}

func _build_initial_timed_escape_state(enemy_obj: EnemyData) -> Dictionary:
	if enemy_obj == null:
		return {}
	var config = _get_timed_escape_trait_config_from_traits(enemy_obj.traits)
	if config.is_empty():
		return {}
	var max_escape_count = int(config.get("max_escape_count", 1))
	return {
		"countdown_mode": str(config.get("countdown_mode", TIMED_ESCAPE_MODE_TICK)),
		"remaining_ticks": int(config.get("escape_after_ticks", 5)),
		"remaining_escapes": max(max_escape_count, 0),
		"escapes_done": 0,
		"max_health_bonus_accumulated": 0,
		"max_health_bonus_per_escape": int(config.get("max_health_bonus_per_escape", 0)),
		"allow_multiple_escapes": bool(config.get("allow_multiple_escapes", false)),
		"max_escape_count": max(max_escape_count, 0),
		"marker_id": str(config.get("marker_id", TIMED_ESCAPE_MARKER_DEFAULT)),
		"escape_status_id": str(config.get("escape_status_id", "")),
		"escape_status_duration": int(config.get("escape_status_duration", 0)),
		"upgraded_hexes_after_escape": config.get("upgraded_hexes_after_escape", []).duplicate(true) if typeof(config.get("upgraded_hexes_after_escape", [])) == TYPE_ARRAY else [],
		"transit": false
	}

func _ensure_enemy_runtime_state(enemy_id: String) -> void:
	if enemy_id == "" or not enemy_data.enemy_fiends.has(enemy_id):
		return
	var enemy_state = enemy_data.enemy_fiends[enemy_id]
	if not enemy_state.has("enemy_template_id"):
		enemy_state["enemy_template_id"] = str(enemy_state.get("enemy_name", ""))
	if not enemy_state.has("equipment") or typeof(enemy_state.get("equipment", [])) != TYPE_ARRAY:
		var fallback_data = GameDataManager.get_enemy_data(str(enemy_state.get("enemy_template_id", "")))
		enemy_state["equipment"] = fallback_data.get("equipment", []).duplicate() if not fallback_data.is_empty() else []
	if not enemy_state.has("hexes") or typeof(enemy_state.get("hexes", [])) != TYPE_ARRAY:
		var fallback_hex_data = GameDataManager.get_enemy_data(str(enemy_state.get("enemy_template_id", "")))
		enemy_state["hexes"] = fallback_hex_data.get("hexes", []).duplicate() if not fallback_hex_data.is_empty() else []
	var timed_escape_state = enemy_state.get("timed_escape_state", {})
	if typeof(timed_escape_state) != TYPE_DICTIONARY:
		timed_escape_state = {}
	if timed_escape_state.is_empty():
		var enemy_template_data = GameDataManager.get_enemy_data(str(enemy_state.get("enemy_template_id", "")))
		if enemy_template_data.is_empty():
			enemy_template_data = {
				"traits": enemy_state.get("traits", [])
			}
		var config = _get_timed_escape_trait_config_from_traits(enemy_template_data.get("traits", enemy_state.get("traits", [])))
		if not config.is_empty():
			timed_escape_state = {
				"countdown_mode": str(config.get("countdown_mode", TIMED_ESCAPE_MODE_TICK)),
				"remaining_ticks": int(config.get("escape_after_ticks", 5)),
				"remaining_escapes": max(int(config.get("max_escape_count", 1)), 0),
				"escapes_done": 0,
				"max_health_bonus_accumulated": max(int(enemy_state.get("max_health", 0)) - int(enemy_template_data.get("base_health", enemy_state.get("max_health", 0))), 0),
				"max_health_bonus_per_escape": int(config.get("max_health_bonus_per_escape", 0)),
				"allow_multiple_escapes": bool(config.get("allow_multiple_escapes", false)),
				"max_escape_count": max(int(config.get("max_escape_count", 1)), 0),
				"marker_id": str(config.get("marker_id", TIMED_ESCAPE_MARKER_DEFAULT)),
				"escape_status_id": str(config.get("escape_status_id", "")),
				"escape_status_duration": int(config.get("escape_status_duration", 0)),
				"upgraded_hexes_after_escape": config.get("upgraded_hexes_after_escape", []).duplicate(true) if typeof(config.get("upgraded_hexes_after_escape", [])) == TYPE_ARRAY else [],
				"transit": false
			}
	if not timed_escape_state.is_empty():
		if not timed_escape_state.has("countdown_mode"):
			timed_escape_state["countdown_mode"] = TIMED_ESCAPE_MODE_TICK
		if not timed_escape_state.has("marker_id"):
			timed_escape_state["marker_id"] = TIMED_ESCAPE_MARKER_DEFAULT
		if not timed_escape_state.has("escape_status_id"):
			timed_escape_state["escape_status_id"] = ""
		if not timed_escape_state.has("escape_status_duration"):
			timed_escape_state["escape_status_duration"] = 0
		if not timed_escape_state.has("upgraded_hexes_after_escape") or typeof(timed_escape_state.get("upgraded_hexes_after_escape", [])) != TYPE_ARRAY:
			timed_escape_state["upgraded_hexes_after_escape"] = []
		if not timed_escape_state.has("transit"):
			timed_escape_state["transit"] = false
		enemy_state["timed_escape_state"] = timed_escape_state

func _generate_enemy_instance_id(base_name: String) -> String:
	var normalized_base_name = base_name if base_name != "" else "enemy"
	var next_index := 0
	var candidate = normalized_base_name + "_" + str(next_index)
	while enemy_data.enemy_fiends.has(candidate):
		next_index += 1
		candidate = normalized_base_name + "_" + str(next_index)
	return candidate

func add_incoming_enemy_to_current_team(enemy_payload: Dictionary) -> String:
	if typeof(enemy_payload) != TYPE_DICTIONARY or enemy_payload.is_empty():
		return ""
	var template_id = str(enemy_payload.get("enemy_template_id", enemy_payload.get("enemy_id", "")))
	if template_id == "":
		return ""
	var base_data = GameDataManager.get_enemy_data(template_id)
	if base_data.is_empty():
		return ""
	var enemy_obj = EnemyData.new().init(base_data)
	enemy_obj.unique_id = _generate_enemy_instance_id(enemy_obj.enemy_name)
	if enemy_payload.has("new_max_health"):
		enemy_obj.health = int(enemy_payload.get("new_max_health", enemy_obj.health))
	if enemy_payload.has("hexes") and typeof(enemy_payload.get("hexes", [])) == TYPE_ARRAY:
		enemy_obj.hexes = enemy_payload.get("hexes", []).duplicate()
	enemy_data.init_enemies(enemy_obj)
	var enemy_id = enemy_obj.unique_id
	if enemy_id == "" or not enemy_data.enemy_fiends.has(enemy_id):
		return ""
	var enemy_state = enemy_data.enemy_fiends[enemy_id]
	enemy_state["current_health"] = int(enemy_payload.get("current_health", enemy_obj.health))
	enemy_state["max_health"] = int(enemy_payload.get("new_max_health", enemy_obj.health))
	if enemy_payload.has("hexes") and typeof(enemy_payload.get("hexes", [])) == TYPE_ARRAY:
		enemy_state["hexes"] = enemy_payload.get("hexes", []).duplicate()
	var timed_escape_state = enemy_payload.get("timed_escape_state", {})
	if typeof(timed_escape_state) == TYPE_DICTIONARY:
		var normalized_timed_escape = timed_escape_state.duplicate(true)
		normalized_timed_escape["remaining_ticks"] = int(normalized_timed_escape.get("remaining_ticks", 5))
		normalized_timed_escape["transit"] = false
		enemy_state["timed_escape_state"] = normalized_timed_escape
	_ensure_enemy_runtime_state(enemy_id)
	_apply_battle_start_enemy_escape_statuses()
	_append_team_display_order("enemy", enemy_id)
	return enemy_id

func refresh_enemy_support_dice() -> void:
	var enemy_equipment_list: Array = []
	var enemy_hex_list: Array = []
	for enemy_state in enemy_data.enemy_fiends.values():
		var equipment = enemy_state.get("equipment", [])
		if typeof(equipment) == TYPE_ARRAY:
			enemy_equipment_list.append_array(equipment)
		var hexes = enemy_state.get("hexes", [])
		if typeof(hexes) == TYPE_ARRAY:
			enemy_hex_list.append_array(hexes)
	DiceManager.auto_fill_dice_faces("enemy_equipment", enemy_equipment_list)
	DiceManager.auto_fill_dice_faces("enemy_hex2", enemy_hex_list)

func _get_hex_target_blocks(hex_data: HexData) -> Array:
	if hex_data == null:
		return []
	return hex_data.target_data if typeof(hex_data.target_data) == TYPE_ARRAY else []

func _get_hex_effect_blocks(hex_data: HexData) -> Array:
	if hex_data == null:
		return []
	return hex_data.effect_data if typeof(hex_data.effect_data) == TYPE_ARRAY else []

func get_equipment_trait_state(equipment_id: String, trait_id: String, defaults: Dictionary = {}) -> Dictionary:
	if equipment_id == "" or trait_id == "":
		return defaults.duplicate(true)
	if not equipment_trait_states.has(equipment_id):
		equipment_trait_states[equipment_id] = {}
	if not equipment_trait_states[equipment_id].has(trait_id):
		equipment_trait_states[equipment_id][trait_id] = defaults.duplicate(true)
	return equipment_trait_states[equipment_id][trait_id]

func set_equipment_trait_state(equipment_id: String, trait_id: String, state: Dictionary) -> void:
	if equipment_id == "" or trait_id == "":
		return
	if not equipment_trait_states.has(equipment_id):
		equipment_trait_states[equipment_id] = {}
	equipment_trait_states[equipment_id][trait_id] = state

func get_face_up_character_owner_id() -> String:
	return _get_face_up_player_id()

func get_front_character_owner_id() -> String:
	return _get_front_player_id()

func get_back_character_owner_id() -> String:
	return _get_back_player_id()

func get_face_up_enemy_id() -> String:
	var face_index = get_certain_dice_result("enemy_frien")
	if face_index < 0:
		var dice_node = _get_dice_node_by_type("enemy_frien")
		if dice_node:
			face_index = int(dice_node.current_face_index)
	return _resolve_face_up_character_id("enemy_frien", face_index)

func get_front_enemy_id() -> String:
	return _get_front_enemy_id()

func get_back_enemy_id() -> String:
	return _get_back_enemy_id()

func _empty_string_array() -> Array[String]:
	var empty: Array[String] = []
	return empty

func get_character_target_ids_by_selector(selector: String, caster_is_enemy: bool, status_id: String = "") -> Array[String]:
	match selector:
		"front_ally":
			return _resolve_rank_target_ids(caster_is_enemy, true)
		"front_enemy":
			return _resolve_rank_target_ids(not caster_is_enemy, true)
		"back_ally":
			return _resolve_rank_target_ids(caster_is_enemy, false)
		"back_enemy":
			return _resolve_rank_target_ids(not caster_is_enemy, false)
		"lowest_health_ally":
			return _resolve_health_extreme_target_ids(caster_is_enemy, false)
		"lowest_health_enemy":
			return _resolve_health_extreme_target_ids(not caster_is_enemy, false)
		"highest_health_ally":
			return _resolve_health_extreme_target_ids(caster_is_enemy, true)
		"highest_health_enemy":
			return _resolve_health_extreme_target_ids(not caster_is_enemy, true)
		"status_ally":
			return _resolve_status_target_ids(caster_is_enemy, status_id)
		"status_enemy":
			return _resolve_status_target_ids(not caster_is_enemy, status_id)
	return _empty_string_array()

func supports_character_target_selector(selector: String) -> bool:
	match selector:
		"front_ally", "front_enemy", "back_ally", "back_enemy", "lowest_health_ally", "lowest_health_enemy", "highest_health_ally", "highest_health_enemy", "status_ally", "status_enemy":
			return true
	return false

func get_face_up_equipment_owner_id(is_enemy: bool = false) -> String:
	var equip_info = _get_equipment_face_up(is_enemy)
	return str(equip_info.get("equipment_id", ""))

func get_face_up_dice_face_target(dice_type: String) -> Dictionary:
	var face_index = get_certain_dice_result(dice_type)
	if face_index < 0:
		var dice_node = _get_dice_node_by_type(dice_type)
		if dice_node:
			face_index = int(dice_node.current_face_index)
	if face_index < 0:
		return {}
	return {
		"dice_type": dice_type,
		"face_index": face_index
	}

func get_face_status_map(dice_type: String, face_index: int) -> Dictionary:
	if not face_statuses.has(dice_type) or not face_statuses[dice_type].has(face_index):
		return {}
	return face_statuses[dice_type][face_index].duplicate(true)

func trigger_equipment_trait_event(equipment_id: String, event_name: String, context: Dictionary = {}) -> void:
	var is_enemy_equipment := bool(context.get("equipment_is_enemy", false))
	if equipment_id != "":
		if _is_equipment_trait_event_blocked(equipment_id, event_name, is_enemy_equipment):
			return
		if TraitManager:
			TraitManager.trigger_equipment_traits(equipment_id, event_name, context)
		return
	for owned_equipment_id in get_all_owned_equipment_ids():
		if TraitManager:
			TraitManager.trigger_equipment_traits(str(owned_equipment_id), event_name, context)

func get_all_owned_equipment_ids() -> Array:
	var ids: Array = []
	for face in EmbeddedDiceFaces.equipment_dice_faces.values():
		var equipment_id = str(face.id)
		if equipment_id != "" and not ids.has(equipment_id):
			ids.append(equipment_id)
	return ids

func _is_equipment_trait_event_blocked(equipment_id: String, event_name: String, is_enemy_equipment: bool = false) -> bool:
	if equipment_id == "":
		return false
	match event_name:
		"equipment_face_up", "equipment_countdown_tick", "ally_action_before", "ally_action_after", "ally_spell_resolved_after", "enemy_action_damage_before", "enemy_action_before", "enemy_action_after", "enemy_spell_resolved_after":
			pass
		_:
			return false
	var equip_info := _get_equipment_face_up(is_enemy_equipment)
	if str(equip_info.get("equipment_id", "")) != equipment_id:
		return false
	var face_index := int(equip_info.get("face_index", -1))
	if face_index < 0:
		return false
	return has_status_on_target({
		"dice_type": str(equip_info.get("dice_type", "")),
		"face_index": face_index
	}, "st019", "")

func _consume_face_up_equipment_lockout_status(is_enemy: bool) -> void:
	var equip_info := _get_equipment_face_up(is_enemy)
	var face_index := int(equip_info.get("face_index", -1))
	if face_index < 0:
		return
	var dice_type := str(equip_info.get("dice_type", ""))
	if dice_type == "":
		return
	remove_status_from_target({
		"dice_type": dice_type,
		"face_index": face_index
	}, "", "st019")

func apply_equipment_trait_damage(equipment_id: String, target_id: String, amount: int) -> void:
	if equipment_id == "" or target_id == "" or amount <= 0:
		return
	var runtime_face_data = _get_equipment_runtime_face_data(equipment_id)
	var equip_data: Dictionary = {}
	if runtime_face_data != null:
		if typeof(runtime_face_data) == TYPE_DICTIONARY:
			equip_data = runtime_face_data
		else:
			equip_data = runtime_face_data.to_dict()
	else:
		equip_data = GameDataManager.get_equipment_data(equipment_id)
	var previous_forced_context = _forced_equipment_context.duplicate(true)
	var previous_caster = current_caster
	_forced_equipment_context = {
		"dice_type": "equipment",
		"face_index": get_certain_dice_result("equipment"),
		"face_data": runtime_face_data,
		"stats": {
			"attack_bonus": int(equip_data.get("attack_bonus", 0)),
			"defense_bonus": int(equip_data.get("defense_bonus", 0))
		}
	}
	var source_id = _resolve_current_source_id()
	current_caster = {"character_name": source_id, "name": source_id}
	update_character_health(target_id, -amount)
	current_caster = previous_caster
	_forced_equipment_context = previous_forced_context

func get_equipment_forged_bonus_damage(equipment_id: String, bonus_kind: String) -> int:
	if equipment_id == "" or bonus_kind == "":
		return 0
	var face_data = _get_equipment_runtime_face_data(equipment_id)
	var forged_variant_id = _get_forged_variant_id_from_face_data(face_data)
	match bonus_kind:
		"ammo":
			return 2 if forged_variant_id == "critical" else 0
	return 0

func apply_separate_damage(target_id: String, amount: int, damage_context: Dictionary = {}) -> void:
	if target_id == "" or amount <= 0:
		return
	var previous_forced_context = _forced_equipment_context.duplicate(true)
	_forced_equipment_context = {}
	update_character_health(target_id, -amount, damage_context)
	_forced_equipment_context = previous_forced_context

func negate_pending_enemy_action_damage() -> void:
	_pending_enemy_action_damage_negated = true

func get_runtime_sequence_id() -> int:
	return _runtime_sequence_id

func _get_roll_exclusion_status_id_for_dice_type(dice_type: String) -> String:
	match dice_type:
		"frien", "enemy_frien":
			return "st007"
		"equipment", "enemy_equipment":
			return "st014"
		"hex2", "enemy_hex2":
			return "st015"
	return ""

func _get_roll_forced_status_id_for_dice_type(dice_type: String) -> String:
	match dice_type:
		"frien", "enemy_frien":
			return "st017"
	return ""

func _get_roll_candidate_faces(dice_type: String) -> Dictionary:
	match dice_type:
		"frien":
			return EmbeddedDiceFaces.frien_dice_faces
		"enemy_frien":
			return EmbeddedDiceFaces.enemy_frien_dice_faces
		"equipment":
			return EmbeddedDiceFaces.equipment_dice_faces
		"enemy_equipment":
			return EmbeddedDiceFaces.enemy_equipment_dice_faces
		"hex2":
			return EmbeddedDiceFaces.hex_dice_faces
		"enemy_hex2":
			return EmbeddedDiceFaces.enemy_hex_dice_faces
	return {}

func _get_face_content_id(dice_type: String, face_index: int) -> String:
	var face_data = EmbeddedDiceFaces.get_dice_face(dice_type, face_index)
	if face_data == null or EmbeddedDiceFaces.is_default_face(face_data):
		return ""
	if typeof(face_data) == TYPE_DICTIONARY:
		var direct_id := str(face_data.get("id", ""))
		if direct_id != "":
			return direct_id
		match dice_type:
			"equipment", "enemy_equipment":
				return GameDataManager.get_equipment_id_by_name(str(face_data.get("equipment_name", "")))
			"hex2", "enemy_hex2":
				return GameDataManager.get_hex_id_by_name(str(face_data.get("hex_name", "")))
		return ""
	if "id" in face_data and str(face_data.id) != "":
		return str(face_data.id)
	match dice_type:
		"equipment", "enemy_equipment":
			return GameDataManager.get_equipment_id_by_name(str(face_data.equipment_name))
		"hex2", "enemy_hex2":
			return GameDataManager.get_hex_id_by_name(str(face_data.hex_name))
	return ""

func _get_matching_face_indices_by_content_id(dice_type: String, content_id: String) -> Array:
	var matches: Array = []
	if content_id == "":
		return matches
	var faces := _get_roll_candidate_faces(dice_type)
	for face_index in range(6):
		if not faces.has(face_index):
			continue
		if _get_face_content_id(dice_type, face_index) != content_id:
			continue
		matches.append(face_index)
	return matches

func _get_roll_exclusion_target_for_face(dice_type: String, face_index: int):
	match dice_type:
		"frien", "enemy_frien":
			var faces = _get_roll_candidate_faces(dice_type)
			if not faces.has(face_index):
				return ""
			return _get_party_face_character_id(faces[face_index], dice_type == "enemy_frien")
		"equipment", "enemy_equipment", "hex2", "enemy_hex2":
			return {
				"dice_type": dice_type,
				"face_index": face_index
			}
	return null

func _target_has_roll_exclusion_status(target, dice_type: String) -> bool:
	var status_id = _get_roll_exclusion_status_id_for_dice_type(dice_type)
	if status_id == "" or not has_status_on_target(target, status_id, ""):
		return false
	var status_map: Dictionary = {}
	if typeof(target) == TYPE_DICTIONARY:
		var target_dice_type = str(target.get("dice_type", ""))
		if target.has("face_index"):
			var face_index = int(target.get("face_index", -1))
			if face_index >= 0 and face_statuses.has(target_dice_type) and face_statuses[target_dice_type].has(face_index):
				status_map = face_statuses[target_dice_type][face_index]
		elif dice_statuses.has(target_dice_type):
			status_map = dice_statuses[target_dice_type]
	else:
		var char_state = _get_character_state(str(target))
		if char_state != null:
			status_map = char_state.get("status_effects", {})
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if str(status.get("id", "")) != status_id:
			continue
		return bool(status.get("effects", {}).get("exclude_from_next_friend_roll", false))
	return false

func _get_target_status_map(target, dice_type: String = "") -> Dictionary:
	if typeof(target) == TYPE_DICTIONARY:
		var target_dice_type = str(target.get("dice_type", dice_type))
		if target.has("face_index"):
			var face_index = int(target.get("face_index", -1))
			if face_index >= 0 and face_statuses.has(target_dice_type) and face_statuses[target_dice_type].has(face_index):
				return face_statuses[target_dice_type][face_index]
		elif dice_statuses.has(target_dice_type):
			return dice_statuses[target_dice_type]
		return {}
	var char_state = _get_character_state(str(target))
	if char_state == null:
		return {}
	return char_state.get("status_effects", {})

func _get_roll_forced_status_instance(target, dice_type: String) -> Dictionary:
	var status_id = _get_roll_forced_status_id_for_dice_type(dice_type)
	if status_id == "":
		return {}
	var status_map = _get_target_status_map(target, dice_type)
	if typeof(status_map) != TYPE_DICTIONARY:
		return {}
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if str(status.get("id", "")) != status_id:
			continue
		if not bool(status.get("effects", {}).get("force_next_friend_roll", false)):
			continue
		if not _is_status_effectively_active(status):
			continue
		return status
	return {}

func _get_forced_roll_candidates(dice_type: String) -> Array:
	var status_id = _get_roll_forced_status_id_for_dice_type(dice_type)
	if status_id == "":
		return []
	var faces = _get_roll_candidate_faces(dice_type)
	if faces.is_empty():
		return []
	var forced_candidates: Array = []
	var latest_applied_order := -1
	for face_index in range(6):
		if not faces.has(face_index):
			continue
		var target = _get_roll_exclusion_target_for_face(dice_type, face_index)
		if typeof(target) != TYPE_STRING or str(target) == "":
			continue
		var status = _get_roll_forced_status_instance(target, dice_type)
		if status.is_empty():
			continue
		var applied_order = int(status.get("applied_order", -1))
		if applied_order > latest_applied_order:
			latest_applied_order = applied_order
			forced_candidates = [face_index]
		elif applied_order == latest_applied_order:
			forced_candidates.append(face_index)
	return forced_candidates

func get_filtered_roll_candidates(dice_type: String) -> Array:
	var candidates: Array = [0, 1, 2, 3, 4, 5]
	var forced_candidates := _get_forced_roll_candidates(dice_type)
	if not forced_candidates.is_empty():
		return forced_candidates
	var status_id = _get_roll_exclusion_status_id_for_dice_type(dice_type)
	if status_id == "":
		return candidates
	var faces = _get_roll_candidate_faces(dice_type)
	if faces.is_empty():
		return candidates
	var filtered: Array = []
	for face_index in candidates:
		if not faces.has(face_index):
			continue
		var target = _get_roll_exclusion_target_for_face(dice_type, face_index)
		if target == null:
			filtered.append(face_index)
			continue
		if _target_has_roll_exclusion_status(target, dice_type):
			continue
		filtered.append(face_index)
	if filtered.is_empty():
		return candidates
	return filtered

func get_biased_roll_face(dice_type: String, candidates: Array) -> int:
	if candidates.is_empty():
		return 0
	var category_counts := _build_roll_category_counts(dice_type, candidates)
	if category_counts.is_empty():
		return int(candidates[randi() % candidates.size()])

	var deficit_map := _get_roll_bias_deficit_map(dice_type)
	var total_candidates := float(candidates.size())
	var face_weights: Array = []
	var total_weight := 0.0

	for face_index in candidates:
		var category_key := _get_roll_face_category_key(dice_type, int(face_index))
		var category_count := int(category_counts.get(category_key, 1))
		var expected_probability := float(category_count) / total_candidates
		var deficit := float(deficit_map.get(category_key, 0.0))
		var multiplier: float = maxf(ROLL_BIAS_MIN_MULTIPLIER, 1.0 + deficit * ROLL_BIAS_STRENGTH)
		var face_weight: float = multiplier
		face_weights.append({
			"face_index": int(face_index),
			"category_key": category_key,
			"expected_probability": expected_probability,
			"weight": face_weight
		})
		total_weight += face_weight

	if total_weight <= 0.0:
		return int(candidates[randi() % candidates.size()])

	var roll := randf() * total_weight
	var cumulative := 0.0
	var selected_face_index := int(candidates[0])
	var selected_category_key := _get_roll_face_category_key(dice_type, selected_face_index)

	for entry in face_weights:
		cumulative += float(entry.weight)
		if roll <= cumulative:
			selected_face_index = int(entry.face_index)
			selected_category_key = str(entry.category_key)
			break

	var next_deficit_map: Dictionary = {}
	for category_key in category_counts.keys():
		var category_count := int(category_counts[category_key])
		var expected_probability := float(category_count) / total_candidates
		var previous_deficit := float(deficit_map.get(category_key, 0.0))
		var next_deficit := previous_deficit * ROLL_BIAS_MEMORY_DECAY + expected_probability
		if str(category_key) == selected_category_key:
			next_deficit -= 1.0
		if absf(next_deficit) > 0.0001:
			next_deficit_map[str(category_key)] = next_deficit

	_roll_bias_state[dice_type] = next_deficit_map
	return selected_face_index

func _build_roll_category_counts(dice_type: String, candidates: Array) -> Dictionary:
	var category_counts: Dictionary = {}
	for face_index in candidates:
		var category_key := _get_roll_face_category_key(dice_type, int(face_index))
		category_counts[category_key] = int(category_counts.get(category_key, 0)) + 1
	return category_counts

func _get_roll_bias_deficit_map(dice_type: String) -> Dictionary:
	var deficit_map = _roll_bias_state.get(dice_type, {})
	if typeof(deficit_map) != TYPE_DICTIONARY:
		deficit_map = {}
	_roll_bias_state[dice_type] = deficit_map
	return deficit_map

func _get_roll_face_category_key(dice_type: String, face_index: int) -> String:
	var face_data = EmbeddedDiceFaces.get_dice_face(dice_type, face_index)
	if face_data == null or EmbeddedDiceFaces.is_default_face(face_data):
		return "blank"
	if typeof(face_data) == TYPE_DICTIONARY:
		var face_id := str(face_data.get("id", ""))
		if face_id != "":
			return face_id
		match dice_type:
			"frien":
				return "character:%s" % str(face_data.get("character_name", ""))
			"enemy_frien":
				var unique_id := str(face_data.get("unique_id", ""))
				if unique_id != "":
					return "enemy:%s" % unique_id
				return "enemy:%s" % str(face_data.get("enemy_name", ""))
			"equipment", "enemy_equipment":
				return "equipment:%s" % str(face_data.get("equipment_name", ""))
			"hex2", "enemy_hex2":
				return "hex:%s" % str(face_data.get("hex_name", ""))
		return "filled:%s:%d" % [dice_type, face_index]
	if "id" in face_data and str(face_data.id) != "":
		return str(face_data.id)
	match dice_type:
		"frien":
			return "character:%s" % str(face_data.character_name)
		"enemy_frien":
			if "unique_id" in face_data and str(face_data.unique_id) != "":
				return "enemy:%s" % str(face_data.unique_id)
			return "enemy:%s" % str(face_data.enemy_name)
		"equipment", "enemy_equipment":
			return "equipment:%s" % str(face_data.equipment_name)
		"hex2", "enemy_hex2":
			return "hex:%s" % str(face_data.hex_name)
	return "filled:%s:%d" % [dice_type, face_index]

func _consume_roll_exclusion_stealth(dice_type: String) -> void:
	var status_id = _get_roll_exclusion_status_id_for_dice_type(dice_type)
	if status_id == "":
		return
	var faces = _get_roll_candidate_faces(dice_type)
	if faces.is_empty():
		return

	var has_alternative_face := false
	var excluded_targets: Array = []
	for face_index in range(6):
		if not faces.has(face_index):
			continue
		var target = _get_roll_exclusion_target_for_face(dice_type, face_index)
		if target == null or (typeof(target) == TYPE_STRING and target == ""):
			has_alternative_face = true
			break
		if not _target_has_roll_exclusion_status(target, dice_type):
			has_alternative_face = true
			break
		if not excluded_targets.has(target):
			excluded_targets.append(target)

	if not has_alternative_face:
		return

	for target in excluded_targets:
		remove_status_from_target(target, "", status_id)

func _consume_forced_roll_expose(dice_type: String, face_up_value: int) -> void:
	var status_id = _get_roll_forced_status_id_for_dice_type(dice_type)
	if status_id == "":
		return
	var target = _get_roll_exclusion_target_for_face(dice_type, face_up_value)
	if typeof(target) != TYPE_STRING or str(target) == "":
		return
	var status = _get_roll_forced_status_instance(target, dice_type)
	if status.is_empty():
		return
	remove_status_from_target(target, "", status_id)


class DiceResult:
	var dice_type: String
	var face_up_value: int
	var face_down_value: int

var dice_result = DiceResult.new()
var dice_results: Array = []

@onready var character_scene = preload("res://Scenes/player_character.tscn")
@onready var enemy_scene = preload("res://Scenes/enemy_character.tscn")


signal battle_ended(victory: bool)

func _ready():
	pass

func _process(_delta):
	
	pass

func _build_default_battle_stats() -> Dictionary:
	return {
		"battle_index": -1,
		"seed": 0,
		"encounter_id": "",
		"enemy_config_label": "",
		"enemy_entries": [],
		"result": "",
		"total_ticks": 0,
		"player_total_casts": 0,
		"player_damage_dealt_by_unit": {},
		"player_damage_taken_by_unit": {},
		"player_healing_received_by_unit": {},
		"player_shield_received_by_unit": {},
		"enemy_healing_received_total": 0,
		"enemy_shield_received_total": 0
	}

func _initialize_battle_stats(config: Dictionary) -> void:
	current_battle_stats = _build_default_battle_stats()
	if typeof(config) != TYPE_DICTIONARY:
		return
	var context = config.get("simulation_context", {})
	if typeof(context) != TYPE_DICTIONARY:
		context = {}
	current_battle_stats["battle_index"] = int(context.get("battle_index", config.get("battle_index", -1)))
	current_battle_stats["seed"] = int(context.get("seed", config.get("seed", 0)))
	current_battle_stats["encounter_id"] = str(context.get("encounter_id", config.get("encounter_id", "")))
	current_battle_stats["enemy_config_label"] = str(context.get("enemy_config_label", config.get("enemy_config_label", "")))
	var enemy_entries = context.get("enemy_entries", config.get("enemies", []))
	current_battle_stats["enemy_entries"] = enemy_entries.duplicate(true) if typeof(enemy_entries) == TYPE_ARRAY else []

func _record_stat_map_value(field_name: String, unit_id: String, amount: int) -> void:
	if unit_id == "" or amount <= 0:
		return
	var stat_map = current_battle_stats.get(field_name, {})
	if typeof(stat_map) != TYPE_DICTIONARY:
		stat_map = {}
	stat_map[unit_id] = int(stat_map.get(unit_id, 0)) + amount
	current_battle_stats[field_name] = stat_map

func _build_battle_summary() -> Dictionary:
	var summary = current_battle_stats.duplicate(true)
	if summary.is_empty():
		summary = _build_default_battle_stats()
	summary["result"] = battle_result
	return summary

func get_last_battle_summary() -> Dictionary:
	return last_battle_summary.duplicate(true)

func _get_battle_layout_duration(base_duration: float) -> float:
	return 0.0 if simulation_fast_mode else base_duration

func _get_battle_layout_gap(base_gap: float) -> float:
	return 0.0 if simulation_fast_mode else base_gap

func _get_health_queue_interval() -> float:
	return 0.0 if simulation_fast_mode else HEALTH_QUEUE_INTERVAL

func queue_battle_layout_refresh() -> void:
	if _battle_layout_refresh_queued:
		return
	_battle_layout_refresh_queued = true
	call_deferred("_flush_battle_layout_refresh")

func refresh_battle_layout_if_needed() -> void:
	queue_battle_layout_refresh()

func _flush_battle_layout_refresh() -> void:
	_battle_layout_refresh_queued = false
	apply_battle_layout()

func compute_battle_layout() -> Dictionary:
	_sync_team_display_order("frien")
	_sync_team_display_order("enemy")
	var layout: Dictionary = {}
	var ally_nodes := _get_battle_team_nodes("frien")
	var enemy_nodes := _get_battle_team_nodes("enemy")
	layout.merge(_compute_team_layout(ally_nodes, BATTLE_LAYOUT_ALLY_REGION), true)
	layout.merge(_compute_team_layout(enemy_nodes, BATTLE_LAYOUT_ENEMY_REGION), true)
	return layout

func apply_battle_layout(layout: Dictionary = {}) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	if layout.is_empty():
		layout = compute_battle_layout()
	for team_nodes in [_get_battle_team_nodes("frien"), _get_battle_team_nodes("enemy")]:
		for node in team_nodes:
			var unit_id := str(node.name)
			if not layout.has(unit_id):
				continue
			if node.has_method("apply_layout"):
				var layout_data = layout[unit_id]
				if _battle_layout_position_lock and typeof(layout_data) == TYPE_DICTIONARY:
					layout_data = layout_data.duplicate(true)
					layout_data["position"] = node.position
				node.apply_layout(layout_data)
	emit_signal("battle_layout_changed")

func _get_battle_team_nodes(group_name: String) -> Array:
	var nodes: Array = []
	if get_tree() == null or get_tree().current_scene == null:
		return nodes
	for child in get_tree().current_scene.get_children():
		if child != null and child.is_in_group(group_name):
			nodes.append(child)
	var order_map := _build_team_display_order_index(group_name)
	nodes.sort_custom(func(a, b):
		return int(order_map.get(str(a.name), 2147483647)) < int(order_map.get(str(b.name), 2147483647))
	)
	return nodes

func _build_team_display_order_index(group_name: String) -> Dictionary:
	var order_map: Dictionary = {}
	var order := _get_team_display_order(group_name)
	for i in range(order.size()):
		order_map[str(order[i])] = i
	return order_map

func _get_team_display_order(group_name: String) -> Array[String]:
	return _enemy_display_order if group_name == "enemy" else _ally_display_order

func _append_team_display_order(group_name: String, unit_id: String) -> void:
	if unit_id == "":
		return
	var order := _get_team_display_order(group_name)
	if order.has(unit_id):
		return
	order.append(unit_id)

func _remove_team_display_order(group_name: String, unit_id: String) -> void:
	if unit_id == "":
		return
	var order := _get_team_display_order(group_name)
	order.erase(unit_id)

func _get_team_state_map(group_name: String) -> Dictionary:
	return enemy_data.enemy_fiends if group_name == "enemy" else player_data.player_characters

func _is_unit_alive_in_group(group_name: String, unit_id: String) -> bool:
	if unit_id == "":
		return false
	var state_map := _get_team_state_map(group_name)
	if not state_map.has(unit_id):
		return false
	return int(state_map[unit_id].get("current_health", 0)) > 0

func _move_unit_to_order_index(group_name: String, unit_id: String, target_index: int) -> bool:
	if unit_id == "":
		return false
	_sync_team_display_order(group_name)
	var order := _get_team_display_order(group_name)
	if not order.has(unit_id):
		return false
	var current_index := order.find(unit_id)
	var clamped_target := clampi(target_index, 0, order.size() - 1)
	if current_index == -1 or current_index == clamped_target:
		return false
	order.remove_at(current_index)
	order.insert(clamped_target, unit_id)
	return true

func _resolve_unit_group_name(unit_id: String) -> String:
	if unit_id == "":
		return ""
	if player_data.player_characters.has(unit_id):
		return "frien"
	if enemy_data.enemy_fiends.has(unit_id):
		return "enemy"
	return ""

func _resolve_team_shift_target_index(group_name: String, current_index: int, order_size: int, steps: int, toward_front: bool) -> int:
	if current_index < 0 or order_size <= 0 or steps <= 0:
		return current_index
	if toward_front:
		return min(current_index + steps, order_size - 1) if group_name == "frien" else max(current_index - steps, 0)
	return max(current_index - steps, 0) if group_name == "frien" else min(current_index + steps, order_size - 1)

func _shift_unit_in_team_order(unit_id: String, steps: int, toward_front: bool) -> Dictionary:
	if unit_id == "" or steps <= 0:
		return {}
	var group_name := _resolve_unit_group_name(unit_id)
	if group_name == "":
		return {}
	if not _is_unit_alive_in_group(group_name, unit_id):
		return {}
	_sync_team_display_order(group_name)
	var order := _get_team_display_order(group_name)
	var current_index := order.find(unit_id)
	if current_index == -1:
		return {}
	var target_index := _resolve_team_shift_target_index(group_name, current_index, order.size(), steps, toward_front)
	if target_index == current_index:
		return {}
	if not _move_unit_to_order_index(group_name, unit_id, target_index):
		return {}
	return {
		"group_name": group_name,
		"layout": compute_battle_layout()
	}

func _sync_team_display_order(group_name: String) -> void:
	var order := _get_team_display_order(group_name)
	var existing_ids: Array[String] = []
	var valid_runtime_ids: Array[String] = []
	if group_name == "enemy":
		for unit_id in enemy_data.enemy_fiends.keys():
			valid_runtime_ids.append(str(unit_id))
	else:
		for unit_id in player_data.player_characters.keys():
			valid_runtime_ids.append(str(unit_id))
	if get_tree() != null and get_tree().current_scene != null:
		for child in get_tree().current_scene.get_children():
			if child != null and child.is_in_group(group_name) and valid_runtime_ids.has(str(child.name)):
				existing_ids.append(str(child.name))
	if existing_ids.is_empty():
		existing_ids = valid_runtime_ids.duplicate()
	var next_order: Array[String] = []
	for unit_id in order:
		if existing_ids.has(unit_id):
			next_order.append(unit_id)
	for unit_id in existing_ids:
		if not next_order.has(unit_id):
			next_order.append(unit_id)
	if group_name == "enemy":
		_enemy_display_order = next_order
	else:
		_ally_display_order = next_order

func promote_front_unit(dice_type: String, face_up_value: int) -> Dictionary:
	var group_name := ""
	var front_unit_id := ""
	match dice_type:
		"frien":
			group_name = "frien"
			front_unit_id = _resolve_face_up_character_id("frien", face_up_value)
		"enemy_frien":
			group_name = "enemy"
			front_unit_id = _resolve_face_up_character_id("enemy_frien", face_up_value)
		_:
			return {}
	if front_unit_id == "":
		return {}
	_sync_team_display_order(group_name)
	var order := _get_team_display_order(group_name)
	if not order.has(front_unit_id):
		return {}
	var target_index := order.size() - 1 if group_name == "frien" else 0
	var already_front = order.back() == front_unit_id if group_name == "frien" else order.front() == front_unit_id
	if already_front:
		return {}
	if not _move_unit_to_order_index(group_name, front_unit_id, target_index):
		return {}
	return compute_battle_layout()

func _start_battle_layout_transition(layout: Dictionary, duration: float = FRONT_UNIT_MOVE_DURATION) -> bool:
	if layout.is_empty():
		return false
	if get_tree() == null or get_tree().current_scene == null:
		return false
	if is_instance_valid(_battle_layout_transition_tween):
		_battle_layout_transition_tween.kill()
		_battle_layout_transition_tween = null
	var tween := get_tree().current_scene.create_tween()
	tween.set_parallel(true)
	var animated := false
	for team_nodes in [_get_battle_team_nodes("frien"), _get_battle_team_nodes("enemy")]:
		for node in team_nodes:
			var unit_id := str(node.name)
			if not layout.has(unit_id):
				continue
			var target_position: Vector2 = layout[unit_id].get("position", node.position)
			if is_equal_approx(float(node.position.x), float(target_position.x)):
				continue
			animated = true
			tween.tween_property(node, "position:x", target_position.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not animated:
		tween.kill()
		_battle_layout_position_lock = false
		apply_battle_layout(layout)
		return false
	_battle_layout_position_lock = true
	_battle_layout_transition_tween = tween
	tween.finished.connect(_on_battle_layout_transition_finished.bind(layout, tween), CONNECT_ONE_SHOT)
	return true

func _on_battle_layout_transition_finished(layout: Dictionary, tween: Tween) -> void:
	if _battle_layout_transition_tween == tween:
		_battle_layout_transition_tween = null
	_battle_layout_position_lock = false
	apply_battle_layout(layout)

func retreat_unit(unit_id: String, steps: int, animate: bool = true) -> bool:
	var shift_result := _shift_unit_in_team_order(unit_id, steps, false)
	if shift_result.is_empty():
		return false
	var layout: Dictionary = shift_result.get("layout", {})
	if animate:
		_start_battle_layout_transition(layout, FRONT_UNIT_MOVE_DURATION)
	else:
		apply_battle_layout(layout)
	return true

func retreat_unit_with_tween(unit_id: String, steps: int, duration: float = FRONT_UNIT_MOVE_DURATION) -> bool:
	var shift_result := _shift_unit_in_team_order(unit_id, steps, false)
	if shift_result.is_empty():
		return false
	var layout: Dictionary = shift_result.get("layout", {})
	await animate_battle_layout_transition(layout, duration, BATTLE_LAYOUT_TRANSITION_GAP)
	return true

func advance_unit(unit_id: String, steps: int, animate: bool = true) -> bool:
	var shift_result := _shift_unit_in_team_order(unit_id, steps, true)
	if shift_result.is_empty():
		return false
	var layout: Dictionary = shift_result.get("layout", {})
	if animate:
		_start_battle_layout_transition(layout, FRONT_UNIT_MOVE_DURATION)
	else:
		apply_battle_layout(layout)
	return true

func advance_unit_with_tween(unit_id: String, steps: int, duration: float = FRONT_UNIT_MOVE_DURATION) -> bool:
	var shift_result := _shift_unit_in_team_order(unit_id, steps, true)
	if shift_result.is_empty():
		return false
	var layout: Dictionary = shift_result.get("layout", {})
	await animate_battle_layout_transition(layout, duration, BATTLE_LAYOUT_TRANSITION_GAP)
	return true

func animate_battle_layout_transition(layout: Dictionary, duration: float = FRONT_UNIT_MOVE_DURATION, gap_after: float = 0.0) -> void:
	if layout.is_empty():
		return
	if get_tree() == null or get_tree().current_scene == null:
		return
	duration = _get_battle_layout_duration(duration)
	gap_after = _get_battle_layout_gap(gap_after)
	var tween := get_tree().current_scene.create_tween()
	tween.set_parallel(true)
	var animated := false
	for team_nodes in [_get_battle_team_nodes("frien"), _get_battle_team_nodes("enemy")]:
		for node in team_nodes:
			var unit_id := str(node.name)
			if not layout.has(unit_id):
				continue
			var target_position: Vector2 = layout[unit_id].get("position", node.position)
			if is_equal_approx(float(node.position.x), float(target_position.x)):
				continue
			animated = true
			tween.tween_property(node, "position:x", target_position.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not animated:
		_battle_layout_position_lock = false
		apply_battle_layout(layout)
		return
	_battle_layout_position_lock = true
	await tween.finished
	_battle_layout_position_lock = false
	apply_battle_layout(layout)
	if gap_after > 0.0 and get_tree() != null:
		await get_tree().create_timer(gap_after).timeout

func _compute_team_layout(nodes: Array, region: Rect2) -> Dictionary:
	var layout: Dictionary = {}
	var unit_count: int = nodes.size()
	if unit_count == 0:
		return layout

	var status_max_width: float = clampf(region.size.x / float(unit_count) - 20.0, BATTLE_LAYOUT_MIN_STATUS_WIDTH, BATTLE_LAYOUT_MAX_STATUS_WIDTH)
	var default_gap: float = BATTLE_LAYOUT_DEFAULT_GAP if unit_count > 1 else 0.0
	var metrics_list: Array = _build_layout_metrics_for_nodes(nodes, 1.0, status_max_width)
	var gap: float = _resolve_layout_gap(metrics_list, region.size.x, default_gap)
	var required_width: float = _compute_required_layout_width(metrics_list, gap)

	if required_width > region.size.x:
		var scale_factor: float = _resolve_layout_scale_factor(metrics_list, region.size.x, unit_count)
		metrics_list = _build_layout_metrics_for_nodes(nodes, scale_factor, status_max_width)
		gap = _resolve_layout_gap(metrics_list, region.size.x, default_gap)
		required_width = _compute_required_layout_width(metrics_list, gap)
		if required_width > region.size.x and unit_count > 1:
			gap = BATTLE_LAYOUT_MIN_GAP
			required_width = _compute_required_layout_width(metrics_list, gap)

	var start_x: float = region.position.x + maxf((region.size.x - required_width) * 0.5, 0.0)
	var cursor_x: float = start_x
	for metrics in metrics_list:
		var node = metrics.get("node")
		var local_bounds: Rect2 = metrics.get("local_bounds", Rect2())
		var node_x: float = cursor_x - local_bounds.position.x
		var min_y: float = BATTLE_LAYOUT_TOP_MARGIN - local_bounds.position.y
		var max_y: float = BATTLE_LAYOUT_VIEWPORT_SIZE.y - BATTLE_LAYOUT_BOTTOM_MARGIN - local_bounds.end.y
		var node_y: float = clampf(BATTLE_LAYOUT_BASELINE_Y, min_y, max_y)
		var position: Vector2 = Vector2(node_x, node_y)
		layout[str(node.name)] = {
			"unit_id": str(node.name),
			"position": position,
			"portrait_scale": metrics.get("portrait_scale", 1.0),
			"status_max_width": metrics.get("status_max_width", status_max_width),
			"health_bar_width_scale": BATTLE_LAYOUT_HEALTH_BAR_WIDTH_SCALE,
			"bounds": Rect2(position + local_bounds.position, local_bounds.size)
		}
		cursor_x += local_bounds.size.x + gap
	return layout

func _build_layout_metrics_for_nodes(nodes: Array, scale_factor: float, status_max_width: float) -> Array:
	var metrics_list: Array = []
	for node in nodes:
		var default_scale: float = 1.0
		if node.has_method("get_default_portrait_scale"):
			default_scale = float(node.get_default_portrait_scale())
		var portrait_scale: float = default_scale * scale_factor
		var metrics: Dictionary = {}
		if node.has_method("get_layout_metrics"):
			metrics = node.get_layout_metrics(portrait_scale, status_max_width, BATTLE_LAYOUT_HEALTH_BAR_WIDTH_SCALE)
		else:
			metrics = {"local_bounds": Rect2(-64.0, -64.0, 128.0, 128.0)}
		metrics["node"] = node
		metrics["portrait_scale"] = portrait_scale
		metrics["status_max_width"] = status_max_width
		metrics["health_bar_width_scale"] = BATTLE_LAYOUT_HEALTH_BAR_WIDTH_SCALE
		metrics_list.append(metrics)
	return metrics_list

func _compute_required_layout_width(metrics_list: Array, gap: float) -> float:
	var width: float = 0.0
	for metrics in metrics_list:
		var local_bounds: Rect2 = metrics.get("local_bounds", Rect2())
		width += local_bounds.size.x
	if metrics_list.size() > 1:
		width += gap * float(metrics_list.size() - 1)
	return width

func _resolve_layout_gap(metrics_list: Array, available_width: float, default_gap: float) -> float:
	if metrics_list.size() <= 1:
		return 0.0
	var total_width: float = 0.0
	for metrics in metrics_list:
		var local_bounds: Rect2 = metrics.get("local_bounds", Rect2())
		total_width += local_bounds.size.x
	var computed_gap: float = (available_width - total_width) / float(metrics_list.size() - 1)
	return clampf(computed_gap, BATTLE_LAYOUT_MIN_GAP, default_gap)

func _resolve_layout_scale_factor(metrics_list: Array, available_width: float, unit_count: int) -> float:
	var total_width: float = 0.0
	for metrics in metrics_list:
		var local_bounds: Rect2 = metrics.get("local_bounds", Rect2())
		total_width += local_bounds.size.x
	if total_width <= 0.0:
		return 1.0
	var target_gap: float = BATTLE_LAYOUT_MIN_GAP * float(max(unit_count - 1, 0))
	return clampf((available_width - target_gap) / total_width, BATTLE_LAYOUT_MIN_SCALE_FACTOR, 1.0)

func spawn_portraits(enemy_ids: Array = []):
	if not is_test_mode and not GameManager.current_run:
		print("[BattleManager] No current run or not testing, skipping portrait spawn")
		return

	rebuild_player_team_from_current_faces()
	spawn_player_visuals_from_current_faces()
	
	var enemy_offset = Vector2(-200, 0)
	var enemy_base_position = Vector2(1800, 600)
	
	var enemy_array = []
	if enemy_ids.is_empty():
		pass
	else:
		for raw_entry in enemy_ids:
			var data: Dictionary = {}
			var runtime_payload: Dictionary = {}
			if typeof(raw_entry) == TYPE_STRING:
				var enemy_id = str(raw_entry)
				data = GameDataManager.get_enemy_data(enemy_id)
				if data.is_empty():
					data = GameDataManager.get_boss_data(enemy_id)
			elif typeof(raw_entry) == TYPE_DICTIONARY:
				runtime_payload = raw_entry.duplicate(true)
				var template_id = str(runtime_payload.get("enemy_template_id", runtime_payload.get("enemy_id", "")))
				if template_id != "":
					data = GameDataManager.get_enemy_data(template_id)
					if data.is_empty():
						data = GameDataManager.get_boss_data(template_id)
			if data.is_empty():
				continue
			var enemy = EnemyData.new().init(data)
			if runtime_payload.has("new_max_health"):
				enemy.health = int(runtime_payload.get("new_max_health", enemy.health))
			if runtime_payload.has("unique_id"):
				enemy.unique_id = str(runtime_payload.get("unique_id", ""))
			if runtime_payload.has("hexes") and typeof(runtime_payload.get("hexes", [])) == TYPE_ARRAY:
				enemy.hexes = runtime_payload.get("hexes", []).duplicate()
			enemy_array.append({
				"enemy": enemy,
				"runtime_payload": runtime_payload
			})
	
	# If still empty (and no IDs passed), maybe fallback to old behavior for safety?
	if enemy_array.is_empty() and enemy_ids.is_empty():
		for enemy in GameDataManager.get_all_enemies():
			enemy_array.append({
				"enemy": enemy,
				"runtime_payload": {}
			})

	var name_counts = {}
	for enemy_entry in enemy_array:
		var enemy: EnemyData = enemy_entry.get("enemy")
		var runtime_payload: Dictionary = enemy_entry.get("runtime_payload", {})
		# Handle duplicate names by assigning unique_id to ALL enemies
		var base_name = enemy.enemy_name
		if enemy.unique_id == "":
			if not name_counts.has(base_name):
				name_counts[base_name] = 0
			enemy.unique_id = base_name + "_" + str(name_counts[base_name])
			name_counts[base_name] += 1
		
		print("[BattleManager] Assigned unique_id: ", enemy.unique_id, " to enemy: ", base_name)
		enemy_data.init_enemies(enemy)
		var enemy_state = enemy_data.enemy_fiends.get(enemy.unique_id, {})
		if typeof(runtime_payload) == TYPE_DICTIONARY and not runtime_payload.is_empty():
			if runtime_payload.has("current_health"):
				enemy_state["current_health"] = int(runtime_payload.get("current_health", enemy_state.get("current_health", enemy.health)))
			if runtime_payload.has("new_max_health"):
				enemy_state["max_health"] = int(runtime_payload.get("new_max_health", enemy_state.get("max_health", enemy.health)))
			if runtime_payload.has("hexes") and typeof(runtime_payload.get("hexes", [])) == TYPE_ARRAY:
				enemy_state["hexes"] = runtime_payload.get("hexes", []).duplicate()
			var timed_escape_state = runtime_payload.get("timed_escape_state", {})
			if typeof(timed_escape_state) == TYPE_DICTIONARY and not timed_escape_state.is_empty():
				var next_timed_escape_state = timed_escape_state.duplicate(true)
				next_timed_escape_state["transit"] = false
				enemy_state["timed_escape_state"] = next_timed_escape_state
		_ensure_enemy_runtime_state(enemy.unique_id)

	_apply_battle_start_enemy_escape_statuses()
	
	for i in range(enemy_array.size()):
		var enemy: EnemyData = enemy_array[i].get("enemy")
		var spawn_position = enemy_base_position + (enemy_offset * i)
		var enemy_state = enemy_data.enemy_fiends.get(enemy.unique_id, {})
		spawn_enemy_at_position(enemy, spawn_position, int(enemy_state.get("current_health", enemy.health)))

	_sync_team_display_order("frien")
	_sync_team_display_order("enemy")
	apply_battle_layout()

func get_current_player_faces() -> Array:
	var character_array: Array = []
	var added_names: Array = []
	for i in range(6):
		if EmbeddedDiceFaces.frien_dice_faces.has(i):
			var face = EmbeddedDiceFaces.frien_dice_faces[i]
			if EmbeddedDiceFaces.is_default_face(face):
				continue
			if face.character_name in added_names:
				continue
			character_array.append(face)
			added_names.append(face.character_name)
	return character_array

func rebuild_player_team_from_current_faces() -> void:
	player_data = PlayerData.new()
	var run_data = GameManager.current_run
	for character in get_current_player_faces():
		var max_health = character.health
		var saved_health = max_health
		if not is_test_mode and not is_tutorial_battle and run_data and run_data.character_current_health.has(character.character_name):
			saved_health = clamp(run_data.character_current_health[character.character_name], 0, max_health)
		player_data.init_characters(character)
		player_data.player_characters[character.character_name]["current_health"] = saved_health
		player_data.player_characters[character.character_name]["max_health"] = max_health

func spawn_player_visuals_from_current_faces() -> void:
	var character_offset = Vector2(200, 0)
	var ally_base_position = Vector2(200, 600)
	var run_data = GameManager.current_run
	var character_array = get_current_player_faces()
	for i in range(character_array.size()):
		var character = character_array[i]
		var saved_health = character.health
		if not is_test_mode and not is_tutorial_battle and run_data and run_data.character_current_health.has(character.character_name):
			saved_health = run_data.character_current_health[character.character_name]
		var spawn_position = ally_base_position + (character_offset * i)
		spawn_character_at_position(character, spawn_position, saved_health)

	_sync_team_display_order("frien")
	apply_battle_layout()

func set_battle_type(type: BattleType) -> void:
	current_battle_type = type

func get_battle_type() -> BattleType:
	return current_battle_type

func start_new_battle(enemy_ids: Array = []) -> void:
	reset_battle_state()
	is_test_mode = false
	is_simulation_mode = false
	simulation_fast_mode = false
	is_tutorial_battle = false
	
	spawn_portraits(enemy_ids)
	for enemy_id in enemy_data.enemy_fiends.keys():
		_ensure_enemy_runtime_state(str(enemy_id))
	
	initialize_character_dice_faces("enemy_frien", enemy_data.enemy_fiends)
	_apply_enemy_health_per_occupied_face()

func start_test_battle(config: Dictionary) -> void:
	is_test_mode = true
	is_simulation_mode = bool(config.get("is_simulation_mode", false))
	simulation_fast_mode = bool(config.get("fast_mode", false))
	simulation_context = config.get("simulation_context", {}).duplicate(true) if typeof(config.get("simulation_context", {})) == TYPE_DICTIONARY else {}
	is_tutorial_battle = false
	battle_result = ""
	last_battle_summary = {}
	_initialize_battle_stats(config)
	_battle_end_scene_transition_requested = false
	reset_special_battle_state()
	player_data.player_characters.clear()
	enemy_data.enemy_fiends.clear()
	rolled_dice.clear()
	dice_results.clear()
	_roll_bias_state.clear()
	
	test_reroll_count = config.get("reroll_count", 0)
	player_data = PlayerData.new()
	enemy_data = EnemyTeam.new()
	
	var enemy_ids = config.get("enemies", [])
	spawn_portraits(enemy_ids)
	for enemy_id in enemy_data.enemy_fiends.keys():
		_ensure_enemy_runtime_state(str(enemy_id))
	
	initialize_character_dice_faces("enemy_frien", enemy_data.enemy_fiends)
	_apply_enemy_health_per_occupied_face()

func start_tutorial_battle(config: Dictionary) -> void:
	reset_battle_state()
	is_test_mode = false
	is_simulation_mode = false
	simulation_fast_mode = false
	is_tutorial_battle = true
	test_reroll_count = int(config.get("reroll_count", 0))
	var enemy_ids = config.get("enemies", [])
	spawn_portraits(enemy_ids)
	for enemy_id in enemy_data.enemy_fiends.keys():
		_ensure_enemy_runtime_state(str(enemy_id))
	initialize_character_dice_faces("enemy_frien", enemy_data.enemy_fiends)
	_apply_enemy_health_per_occupied_face()

func start_battle() -> void:
	spawn_portraits()

func resume_battle() -> void:
	spawn_visuals_from_current_data()

func spawn_visuals_from_current_data() -> void:
	# Spawn Players
	var character_offset = Vector2(200, 0)
	var ally_base_position = Vector2(200, 600)
	
	var player_keys = player_data.player_characters.keys()
	for i in range(player_keys.size()):
		var char_name = player_keys[i]
		var char_state = player_data.player_characters[char_name]
		
		var data_dict = {
			"character_name": char_state.name,
			"texture_path": char_state.texture_path,
			"health": char_state.max_health,
			"traits": char_state.traits,
			"countdown": char_state.get("countdown", 999)
		}
		var char_data = CharacterData.new().init(data_dict)
		
		var spawn_position = ally_base_position + (character_offset * i)
		spawn_character_at_position(char_data, spawn_position, char_state.current_health)
		
	# Spawn Enemies
	var enemy_offset = Vector2(-200, 0)
	var enemy_base_position = Vector2(1800, 600)
	
	var enemy_keys = enemy_data.enemy_fiends.keys()
	for i in range(enemy_keys.size()):
		var enemy_id = enemy_keys[i]
		var enemy_state = enemy_data.enemy_fiends[enemy_id]
		_ensure_enemy_runtime_state(str(enemy_id))
		
		var data_dict = {
			"id": str(enemy_state.get("enemy_template_id", "")),
			"enemy_name": enemy_state.enemy_name,
			"texture_path": enemy_state.texture_path,
			"health": enemy_state.max_health,
			"traits": enemy_state.traits,
			"unique_id": enemy_state.name,
			"countdown": enemy_state.get("countdown", 999),
			"health_per_occupied_face": enemy_state.get("health_per_occupied_face", 0),
			"equipment": enemy_state.get("equipment", []).duplicate(),
			"hexes": enemy_state.get("hexes", []).duplicate()
		}
		var enemy_obj = EnemyData.new().init(data_dict)
		
		var spawn_position = enemy_base_position + (enemy_offset * i)
		spawn_enemy_at_position(enemy_obj, spawn_position, enemy_state.current_health)

	_sync_team_display_order("frien")
	_sync_team_display_order("enemy")
	apply_battle_layout()

func _apply_enemy_health_per_occupied_face() -> void:
	for enemy_id in enemy_data.enemy_fiends.keys():
		var enemy_state = enemy_data.enemy_fiends[enemy_id]
		var health_per_occupied_face = int(enemy_state.get("health_per_occupied_face", 0))
		if health_per_occupied_face <= 0:
			continue
		var occupied_faces = _get_character_occupied_face_count(str(enemy_id))
		var resolved_health = health_per_occupied_face * occupied_faces
		enemy_state["max_health"] = resolved_health
		enemy_state["current_health"] = resolved_health
		var enemy_node = get_tree().current_scene.get_node_or_null(str(enemy_id))
		if enemy_node and enemy_node.has_method("update_health"):
			enemy_node.update_health(resolved_health, resolved_health)

func _tick_timed_escape_enemies() -> void:
	var pending_escape_enemy_ids: Array = []
	for raw_enemy_id in enemy_data.enemy_fiends.keys():
		var enemy_id = str(raw_enemy_id)
		_ensure_enemy_runtime_state(enemy_id)
		if not enemy_data.enemy_fiends.has(enemy_id):
			continue
		var enemy_state = enemy_data.enemy_fiends[enemy_id]
		var timed_escape_state = enemy_state.get("timed_escape_state", {})
		if typeof(timed_escape_state) != TYPE_DICTIONARY or timed_escape_state.is_empty():
			continue
		if str(timed_escape_state.get("countdown_mode", TIMED_ESCAPE_MODE_TICK)) != TIMED_ESCAPE_MODE_TICK:
			continue
		var remaining_escapes = int(timed_escape_state.get("remaining_escapes", 0))
		if remaining_escapes <= 0:
			continue
		var previous_ticks = int(timed_escape_state.get("remaining_ticks", 0))
		if previous_ticks <= 0:
			continue
		timed_escape_state["remaining_ticks"] = max(previous_ticks - 1, 0)
		if int(timed_escape_state.get("remaining_ticks", 0)) == 0:
			pending_escape_enemy_ids.append(enemy_id)
	for enemy_id in pending_escape_enemy_ids:
		_attempt_timed_escape(enemy_id)

func _attempt_timed_escape(enemy_id: String) -> bool:
	if enemy_id == "" or not enemy_data.enemy_fiends.has(enemy_id):
		return false
	var enemy_state = enemy_data.enemy_fiends[enemy_id]
	var timed_escape_state = enemy_state.get("timed_escape_state", {})
	if typeof(timed_escape_state) != TYPE_DICTIONARY or timed_escape_state.is_empty():
		return false
	var target_room = MapStateManager.find_nearest_uncleared_normal_battle_room(MapStateManager.get_current_room())
	var max_health_bonus_per_escape = int(timed_escape_state.get("max_health_bonus_per_escape", 0))
	var next_escapes_done = int(timed_escape_state.get("escapes_done", 0)) + 1
	var next_bonus = int(timed_escape_state.get("max_health_bonus_accumulated", 0)) + max_health_bonus_per_escape
	var template_id = str(enemy_state.get("enemy_template_id", ""))
	var template_data = GameDataManager.get_enemy_data(template_id)
	var base_health = int(template_data.get("base_health", enemy_state.get("max_health", 0)))
	var remaining_escapes = max(int(timed_escape_state.get("remaining_escapes", 0)) - 1, 0)
	var next_timed_escape_state = timed_escape_state.duplicate(true)
	next_timed_escape_state["remaining_escapes"] = remaining_escapes
	next_timed_escape_state["escapes_done"] = next_escapes_done
	next_timed_escape_state["max_health_bonus_accumulated"] = next_bonus
	next_timed_escape_state["remaining_ticks"] = int(_get_timed_escape_trait_config_from_traits(enemy_state.get("traits", [])).get("escape_after_ticks", 5))
	next_timed_escape_state["transit"] = true
	var incoming_payload = {
		"enemy_template_id": template_id,
		"current_health": base_health + next_bonus,
		"new_max_health": base_health + next_bonus,
		"timed_escape_state": next_timed_escape_state
	}
	var upgraded_hexes = next_timed_escape_state.get("upgraded_hexes_after_escape", [])
	if typeof(upgraded_hexes) == TYPE_ARRAY and not upgraded_hexes.is_empty():
		incoming_payload["hexes"] = upgraded_hexes.duplicate()
	if target_room != INVALID_ROOM_POS:
		MapStateManager.append_room_incoming_enemy(target_room, incoming_payload)
		MapStateManager.add_room_escape_marker(target_room, {
			"enemy_template_id": template_id,
			"marker_id": str(timed_escape_state.get("marker_id", TIMED_ESCAPE_MARKER_DEFAULT)),
			"source_room": {
				"x": MapStateManager.get_current_room().x,
				"y": MapStateManager.get_current_room().y
			}
		})
	_remove_enemy_by_escape(enemy_id)
	return true

func _remove_enemy_by_escape(enemy_id: String) -> void:
	if enemy_id == "" or not enemy_data.enemy_fiends.has(enemy_id):
		return
	var enemy_name = str(enemy_data.enemy_fiends[enemy_id].get("enemy_name", enemy_id))
	_remove_team_display_order("enemy", enemy_id)
	remove_certain_portrait(enemy_id)
	_clear_character_party_dice_faces(enemy_id, true, "enemy_escaped")
	enemy_data.enemy_fiends.erase(enemy_id)
	emit_signal("enemy_timed_escape", enemy_id, enemy_name)
	if not enemy_data.enemy_fiends.is_empty():
		refresh_enemy_support_dice()
	# Timed escape removes enemies outside the health queue, so battle-end
	# finalization must be triggered here when the last enemy leaves.
	_finalize_battle_end_if_needed()

func _tick_all_statuses(tick_context: Dictionary) -> void:
	_tick_control_flags.clear()

	for char_id in player_data.player_characters.keys():
		var status_map = player_data.player_characters[char_id].status_effects
		if _tick_statuses_for_target(StatusTarget.CHARACTER, char_id, status_map, tick_context):
			emit_signal("character_status_changed", char_id, status_map)

	for enemy_id in enemy_data.enemy_fiends.keys():
		var enemy_status_map = enemy_data.enemy_fiends[enemy_id].status_effects
		if _tick_statuses_for_target(StatusTarget.CHARACTER, enemy_id, enemy_status_map, tick_context):
			emit_signal("character_status_changed", enemy_id, enemy_status_map)

	for dice_type in dice_statuses.keys():
		var dice_map = dice_statuses[dice_type]
		var changed = _tick_statuses_for_target(StatusTarget.DICE, dice_type, dice_map, tick_context)
		if dice_map.is_empty():
			dice_statuses.erase(dice_type)
			changed = true
		if changed:
			emit_signal("dice_status_changed", dice_type, dice_map)

	for dice_type in face_statuses.keys():
		var face_map = face_statuses[dice_type]
		for face_index in face_map.keys():
			var status_map = face_map[face_index]
			var changed = _tick_statuses_for_target(StatusTarget.DICE_FACE, {"dice_type": dice_type, "face_index": face_index}, status_map, tick_context)
			if status_map.is_empty():
				face_map.erase(face_index)
				changed = true
			if changed:
				emit_signal("face_status_changed", dice_type, face_index, status_map)
		if face_map.is_empty():
			face_statuses.erase(dice_type)

func _tick_after_action_statuses_for_character(char_id: String, is_enemy: bool, after_action_snapshot: Dictionary = {}) -> void:
	if char_id == "":
		return
	var team_dict = enemy_data.enemy_fiends if is_enemy else player_data.player_characters
	if not team_dict.has(char_id):
		return
	var status_map = team_dict[char_id].get("status_effects", {})
	if typeof(status_map) != TYPE_DICTIONARY:
		return
	if _tick_statuses_for_target(StatusTarget.CHARACTER, char_id, status_map, {
		"phase": StatusTickPhase.AFTER_ACTION,
		"sequence_id": _runtime_sequence_id,
		"after_action_snapshot": after_action_snapshot
	}):
		emit_signal("character_status_changed", char_id, status_map)

func _apply_battle_start_enemy_escape_statuses() -> void:
	for raw_enemy_id in enemy_data.enemy_fiends.keys():
		var enemy_id := str(raw_enemy_id)
		_ensure_enemy_runtime_state(enemy_id)
		if not enemy_data.enemy_fiends.has(enemy_id):
			continue
		var enemy_state = enemy_data.enemy_fiends[enemy_id]
		var timed_escape_state = enemy_state.get("timed_escape_state", {})
		if typeof(timed_escape_state) != TYPE_DICTIONARY or timed_escape_state.is_empty():
			continue
		if str(timed_escape_state.get("countdown_mode", TIMED_ESCAPE_MODE_TICK)) != TIMED_ESCAPE_MODE_ACTION_STATUS:
			continue
		if int(timed_escape_state.get("remaining_escapes", 0)) <= 0:
			continue
		if int(timed_escape_state.get("escapes_done", 0)) > 0:
			continue
		var status_id := str(timed_escape_state.get("escape_status_id", ""))
		var status_duration := int(timed_escape_state.get("escape_status_duration", 0))
		if status_id == "" or status_duration <= 0:
			continue
		if has_character_status(enemy_id, status_id, ""):
			continue
		apply_status({
			"status_id": status_id,
			"stack_count": 1,
			"status_info": {
				"id": status_id,
				"duration": status_duration,
				"stack_count": 1
			}
		}, [enemy_id])

func _capture_after_action_status_snapshot(status_map: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	if typeof(status_map) != TYPE_DICTIONARY:
		return snapshot
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if typeof(status) != TYPE_DICTIONARY:
			continue
		var effects = status.get("effects", {})
		if typeof(effects) != TYPE_DICTIONARY:
			effects = {}
		var tick_phase = str(effects.get("tick_phase", "global_tick"))
		var decay_phase = str(effects.get("duration_tick_phase", "global_tick"))
		if tick_phase != "after_action" and decay_phase != "after_action":
			continue
		snapshot[status_name] = {
			"stacks": int(status.get("stacks", 1)),
			"duration": int(status.get("duration", 0))
		}
	return snapshot

func _tick_statuses_for_target(target_kind: int, target_id, status_map: Dictionary, tick_context: Dictionary) -> bool:
	if status_map.is_empty():
		return false
	var changed = false
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if _should_skip_status_tick_for_context(status, tick_context):
			continue
		if _apply_status_effect_by_category(target_kind, target_id, status_name, status, tick_context):
			changed = true
		if _decay_status_instance(status, tick_context):
			changed = true
	if _prune_expired_statuses(status_map):
		changed = true
	return changed

func _apply_status_effect_by_category(target_kind: int, target_id, _status_name: String, status: Dictionary, _tick_context: Dictionary) -> bool:
	var category = int(status.get("category", Category.DoT))
	var effects = status.get("effects", {})
	var stacks = int(status.get("stacks", 1))
	var changed = false
	match category:
		Category.DoT:
			if target_kind == StatusTarget.CHARACTER:
				var duration = int(status.get("duration", 0))
				if duration == 0:
					return false
				var tick_phase = str(effects.get("tick_phase", "global_tick"))
				var runtime_phase = int(_tick_context.get("phase", StatusTickPhase.GLOBAL_TICK))
				if tick_phase == "after_action":
					var after_action_snapshot = _tick_context.get("after_action_snapshot", {})
					if typeof(after_action_snapshot) != TYPE_DICTIONARY or not after_action_snapshot.has(_status_name):
						return false
					if runtime_phase != StatusTickPhase.AFTER_ACTION:
						return false
					var snapshot_entry = after_action_snapshot.get(_status_name, {})
					if typeof(snapshot_entry) == TYPE_DICTIONARY:
						stacks = min(stacks, max(int(snapshot_entry.get("stacks", stacks)), 0))
				elif runtime_phase != StatusTickPhase.GLOBAL_TICK:
					return false
				var tick_damage = int(effects.get("tick_damage", 0))
				tick_damage *= max(stacks, 0)
				if tick_damage > 0:
					_apply_status_tick_damage(str(target_id), tick_damage)
				if bool(effects.get("clear_stacks_after_trigger", false)):
					var remaining_stacks = max(int(status.get("stacks", 1)) - max(stacks, 0), 0)
					if remaining_stacks != int(status.get("stacks", 1)):
						status.stacks = remaining_stacks
						changed = true
		Category.CROWD_CONTROL:
			var key = _make_control_key(target_kind, target_id)
			var flags = _tick_control_flags.get(key, {})
			flags["skip_action"] = bool(flags.get("skip_action", false)) or bool(effects.get("skip_action", false))
			flags["disable_roll"] = bool(flags.get("disable_roll", false)) or bool(effects.get("disable_roll", false))
			flags["disable_flip"] = bool(flags.get("disable_flip", false)) or bool(effects.get("disable_flip", false))
			_tick_control_flags[key] = flags
		Category.DAMAGE_MOD:
			pass
		Category.AGGRO:
			pass
	return changed

func _decay_status_instance(status: Dictionary, tick_context: Dictionary) -> bool:
	var duration = int(status.get("duration", 0))
	if duration == -1:
		return false
	var effects = status.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		effects = {}
	var decay_phase = str(effects.get("duration_tick_phase", "global_tick"))
	var runtime_phase = int(tick_context.get("phase", StatusTickPhase.GLOBAL_TICK))
	if decay_phase == "after_action":
		var after_action_snapshot = tick_context.get("after_action_snapshot", {})
		var status_name = str(status.get("status_name", ""))
		if typeof(after_action_snapshot) != TYPE_DICTIONARY or status_name == "" or not after_action_snapshot.has(status_name):
			return false
		if runtime_phase != StatusTickPhase.AFTER_ACTION:
			return false
	else:
		if runtime_phase != StatusTickPhase.GLOBAL_TICK:
			return false
	if duration > 0:
		status.duration = duration - 1
		return true
	return false

func _prune_expired_statuses(status_map: Dictionary) -> bool:
	var expired: Array = []
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if _should_prune_status(status):
			expired.append(status_name)
	for status_name in expired:
		status_map.erase(status_name)
	return not expired.is_empty()

func _apply_status_tick_damage(target_id: String, damage: int) -> void:
	if target_id == "" or damage <= 0:
		return
	var previous_caster = current_caster
	var previous_forced_context: Dictionary = _forced_equipment_context.duplicate(true)
	current_caster = null
	_forced_equipment_context = {}
	update_character_health(target_id, -damage, {"damage_kind": "status_tick"})
	current_caster = previous_caster
	_forced_equipment_context = previous_forced_context

func _get_character_occupied_face_count(character_id: String) -> int:
	if character_id == "":
		return 0
	var is_enemy = enemy_data.enemy_fiends.has(character_id)
	var faces = EmbeddedDiceFaces.enemy_frien_dice_faces if is_enemy else EmbeddedDiceFaces.frien_dice_faces
	var count := 0
	for face in faces.values():
		if face == null or EmbeddedDiceFaces.is_default_face(face):
			continue
		if _get_party_face_character_id(face, is_enemy) == character_id:
			count += 1
	return count

func _get_party_face_character_id(face, is_enemy: bool) -> String:
	if typeof(face) == TYPE_OBJECT:
		if is_enemy:
			if "unique_id" in face and face.unique_id != "":
				return str(face.unique_id)
			if "enemy_name" in face:
				return str(face.enemy_name)
		elif "character_name" in face:
			return str(face.character_name)
	elif typeof(face) == TYPE_DICTIONARY:
		if is_enemy:
			if face.has("unique_id") and face.unique_id != "":
				return str(face.unique_id)
			if face.has("enemy_name"):
				return str(face.enemy_name)
		elif face.has("character_name"):
			return str(face.character_name)
	return ""

func _clear_character_party_dice_faces(character_id: String, is_enemy: bool, clear_reason: String = "character_removed") -> void:
	if character_id == "":
		return
	var dice_type = "enemy_frien" if is_enemy else "frien"
	var faces = EmbeddedDiceFaces.enemy_frien_dice_faces if is_enemy else EmbeddedDiceFaces.frien_dice_faces
	for face_index in range(6):
		if not faces.has(face_index):
			continue
		var face = faces[face_index]
		if EmbeddedDiceFaces.is_default_face(face):
			continue
		if _get_party_face_character_id(face, is_enemy) != character_id:
			continue
		DiceFaceChanger.update_dice_face(dice_type, face_index, "")
		EmbeddedDiceFaces.clear_dice_face(dice_type, face_index, {
			"change": clear_reason,
			"character_id": character_id,
			"is_enemy": is_enemy
		})
		if face_statuses.has(dice_type):
			face_statuses[dice_type].erase(face_index)
			emit_signal("face_status_changed", dice_type, face_index, {})

func _make_control_key(target_kind: int, target_id) -> String:
	match target_kind:
		StatusTarget.CHARACTER:
			return "character:%s" % str(target_id)
		StatusTarget.DICE:
			return "dice:%s" % str(target_id)
		StatusTarget.DICE_FACE:
			var info = target_id if typeof(target_id) == TYPE_DICTIONARY else {}
			return "dice_face:%s:%s" % [str(info.get("dice_type", "")), str(info.get("face_index", -1))]
	return ""

func _get_control_flags(target_kind: int, target_id) -> Dictionary:
	return _tick_control_flags.get(_make_control_key(target_kind, target_id), {})

func _has_crowd_control_flag(target_kind: int, target_id, flag_name: String) -> bool:
	var flags = _get_control_flags(target_kind, target_id)
	return bool(flags.get(flag_name, false))

func _status_map_has_crowd_control_flag(status_map: Dictionary, flag_name: String) -> bool:
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if int(status.get("category", Category.DoT)) != Category.CROWD_CONTROL:
			continue
		var effects = status.get("effects", {})
		if bool(effects.get(flag_name, false)):
			return true
	return false

func _get_damage_modifiers_from_status_map(status_map: Dictionary, direction: String) -> Dictionary:
	var add_key = "outgoing_damage_add"
	var mul_key = "outgoing_damage_mul"
	if direction == "incoming":
		add_key = "incoming_damage_add"
		mul_key = "incoming_damage_mul"
	var total_add = 0
	var total_mul = 1.0
	for status_name in status_map.keys():
		var status = status_map[status_name]
		if int(status.get("category", Category.DoT)) != Category.DAMAGE_MOD:
			continue
		var effects = status.get("effects", {})
		var stacks = int(status.get("stacks", 1))
		total_add += int(effects.get(add_key, 0)) * stacks
		var mul_value = float(effects.get(mul_key, 1.0))
		for _i in range(stacks):
			total_mul *= mul_value
	return {"add": total_add, "mul": total_mul}

func _merge_damage_modifiers(current: Dictionary, incoming: Dictionary) -> Dictionary:
	return {
		"add": int(current.get("add", 0)) + int(incoming.get("add", 0)),
		"mul": float(current.get("mul", 1.0)) * float(incoming.get("mul", 1.0))
	}

func clear_all_player_shield():
	for character in player_data.player_characters:
		player_data.player_characters[character]["shield"] = 0
		emit_signal("allied_shield_changed", player_data.player_characters[character],0)

func clear_all_enemy_shield():
	for enemy in enemy_data.enemy_fiends:
		enemy_data.enemy_fiends[enemy]["shield"] = 0
		emit_signal("enemy_shield_changed", enemy_data.enemy_fiends[enemy],0)	

func _resolve_scene_spawn_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	var root := tree.root
	if root == null:
		return null
	for child_index in range(root.get_child_count() - 1, -1, -1):
		var child := root.get_child(child_index)
		if child == self:
			continue
		if child is Window:
			continue
		if child is Node:
			return child
	return null

func spawn_character_at_position(character_data:CharacterData, pos: Vector2, current_health: int = -1):
	var character = character_scene.instantiate()
	var parent := _resolve_scene_spawn_parent()
	if parent == null:
		push_error("[BattleManager] Failed to spawn character portrait: no valid parent scene for %s" % character_data.character_name)
		return
	parent.add_child(character)
	character.name = character_data.character_name
	character.add_to_group("frien")
	_append_team_display_order("frien", character_data.character_name)
	character.setup_character(character_data)
	character.position = pos
	
	if current_health != -1:
		character.update_health(current_health, character_data.health)

func spawn_enemy_at_position(data:EnemyData, pos: Vector2, current_health: int = -1):
	var enemy = enemy_scene.instantiate()
	var parent := _resolve_scene_spawn_parent()
	if parent == null:
		push_error("[BattleManager] Failed to spawn enemy portrait: no valid parent scene for %s" % data.enemy_name)
		return
	parent.add_child(enemy)
	
	# Use unique_id for the Node name if available
	if data.unique_id != "":
		enemy.name = data.unique_id
	else:
		enemy.name = data.enemy_name
		
	enemy.add_to_group("enemy")
	_append_team_display_order("enemy", str(enemy.name))
	enemy.setup_enemy(data)
	enemy.position = pos
	
	if current_health != -1:
		enemy.update_health(current_health, data.health)

func update_character_health(character_id:String, amount:int, damage_context: Dictionary = {}):
	var queued_context: Dictionary = {}
	if typeof(damage_context) == TYPE_DICTIONARY:
		queued_context = damage_context.duplicate(true)
	var caster_snapshot = current_caster
	if typeof(current_caster) == TYPE_DICTIONARY:
		caster_snapshot = current_caster.duplicate(true)
	var forced_equipment_context_snapshot: Dictionary = _forced_equipment_context.duplicate(true)
	var delay_before := _consume_current_health_queue_delay()
	_health_change_queue.append({
		"character_id": character_id,
		"amount": amount,
		"damage_context": queued_context,
		"caster_snapshot": caster_snapshot,
		"forced_equipment_context_snapshot": forced_equipment_context_snapshot,
		"delay_before": delay_before
	})
	if not _health_queue_processing:
		_health_queue_processing = true
		_start_health_queue_processor.call_deferred()

func _start_health_queue_processor() -> void:
	await _process_health_queue()

func _process_health_queue() -> void:
	while not _health_change_queue.is_empty():
		var req = _health_change_queue.pop_front()
		var delay_before := float(req.get("delay_before", 0.0))
		if delay_before > 0.0:
			await get_tree().create_timer(delay_before).timeout
		var previous_caster = current_caster
		var previous_forced_context: Dictionary = _forced_equipment_context.duplicate(true)
		current_caster = req.get("caster_snapshot", null)
		var forced_context_raw = req.get("forced_equipment_context_snapshot", {})
		if typeof(forced_context_raw) == TYPE_DICTIONARY:
			_forced_equipment_context = forced_context_raw.duplicate(true)
		else:
			_forced_equipment_context = {}
		_apply_character_health_now(
			str(req.get("character_id", "")),
			int(req.get("amount", 0)),
			req.get("damage_context", {})
		)
		current_caster = previous_caster
		_forced_equipment_context = previous_forced_context
		var queue_interval := _get_health_queue_interval()
		if not _health_change_queue.is_empty() and queue_interval > 0.0:
			await get_tree().create_timer(queue_interval).timeout
	_health_queue_processing = false
	_finalize_battle_end_if_needed()
	emit_signal("health_queue_flushed")

func wait_health_queue_flushed() -> void:
	while _health_queue_processing or not _health_change_queue.is_empty():
		await health_queue_flushed

func _consume_current_health_queue_delay() -> float:
	if _current_spell_context.is_empty():
		return 0.0
	var delay_remaining := float(_current_spell_context.get("initial_health_queue_delay_remaining", 0.0))
	if delay_remaining <= 0.0:
		return 0.0
	_current_spell_context["initial_health_queue_delay_remaining"] = 0.0
	return delay_remaining

func _apply_character_health_now(character_id:String, amount:int, damage_context: Dictionary = {}):
	print("[BattleManager] update_character_health called for: ", character_id, " amount: ", amount)
	var source_id = _resolve_current_source_id()
	_try_trigger_resonance_before_damage(character_id, amount, damage_context)
	if player_data.player_characters.has(character_id):
		var char_state = player_data.player_characters[character_id]
		var old_health = int(char_state.current_health)
		print("[BattleManager] Current player health (before): ", old_health)
		
		if amount < 0 :
			var damage_kind = str(damage_context.get("damage_kind", "action"))
			if damage_kind == "action" and current_caster != null and _pending_enemy_action_damage_negated == false:
				var source_name_check = ""
				if typeof(current_caster) == TYPE_DICTIONARY:
					source_name_check = str(current_caster.get("name", current_caster.get("character_name", "")))
				elif "name" in current_caster:
					source_name_check = str(current_caster.name)
				if enemy_data.enemy_fiends.has(source_name_check):
					var current_equipment_id = get_face_up_equipment_owner_id(false)
					if current_equipment_id != "":
						trigger_equipment_trait_event(current_equipment_id, "enemy_action_damage_before", {
							"actor_id": source_name_check,
							"target_id": character_id
						})
			if _pending_enemy_action_damage_negated:
				_pending_enemy_action_damage_negated = false
				amount = 0
			var incoming_mod = _get_damage_modifiers_from_status_map(char_state.status_effects, "incoming")
			var modified_damage = int(round((abs(amount) + int(incoming_mod.add)) * float(incoming_mod.mul)))
			modified_damage = max(modified_damage, 0)
			amount = -modified_damage
			var shield_absorbed = min(abs(amount), char_state.shield)
			char_state.shield -= shield_absorbed
			var remaining_shield = char_state.shield
			amount += shield_absorbed
			print("[BattleManager] Shield absorbed: ", shield_absorbed, " remaining: ", remaining_shield)
			
			if shield_absorbed > 0:
				if remaining_shield > 0:
					print("shield remained")
					emit_signal("allied_shield_changed", player_data.player_characters[character_id], remaining_shield)
				else:
					print("shield broken")
					emit_signal("allied_shield_changed", player_data.player_characters[character_id], 0)
			if amount < 0:
				char_state.current_health = clamp(
		char_state.current_health + amount, 0, char_state.max_health
		)
				print("deal ", abs(amount)," damage to ally")
				emit_signal("allied_health_changed", amount)
		
		elif amount >= 0:
			char_state.current_health = clamp(
			char_state.current_health + amount, 0, char_state.max_health
		)
			emit_signal("allied_health_changed", amount)

		var health_delta = int(char_state.current_health) - old_health
		_sync_single_player_health_to_run(character_id, int(char_state.current_health))
		print("[BattleManager] Player health (after): ", int(char_state.current_health), " delta=", health_delta)
		if health_delta < 0:
			_record_stat_map_value("player_damage_taken_by_unit", character_id, abs(health_delta))
			var taken_ctx = {"actor_id": character_id, "target_id": character_id, "amount": abs(health_delta), "kind": "taken"}
			emit_signal("on_damage_taken", taken_ctx)
			_trigger_trait_event("endure", taken_ctx)
			var player_damage_ctx = {
				"actor_id": character_id,
				"target_id": character_id,
				"source_id": source_id,
				"amount": abs(health_delta),
				"damage_kind": str(damage_context.get("damage_kind", "action")),
				"is_direct_spell_damage": bool(damage_context.get("is_direct_spell_damage", false)),
				"is_resonance_damage": bool(damage_context.get("is_resonance_damage", false)),
				"original_spell_damage": int(damage_context.get("original_spell_damage", 0))
			}
			_trigger_trait_event("character_damage_taken", player_damage_ctx)
			if source_id != "":
				var dealt_ctx = {"actor_id": source_id, "target_id": character_id, "amount": abs(health_delta), "kind": "dealt"}
				emit_signal("on_damage_dealt", dealt_ctx)
				_trigger_trait_event("endure", dealt_ctx)
		elif health_delta > 0:
			_record_stat_map_value("player_healing_received_by_unit", character_id, health_delta)
		
		if char_state.current_health <= 0:
			var player_death_context := _build_character_death_context(
				character_id,
				"player",
				source_id,
				damage_context,
				old_health,
				int(char_state.current_health),
				int(char_state.max_health)
			)
			if TraitManager:
				TraitManager.trigger_actor_event_for_actor(character_id, "last_breath", player_death_context)
			emit_signal("on_character_death", player_death_context)
			print("[BattleManager] Player character died: ", character_id)
			_remove_team_display_order("frien", character_id)
			remove_certain_portrait(character_id)
			_clear_character_party_dice_faces(character_id, false, "battle_character_death")
			player_data.player_characters.erase(character_id)
			
			if GameManager.current_run and not is_test_mode and not is_tutorial_battle:
				GameManager.current_run.character_current_health[character_id] = 0
				GameManager.current_run.inventory.remove_face_by_character(character_id)
				GameManager.current_run.save_embedded_dice_faces()
				GameManager.save_game()
	elif enemy_data.enemy_fiends.has(character_id):
		var char_state = enemy_data.enemy_fiends[character_id]
		var old_health = int(char_state.current_health)
		print("[BattleManager] Current enemy health (before): ", old_health)
		
		if amount < 0 :
			var incoming_mod = _get_damage_modifiers_from_status_map(char_state.status_effects, "incoming")
			var modified_damage = int(round((abs(amount) + int(incoming_mod.add)) * float(incoming_mod.mul)))
			modified_damage = max(modified_damage, 0)
			amount = -modified_damage
			var shield_absorbed = min(abs(amount), char_state.shield)
			char_state.shield -= shield_absorbed
			var remaining_shield = char_state.shield
			amount += shield_absorbed
			print("[BattleManager] Shield absorbed: ", shield_absorbed, " remaining: ", remaining_shield)
			
			if remaining_shield > 0:
				print("shield remained")
				emit_signal("enemy_shield_changed", char_state, remaining_shield)
			else:
				print("shield broken")
				emit_signal("enemy_shield_changed", char_state, 0)
		
		char_state.current_health = clamp(
		char_state.current_health + amount, 0, char_state.max_health
		)
		
		if amount < 0:
				print("deal ", abs(amount)," damage to enemy")
				emit_signal("enemy_health_changed", amount)
		
		elif amount >= 0:
			emit_signal("enemy_health_changed", amount)

		var enemy_health_delta = int(char_state.current_health) - old_health
		print("[BattleManager] Enemy health (after): ", int(char_state.current_health), " delta=", enemy_health_delta)
		if enemy_health_delta < 0:
			if source_id != "" and player_data.player_characters.has(source_id):
				_record_stat_map_value("player_damage_dealt_by_unit", source_id, abs(enemy_health_delta))
			var enemy_damage_kind = str(damage_context.get("damage_kind", "action"))
			var enemy_taken_ctx = {"actor_id": character_id, "target_id": character_id, "amount": abs(enemy_health_delta), "kind": "taken"}
			emit_signal("on_damage_taken", enemy_taken_ctx)
			_trigger_enemy_trait_event("enemy_damage_taken", {
				"actor_id": character_id,
				"target_id": character_id,
				"source_id": source_id,
				"damage_kind": enemy_damage_kind,
				"amount": abs(enemy_health_delta),
				"old_health": old_health,
				"new_health": int(char_state.current_health),
				"max_health": int(char_state.max_health)
			})
			if source_id != "":
				var dealt_ctx_enemy = {"actor_id": source_id, "target_id": character_id, "amount": abs(enemy_health_delta), "kind": "dealt"}
				emit_signal("on_damage_dealt", dealt_ctx_enemy)
				_trigger_trait_event("endure", dealt_ctx_enemy)
		elif enemy_health_delta > 0:
			current_battle_stats["enemy_healing_received_total"] = int(current_battle_stats.get("enemy_healing_received_total", 0)) + enemy_health_delta
			_trigger_enemy_trait_event("enemy_healed", {
				"actor_id": character_id,
				"target_id": character_id,
				"amount": enemy_health_delta,
				"old_health": old_health,
				"new_health": int(char_state.current_health)
			})

		if char_state.current_health <= 0:
			var enemy_death_context := _build_character_death_context(
				character_id,
				"enemy",
				source_id,
				damage_context,
				old_health,
				int(char_state.current_health),
				int(char_state.max_health)
			)
			if TraitManager:
				TraitManager.trigger_actor_event_for_actor(character_id, "last_breath", enemy_death_context)
			emit_signal("on_character_death", enemy_death_context)
			_trigger_enemy_trait_event("enemy_death_before", {
				"actor_id": character_id,
				"target_id": character_id
			})
			print("[BattleManager] Enemy character died: ", character_id)
			_remove_team_display_order("enemy", character_id)
			remove_certain_portrait(character_id)
			_clear_character_party_dice_faces(character_id, true, "battle_character_death")
			_trigger_enemy_trait_event("enemy_death_after", {
				"actor_id": character_id,
				"target_id": character_id
			})
			enemy_data.enemy_fiends.erase(character_id)

func _build_character_death_context(character_id: String, actor_side: String, source_id: String, damage_context: Dictionary, old_health: int, new_health: int, max_health: int) -> Dictionary:
	return {
		"actor_id": character_id,
		"target_id": character_id,
		"actor_side": actor_side,
		"target_team": actor_side,
		"source_id": source_id,
		"damage_kind": str(damage_context.get("damage_kind", "action")),
		"old_health": old_health,
		"new_health": new_health,
		"max_health": max_health,
		"is_direct_spell_damage": bool(damage_context.get("is_direct_spell_damage", false)),
		"is_resonance_damage": bool(damage_context.get("is_resonance_damage", false)),
		"original_spell_damage": int(damage_context.get("original_spell_damage", 0))
	}

func restore_dice_results(saved_results: Array) -> void:
	dice_results.clear()
	rolled_dice.clear()
	for data in saved_results:
		var result = DiceResult.new()
		result.dice_type = data.get("dice_type", "")
		result.face_up_value = data.get("face_up_value", 0)
		result.face_down_value = data.get("face_down_value", 0)
		dice_results.append(result)
		rolled_dice.append(result.dice_type)
		
		# Update current result reference if needed (usually last one)
		dice_result = result

func update_character_shield(character_id: String, amount: int) -> void:
	print("[BattleManager] update_character_shield called for: ", character_id, " amount: ", amount)
	
	if player_data.player_characters.has(character_id):
		var char_state = player_data.player_characters[character_id]
		var old_shield: int = int(char_state.shield)
		char_state.shield += amount
		var actual_gain: int = max(int(char_state.shield) - old_shield, 0)
		_record_stat_map_value("player_shield_received_by_unit", character_id, actual_gain)
		print("[BattleManager] Player shield updated to: ", char_state.shield)
		emit_signal("allied_shield_changed", char_state, char_state.shield)
		
	elif enemy_data.enemy_fiends.has(character_id):
		var char_state = enemy_data.enemy_fiends[character_id]
		var old_shield: int = int(char_state.shield)
		char_state.shield += amount
		var actual_gain: int = max(int(char_state.shield) - old_shield, 0)
		current_battle_stats["enemy_shield_received_total"] = int(current_battle_stats.get("enemy_shield_received_total", 0)) + actual_gain
		print("[BattleManager] Enemy shield updated to: ", char_state.shield)
		emit_signal("enemy_shield_changed", char_state, char_state.shield)
	else:
		print("[BattleManager] Character not found for shield update: ", character_id)

func modify_character_countdown(character_id: String, delta: int, reset_to_base: bool = false, cause: String = "external") -> void:
	var char_state: Dictionary = {}
	var is_enemy := false
	if player_data.player_characters.has(character_id):
		char_state = player_data.player_characters[character_id]
	elif enemy_data.enemy_fiends.has(character_id):
		char_state = enemy_data.enemy_fiends[character_id]
		is_enemy = true
	else:
		print("[BattleManager] Character not found for countdown update: ", character_id)
		return
	var previous_countdown = int(char_state.get("countdown", 0))
	var next_countdown = int(char_state.get("base_countdown", 0)) if reset_to_base else previous_countdown + delta
	next_countdown = max(next_countdown, 0)
	char_state["countdown"] = next_countdown
	emit_signal("character_countdown_changed", character_id, next_countdown)
	if is_enemy and next_countdown != previous_countdown:
		_trigger_enemy_trait_event("enemy_countdown_changed", {
			"actor_id": character_id,
			"old_countdown": previous_countdown,
			"new_countdown": next_countdown,
			"cause": cause
		})
	if is_enemy and next_countdown < previous_countdown:
		_trigger_enemy_trait_event("enemy_countdown_reduced", {
			"actor_id": character_id,
			"old_countdown": previous_countdown,
			"new_countdown": next_countdown,
			"cause": cause
		})
	if cause != "tick" and previous_countdown > 0 and next_countdown == 0:
		_schedule_immediate_countdown_action(character_id, is_enemy, previous_countdown)

func _schedule_immediate_countdown_action(character_id: String, is_enemy: bool, previous_countdown: int) -> void:
	if character_id == "":
		return
	if countdown_zero_context.has(character_id):
		return
	countdown_zero_context[character_id] = {
		"dice_type": _last_roll_context.get("dice_type", ""),
		"face_up": _last_roll_context.get("face_up", -1),
		"frien_face_owner": _get_face_up_player_id(),
		"sequence_id": _runtime_sequence_id
	}
	if is_enemy:
		_trigger_enemy_trait_event("enemy_countdown_zero", {
			"actor_id": character_id,
			"old_countdown": previous_countdown,
			"new_countdown": 0
		})
	call_deferred("_run_immediate_countdown_action", character_id, is_enemy)

func _run_immediate_countdown_action(character_id: String, is_enemy: bool) -> void:
	await wait_health_queue_flushed()
	var char_state = enemy_data.enemy_fiends.get(character_id) if is_enemy else player_data.player_characters.get(character_id)
	if char_state == null:
		countdown_zero_context.erase(character_id)
		return
	if int(char_state.get("current_health", 0)) <= 0:
		countdown_zero_context.erase(character_id)
		return
	if int(char_state.get("countdown", 0)) != 0:
		countdown_zero_context.erase(character_id)
		return
	await _execute_character_action(character_id, is_enemy)

func cast_hex(hex_data: HexData, caster, trigger_face: int = DiceFace.UP) -> void:
	var caster_id = _resolve_runtime_entity_id(caster)
	var skip_health_wait := _should_skip_spell_resolution_health_wait(hex_data)
	if caster_id != "":
		if not player_data.player_characters.has(caster_id) or \
		   player_data.player_characters[caster_id].current_health <= 0:
			print("[BattleManager] Caster is dead or invalid, cancelling hex cast")
			check_battle_end()
			return
			
		var caster_state = player_data.player_characters[caster_id]
		if _has_crowd_control_flag(StatusTarget.CHARACTER, caster_id, "skip_action") or _status_map_has_crowd_control_flag(caster_state.get("status_effects", {}), "skip_action"):
			print("[BattleManager] Caster action skipped by crowd control: ", caster_id)
			return

	print("[BattleManager] Cast hex called with data:", JSON.stringify({
		"hex_name": hex_data.hex_name,
		"effect_data": hex_data.effect_data,
		"target_data": hex_data.target_data
	}))
	current_battle_stats["player_total_casts"] = int(current_battle_stats.get("player_total_casts", 0)) + 1
	current_caster = caster
	last_target = null
	_begin_spell_resolution(caster_id, false, hex_data)
	var targets = get_all_targets(hex_data)
	print("[BattleManager] Got targets:", targets)
	_emit_spell_visual_request(hex_data, caster_id, targets, false)
	await apply_all_effects(hex_data, targets, trigger_face)
	_apply_mythic_bonus_damage(false)
	if not skip_health_wait:
		await wait_health_queue_flushed()
	_trigger_hex_trait_event(hex_data, "spell_cast_after", trigger_face, false)
	_finish_ally_spell_resolution()



func get_all_targets(hex_data: HexData) -> Dictionary:
	var targets = {}
	var target_blocks = _get_hex_target_blocks(hex_data)
	for i in range(target_blocks.size()):
		var target_block = target_blocks[i]
		var target_key = i
		if typeof(target_block) == TYPE_DICTIONARY and target_block.has("index"):
			target_key = int(target_block.get("index", i))
		targets[target_key] = get_targets(target_block)
		if not targets[target_key].is_empty():
			last_target = targets[target_key][0]
	print("Final targets:", targets)
	return targets

func get_targets(target_info: Dictionary) -> Array:
	print("[BattleManager] Full target_info structure:", JSON.stringify(target_info))
	print("Getting targets with info: ", target_info)
	return _resolve_hex_targets(target_info, false)

func _resolve_hex_targets(target_info: Dictionary, caster_is_enemy: bool) -> Array:
	var results: Array = []
	var condition = target_info.get("condition", {})
	if typeof(condition) != TYPE_DICTIONARY:
		return results
	if bool(condition.get("is_self", false)) or bool(condition.get("self", false)) or str(condition.get("selector", "")) == "self":
		return [current_caster] if current_caster != null else results

	var target_index = int(target_info.get("index", -1))
	var target_type = int(target_info.get("type", TargetType.CHARACTER))
	var target_team = _get_relative_target_team(target_info, caster_is_enemy)

	match target_type:
		TargetType.CHARACTER:
			var selector := str(condition.get("selector", ""))
			if supports_character_target_selector(selector):
				var selector_ids := get_character_target_ids_by_selector(selector, caster_is_enemy, str(condition.get("status_id", "")))
				var selector_team := _get_selector_target_team(selector, caster_is_enemy)
				return _build_hex_character_targets_from_ids(selector_team, selector_ids, target_index)
			if condition.has("dice_reference"):
				if _should_use_front_target_for_hex_character(target_type, condition):
					var front_target_id = _resolve_front_character_id_by_target_team(target_info, caster_is_enemy)
					var front_target = _build_hex_character_target(target_team, front_target_id, target_index)
					if not front_target.is_empty():
						results.append(front_target)
						print("[BattleManager] Found CHARACTER front target: ", front_target_id)
				else:
					var dice_ref = condition.get("dice_reference", {})
					var dice_type_to_find = _get_dice_type_from_ref(dice_ref, int(target_info.get("team", TargetTeam.ENEMY)), caster_is_enemy)
					var face_value = _get_face_value_from_ref(dice_type_to_find, dice_ref)
					face_value = _resolve_referenced_face_index(dice_type_to_find, face_value)
					print("[BattleManager] Resolved CHARACTER target dice: ", dice_type_to_find, " face=", face_value)
					if face_value != -1:
						var target_character_id = _resolve_face_up_character_id(dice_type_to_find, face_value)
						var target_data = _build_hex_character_target(target_team, target_character_id, target_index)
						if not target_data.is_empty():
							results.append(target_data)
							print("[BattleManager] Found CHARACTER target: ", target_character_id)
			else:
				for char_name in target_team.keys():
					var target_data = target_team[char_name].duplicate(true)
					target_data["index"] = target_index
					results.append(target_data)
		TargetType.DICEFACE:
			if condition.has("dice_reference"):
				var dice_ref = condition.get("dice_reference", {})
				var dice_type_to_find = _get_dice_type_from_ref(dice_ref, int(target_info.get("team", TargetTeam.ENEMY)), caster_is_enemy)
				var face_value = _get_face_value_from_ref(dice_type_to_find, dice_ref)
				face_value = _resolve_referenced_face_index(dice_type_to_find, face_value)
				if face_value != -1:
					var target_data = {
						"dice_type": dice_type_to_find,
						"face_index": face_value,
						"index": target_index
					}
					results.append(target_data)
					print("[BattleManager] Found DICEFACE target: ", target_data)
		TargetType.DICE:
			if condition.has("dice_reference"):
				var dice_ref = condition.get("dice_reference", {})
				var dice_type_to_find = _get_dice_type_from_ref(dice_ref, int(target_info.get("team", TargetTeam.ENEMY)), caster_is_enemy)
				var target_data = {
					"dice_type": dice_type_to_find,
					"index": target_index
				}
				results.append(target_data)
				print("[BattleManager] Found DICE target: ", target_data)
	return results

func _get_relative_target_team(target_info: Dictionary, caster_is_enemy: bool) -> Dictionary:
	var target_team_kind = int(target_info.get("team", TargetTeam.ENEMY))
	if caster_is_enemy:
		return enemy_data.enemy_fiends if target_team_kind == TargetTeam.ALLY else player_data.player_characters
	return player_data.player_characters if target_team_kind == TargetTeam.ALLY else enemy_data.enemy_fiends

func _should_use_front_target_for_hex_character(target_type: int, condition: Dictionary) -> bool:
	if target_type != TargetType.CHARACTER:
		return false
	var dice_reference = condition.get("dice_reference", {})
	if typeof(dice_reference) != TYPE_DICTIONARY:
		return false
	return int(dice_reference.get("type", -1)) == DiceType.FRIEND and int(dice_reference.get("face", -1)) == DiceFace.UP

func _resolve_front_character_id_by_target_team(target_info: Dictionary, caster_is_enemy: bool) -> String:
	var target_team_kind = int(target_info.get("team", TargetTeam.ENEMY))
	if caster_is_enemy:
		return _get_front_enemy_id() if target_team_kind == TargetTeam.ALLY else _get_front_player_id()
	return _get_front_player_id() if target_team_kind == TargetTeam.ALLY else _get_front_enemy_id()

func _build_hex_character_target(target_team: Dictionary, target_character_id: String, target_index: int) -> Dictionary:
	if target_character_id == "" or not target_team.has(target_character_id):
		return {}
	var target_data = target_team[target_character_id].duplicate(true)
	target_data["index"] = target_index
	return target_data

func _build_hex_character_targets_from_ids(target_team: Dictionary, target_ids: Array, target_index: int) -> Array:
	var results: Array = []
	for raw_target_id in target_ids:
		var target_id := str(raw_target_id)
		if target_id == "":
			continue
		var target_data := _build_hex_character_target(target_team, target_id, target_index)
		if not target_data.is_empty():
			results.append(target_data)
	return results

func _get_selector_target_team(selector: String, caster_is_enemy: bool) -> Dictionary:
	match selector:
		"front_ally", "back_ally", "lowest_health_ally", "highest_health_ally", "status_ally":
			return enemy_data.enemy_fiends if caster_is_enemy else player_data.player_characters
		"front_enemy", "back_enemy", "lowest_health_enemy", "highest_health_enemy", "status_enemy":
			return player_data.player_characters if caster_is_enemy else enemy_data.enemy_fiends
	return {}

func _get_dice_type_from_ref(dice_ref: Dictionary, team_type: int, caster_is_enemy: bool = false) -> String:
	var target_is_enemy_side = false
	if caster_is_enemy:
		target_is_enemy_side = team_type == TargetTeam.ALLY
	else:
		target_is_enemy_side = team_type == TargetTeam.ENEMY

	var dice_ref_type = int(dice_ref.get("type", -1))
	if target_is_enemy_side:
		match dice_ref_type:
			DiceType.FRIEND:
				return "enemy_frien"
			DiceType.ACTION:
				return "enemy_equipment"
			DiceType.HEX:
				return "enemy_hex2"
	else:
		match dice_ref_type:
			DiceType.FRIEND:
				return "frien"
			DiceType.ACTION:
				return "equipment"
			DiceType.HEX:
				return "hex2"
	return ""

func _resolve_referenced_face_index(dice_type: String, face_index: int) -> int:
	if dice_type == "" or face_index < 0:
		return face_index
	if EmbeddedDiceFaces.is_filled_face(dice_type, face_index):
		return face_index
	return EmbeddedDiceFaces.get_highest_filled_face_index(dice_type)

func _get_face_value_from_ref(dice_type: String, dice_ref: Dictionary) -> int:
	var face_value = -1
	for result in dice_results:
		if result.dice_type == dice_type:
			if dice_ref.face == DiceFace.UP:
				face_value = result.face_up_value
			elif dice_ref.face == DiceFace.DOWN:
				face_value = result.face_down_value
			return face_value
	if dice_ref.face == DiceFace.SIDE:
		return -1
	var dice_node = _get_dice_node_by_type(dice_type)
	if not dice_node:
		return -1
	var up_face = int(dice_node.current_face_index)
	if dice_ref.face == DiceFace.UP:
		return up_face
	if dice_ref.face == DiceFace.DOWN:
		return 5 - up_face
	return -1

func apply_all_effects(hex_data: HexData, targets: Dictionary, trigger_face: int = DiceFace.UP) -> void:
	print("[BattleManager] Applying all effects for hex:", hex_data.hex_name)
	print("[BattleManager] Effect data:", hex_data.effect_data)
	var caster_is_enemy = bool(_current_spell_context.get("is_enemy_spell", false))
	_trigger_hex_trait_event(hex_data, "spell_cast_before", trigger_face, caster_is_enemy)
	
	for effect_index in range(_get_hex_effect_blocks(hex_data).size()):
		var effect = _get_hex_effect_blocks(hex_data)[effect_index]
		if effect.has("cast_condition"):
			var effect_condition = int(effect.get("cast_condition", DiceFace.UP))
			if effect_condition != trigger_face:
				continue
		print("[BattleManager] Processing effect:", effect)
		var target_indices = effect.get("target_index", [])
		print("[BattleManager] Target indices:", target_indices)
		
		if typeof(target_indices) != TYPE_ARRAY:
			target_indices = [target_indices]
			print("[BattleManager] Converted target indices to array:", target_indices)
		
		print("[BattleManager] Processing effect with target indices:", target_indices)
		var resolved_targets: Array = _resolve_effect_targets_by_indices(targets, target_indices)
		var read_target_indices = effect.get("read_target_index", [])
		var resolved_read_targets: Array = _resolve_effect_targets_by_indices(targets, read_target_indices)
		_trigger_hex_trait_event(hex_data, "spell_effect_before", trigger_face, caster_is_enemy, {
			"effect": effect.duplicate(true),
			"effect_index": effect_index,
			"resolved_targets": resolved_targets.duplicate(true),
			"target_indices": target_indices.duplicate(),
			"resolved_read_targets": resolved_read_targets.duplicate(true),
			"read_target_indices": read_target_indices.duplicate() if typeof(read_target_indices) == TYPE_ARRAY else [read_target_indices]
		})
		for index in target_indices:
			print("[BattleManager] Processing target index:", index)
			var int_index = int(index)
			print("[BattleManager] targets with index: ", targets.has(index))
			if targets.has(int_index):
				print("[BattleManager] Applying effect to targets at index:", index)
				print("[BattleManager] Target data:", targets[int_index])
				await apply_effect(effect, targets[int_index], resolved_read_targets)
			else:
				print("[BattleManager] No targets found for index:", index)
		_trigger_hex_trait_event(hex_data, "spell_effect_after", trigger_face, caster_is_enemy, {
			"effect": effect.duplicate(true),
			"effect_index": effect_index,
			"resolved_targets": resolved_targets.duplicate(true),
			"target_indices": target_indices.duplicate(),
			"resolved_read_targets": resolved_read_targets.duplicate(true),
			"read_target_indices": read_target_indices.duplicate() if typeof(read_target_indices) == TYPE_ARRAY else [read_target_indices]
		})
	await wait_health_queue_flushed()


func _resolve_effect_targets_by_indices(targets_by_index: Dictionary, raw_indices) -> Array:
	var resolved_targets: Array = []
	var target_indices = raw_indices
	if typeof(target_indices) != TYPE_ARRAY:
		target_indices = [target_indices]
	for target_index in target_indices:
		var idx = int(target_index)
		var effect_targets = targets_by_index.get(idx, [])
		if typeof(effect_targets) != TYPE_ARRAY:
			continue
		for target in effect_targets:
			resolved_targets.append(target)
	return resolved_targets


func apply_effect(effect: Dictionary, targets: Array, read_targets: Array = []) -> void:
	print("[BattleManager] Starting apply_effect")
	print("[BattleManager] Effect:", effect)
	print("[BattleManager] Targets:", targets)
	
	if not effect.has("type"):
		print("[BattleManager] ERROR: Effect has no type")
		return
	if typeof(effect.get("type")) == TYPE_STRING:
		var string_type := str(effect.get("type", ""))
		match string_type:
			"status_extend":
				print("[BattleManager] Applying status extend effect")
				_record_spell_character_targets(targets)
				var status_id = str(effect.get("status_id", ""))
				var duration_delta = int(effect.get("duration", 0))
				if status_id == "" or duration_delta <= 0:
					print("[BattleManager] Invalid status_extend effect: ", effect)
					return
				for target in targets:
					extend_status_on_target(target, status_id, duration_delta)
				return
			_:
				print("[BattleManager] Unknown string effect type:", string_type)
				return
	
	match int(effect.get("type", -1)):
		EffectType.HEALTH_CHANGE:
			print("[BattleManager] Applying health change effect")
			await apply_health_change(effect, targets, read_targets)
		EffectType.STATUS_APPLY:
			print("[BattleManager] Applying status effect")
			_record_spell_character_targets(targets)
			apply_status(effect, targets, read_targets)
		EffectType.SPECIAL:
			print("[BattleManager] Applying special effect")
			_record_spell_character_targets(targets)
			await apply_special_effect(effect, targets)
		EffectType.SHIELD_CHANGE:
			print("[BattleManager] Applying shield change effect")
			_record_spell_character_targets(targets)
			apply_shield_change(effect, targets, read_targets)
		_:
			print("[BattleManager] Unknown effect type:", effect.get("type", null))

func apply_special_effect(effect: Dictionary, targets: Array) -> void:
	var special_id = effect.get("special_id", "")
	match special_id:
		"flip_dice":
			var raw_direction = str(effect.get("flip_direction", ""))
			var direction = _parse_flip_direction(raw_direction)
			if direction == -1:
				print("[BattleManager] Invalid flip direction: ", raw_direction)
			else:
				for target in targets:
					if typeof(target) != TYPE_DICTIONARY:
						continue
					var dice_type = str(target.get("dice_type", ""))
					if dice_type == "":
						continue
					var dice_node = _get_dice_node_by_type(dice_type)
					if dice_node == null or not dice_node.has_method("flip"):
						print("[BattleManager] Could not find flippable dice for type: ", dice_type)
						continue
					dice_node.flip(direction)
		"roll_dice":
			for target in targets:
				if typeof(target) != TYPE_DICTIONARY:
					continue
				var dice_type = str(target.get("dice_type", ""))
				if dice_type == "":
					continue
				var dice_node = _get_dice_node_by_type(dice_type)
				if dice_node == null:
					print("[BattleManager] Could not find reroll target for type: ", dice_type)
					continue
				await reroll_single_dice(dice_node)
		"retreat":
			var steps := int(effect.get("steps", 0))
			for target in targets:
				if typeof(target) != TYPE_DICTIONARY:
					continue
				var target_id := _resolve_runtime_entity_id(target)
				if target_id == "":
					continue
				await retreat_unit_with_tween(target_id, steps)
		"advance":
			var steps := int(effect.get("steps", 0))
			for target in targets:
				if typeof(target) != TYPE_DICTIONARY:
					continue
				var target_id := _resolve_runtime_entity_id(target)
				if target_id == "":
					continue
				await advance_unit_with_tween(target_id, steps)
		"burn_consume":
			for target in targets:
				var target_id = _resolve_runtime_entity_id(target)
				if target_id == "":
					continue
				var char_state = null
				if player_data.player_characters.has(target_id):
					char_state = player_data.player_characters[target_id]
				elif enemy_data.enemy_fiends.has(target_id):
					char_state = enemy_data.enemy_fiends[target_id]
				if not char_state:
					continue

				var status_id = str(effect.get("status_id", "st002"))
				var status_data = GameDataManager.get_status_data(status_id)
				var consumed_status_name = _get_status_runtime_key(status_data)
				var status_map = char_state.status_effects
				if status_map.has(consumed_status_name) and _is_status_effectively_active(status_map[consumed_status_name]):
					var consumed_status = status_map[consumed_status_name]
					var stacks = int(consumed_status.get("stacks", 1))
					var damage = stacks * 4
					update_character_health(target_id, -damage)
					status_map.erase(consumed_status_name)
					emit_signal("character_status_changed", target_id, status_map)
				else:
					if status_data.is_empty():
						continue
					var status_info = {
						"id": status_data.get("id", status_id),
						"status_name": status_data.get("status_name", ""),
						"status_type": status_data.get("status_type", StatusType.DEBUFF),
						"category": status_data.get("category", Category.DoT),
						"status_target": status_data.get("status_target", StatusTarget.CHARACTER),
						"duration": status_data.get("duration", 0),
						"stack_count": 1,
						"effects": status_data.get("effects", {})
					}
					apply_status({"status_info": status_info}, [{"name": target_id}])
		_:
			print("[BattleManager] Unknown special effect:", special_id)
	await wait_health_queue_flushed()

func _parse_flip_direction(raw_direction: String) -> int:
	match raw_direction.to_upper():
		"UP":
			return 0
		"DOWN":
			return 1
		"LEFT":
			return 2
		"RIGHT":
			return 3
	return -1

func _get_status_map_for_target(target) -> Dictionary:
	if typeof(target) == TYPE_DICTIONARY:
		var dice_type = str(target.get("dice_type", ""))
		if dice_type == "":
			var target_id = _resolve_runtime_entity_id(target)
			if target_id != "":
				var char_state = _get_character_state(target_id)
				if char_state != null:
					return char_state.get("status_effects", {})
			return {}
		if target.has("face_index"):
			var face_index = int(target.get("face_index", -1))
			if face_index >= 0 and face_statuses.has(dice_type) and face_statuses[dice_type].has(face_index):
				return face_statuses[dice_type][face_index]
			return {}
		if dice_statuses.has(dice_type):
			return dice_statuses[dice_type]
		return {}
	var target_id = str(target)
	if target_id == "":
		return {}
	var char_state = _get_character_state(target_id)
	if char_state == null:
		return {}
	return char_state.get("status_effects", {})

func _get_status_stack_count_on_target(target, status_id: String = "", status_name: String = "") -> int:
	var status_map = _get_status_map_for_target(target)
	if typeof(status_map) != TYPE_DICTIONARY or status_map.is_empty():
		return 0
	if status_name != "" and status_map.has(status_name):
		var direct_status = status_map[status_name]
		if _is_status_effectively_active(direct_status):
			return int(direct_status.get("stacks", 1))
	if status_id != "":
		for existing_status_name in status_map.keys():
			var existing_status = status_map[existing_status_name]
			if str(existing_status.get("id", "")) != status_id:
				continue
			if _is_status_effectively_active(existing_status):
				return int(existing_status.get("stacks", 1))
	return 0

func _get_total_read_status_stacks(effect: Dictionary, read_targets: Array) -> int:
	var read_status_id = str(effect.get("read_status_id", ""))
	var read_status_name = str(effect.get("read_status_name", ""))
	if read_status_id == "" and read_status_name == "":
		return 0
	var total_stacks := 0
	for read_target in read_targets:
		total_stacks += _get_status_stack_count_on_target(read_target, read_status_id, read_status_name)
	return total_stacks

func _get_runtime_char_stat_value_on_target(target, stat_name: String) -> int:
	if stat_name == "":
		return 0
	var char_state = null
	if typeof(target) == TYPE_DICTIONARY:
		if str(target.get("dice_type", "")) != "":
			return 0
		var target_id = _resolve_runtime_entity_id(target)
		if target_id == "":
			return 0
		char_state = _get_character_state(target_id)
	elif typeof(target) == TYPE_STRING:
		char_state = _get_character_state(str(target))
	else:
		return 0
	if char_state == null:
		return 0
	match stat_name:
		"current_health":
			return int(char_state.get("current_health", 0))
		"max_health":
			return int(char_state.get("max_health", 0))
		"shield":
			return int(char_state.get("shield", 0))
		"countdown":
			return int(char_state.get("countdown", 0))
		"base_countdown":
			return int(char_state.get("base_countdown", 0))
		_:
			print("[BattleManager] Unsupported read_char_stat: ", stat_name)
			return 0

func _get_total_read_char_stat_value(effect: Dictionary, read_targets: Array) -> int:
	var read_char_stat = str(effect.get("read_char_stat", ""))
	if read_char_stat == "":
		return 0
	var total_value := 0
	for read_target in read_targets:
		total_value += _get_runtime_char_stat_value_on_target(read_target, read_char_stat)
	return total_value

func _get_effect_read_bonus(effect: Dictionary, read_targets: Array) -> int:
	var bonus := 0
	var read_value_per_stack = int(effect.get("read_value_per_stack", 0))
	if read_value_per_stack != 0:
		bonus += _get_total_read_status_stacks(effect, read_targets) * read_value_per_stack
	var read_value_per_point = int(effect.get("read_value_per_point", 0))
	if read_value_per_point != 0:
		bonus += _get_total_read_char_stat_value(effect, read_targets) * read_value_per_point
	return bonus

func _resolve_health_change_value(effect: Dictionary, read_targets: Array) -> int:
	var base_value = int(effect.get("value", 0))
	return base_value + _get_effect_read_bonus(effect, read_targets)

func _resolve_shield_change_value(effect: Dictionary, read_targets: Array) -> int:
	var base_value = int(effect.get("value", 0))
	return base_value + _get_effect_read_bonus(effect, read_targets)

func get_source_healing_bonus(source_id: String) -> int:
	if source_id == "":
		return 0
	var is_enemy_source := false
	if player_data.player_characters.has(source_id):
		is_enemy_source = false
	elif enemy_data.enemy_fiends.has(source_id):
		is_enemy_source = true
	elif get_face_up_equipment_owner_id(false) == source_id:
		is_enemy_source = false
	elif get_face_up_equipment_owner_id(true) == source_id:
		is_enemy_source = true
	else:
		return 0
	var equip_info := _get_equipment_face_up(is_enemy_source)
	if str(equip_info.get("equipment_id", "")) == "eq009":
		return 2
	return 0

func apply_sourced_healing(target_id: String, amount: int, source_id: String = "", overflow_to_shield: bool = false) -> void:
	if target_id == "" or amount <= 0:
		return
	var final_amount := amount
	if source_id != "":
		final_amount += get_source_healing_bonus(source_id)
	if final_amount <= 0:
		return
	if overflow_to_shield:
		var current_health := 0
		var max_health := 0
		if player_data.player_characters.has(target_id):
			var player_state: Dictionary = player_data.player_characters[target_id]
			current_health = int(player_state.get("current_health", 0))
			max_health = int(player_state.get("max_health", current_health))
		elif enemy_data.enemy_fiends.has(target_id):
			var enemy_state: Dictionary = enemy_data.enemy_fiends[target_id]
			current_health = int(enemy_state.get("current_health", 0))
			max_health = int(enemy_state.get("max_health", current_health))
		var missing_health = max(max_health - current_health, 0)
		var actual_heal = min(final_amount, missing_health)
		var overflow = max(final_amount - actual_heal, 0)
		if actual_heal > 0:
			update_character_health(target_id, actual_heal)
		if overflow > 0:
			update_character_shield(target_id, overflow)
		return
	update_character_health(target_id, final_amount)

func apply_health_change(effect:Dictionary, targets: Array, read_targets: Array = []) -> void:
	print("[BattleManager] Starting health change application")
	var base_value = _resolve_health_change_value(effect, read_targets)
	var overflow_to_shield = bool(effect.get("overflow_to_shield", false))
	var source_id := _resolve_current_source_id()
	print("[BattleManager] Base health change value:", base_value)
	
	for target in targets:
		var final_value = base_value
		
		# Only calculate damage/healing modifications if it's not a fixed value setting (though currently all are relative)
		# And only if there is a caster (source)
		if current_caster and base_value < 0:
			final_value = calculate_final_damage(base_value, current_caster, target)
		
		var target_id = _resolve_runtime_entity_id(target)
		if target_id == "":
			print("[BattleManager] Skipping health change, unresolved target: ", target)
			continue
		_record_spell_character_target(target_id)
		print("[BattleManager] Applying final health change ", final_value, " to target:", target_id)
		if final_value > 0:
			apply_sourced_healing(target_id, final_value, source_id, overflow_to_shield)
			continue
		var damage_context: Dictionary = {}
		if final_value < 0:
			damage_context = {
				"damage_kind": "action",
				"is_direct_spell_damage": true,
				"is_resonance_damage": false,
				"original_spell_damage": abs(final_value)
			}
		update_character_health(target_id, final_value, damage_context)
	
	await wait_health_queue_flushed()

func calculate_final_damage(base_value: int, source, _target) -> int:
	var final_value = base_value
	var source_name = ""
	if source is Dictionary:
		source_name = source.get("name", "")
	elif source is Object:
		if "character_name" in source:
			source_name = source.character_name
		elif "unique_id" in source and source.unique_id != "":
			source_name = source.unique_id
		elif "enemy_name" in source:
			source_name = source.enemy_name
		elif "name" in source:
			source_name = source.name
	var is_source_enemy = enemy_data.enemy_fiends.has(source_name)
	var equipment_stats = {}
	var forced_face_index = -1
	var forced_dice_type = "enemy_equipment" if is_source_enemy else "equipment"
	var forced_face_data = null
	if not _forced_equipment_context.is_empty():
		equipment_stats = _forced_equipment_context.get("stats", {})
		forced_face_index = int(_forced_equipment_context.get("face_index", -1))
		forced_dice_type = _forced_equipment_context.get("dice_type", forced_dice_type)
		forced_face_data = _forced_equipment_context.get("face_data", null)
	else:
		equipment_stats = get_current_equipment_stats(is_source_enemy)
		forced_face_data = _get_equipment_face_up(is_source_enemy).get("face_data", null)

	if base_value < 0:
		final_value -= int(equipment_stats.get("attack_bonus", 0))
	elif base_value > 0:
		final_value += int(equipment_stats.get("attack_bonus", 0))

	if base_value < 0:
		var outgoing_mod = {"add": 0, "mul": 1.0}
		var source_state = _get_character_state(source_name)
		if source_state and source_state.has("status_effects"):
			outgoing_mod = _merge_damage_modifiers(outgoing_mod, _get_damage_modifiers_from_status_map(source_state.status_effects, "outgoing"))
		if dice_statuses.has(forced_dice_type):
			outgoing_mod = _merge_damage_modifiers(outgoing_mod, _get_damage_modifiers_from_status_map(dice_statuses[forced_dice_type], "outgoing"))
		if forced_face_index >= 0 and face_statuses.has(forced_dice_type) and face_statuses[forced_dice_type].has(forced_face_index):
			outgoing_mod = _merge_damage_modifiers(outgoing_mod, _get_damage_modifiers_from_status_map(face_statuses[forced_dice_type][forced_face_index], "outgoing"))
		outgoing_mod = _merge_damage_modifiers(outgoing_mod, _get_forged_face_outgoing_modifiers(forced_face_data))
		var damage_value = abs(final_value)
		damage_value = int(round((damage_value + int(outgoing_mod.add)) * float(outgoing_mod.mul)))
		damage_value = max(damage_value, 0)
		final_value = -damage_value

	return final_value

func get_current_equipment_stats(is_enemy: bool) -> Dictionary:
	var stats = {
		"attack_bonus": 0,
		"defense_bonus": 0
	}
	var equip_info = _get_equipment_face_up(is_enemy)
	var face_data = equip_info.get("face_data", null)
	if face_data:
		stats.attack_bonus += int(face_data.attack_bonus)
		stats.defense_bonus += int(face_data.defense_bonus)
	var equipment_id = str(equip_info.get("equipment_id", ""))
	if equipment_id != "":
		var equipment_def = GameDataManager.get_equipment_data(equipment_id)
		for trait_id in equipment_def.get("traits", []):
			var trait_id_str = str(trait_id)
			if trait_id_str == "":
				continue
			var trait_state = get_equipment_trait_state(equipment_id, trait_id_str, {})
			if trait_state.has("charge_stacks"):
				stats.attack_bonus = int(trait_state.get("base_attack_bonus", stats.attack_bonus)) + int(trait_state.get("charge_stacks", 0)) * int(trait_state.get("charge_step_attack_bonus", 0))
	return stats

func _get_equipment_runtime_face_data(equipment_id: String, is_enemy: bool = false):
	if equipment_id == "":
		return null
	var equip_info = _get_equipment_face_up(is_enemy)
	var current_face_data = equip_info.get("face_data", null)
	if _face_matches_equipment_id(current_face_data, equipment_id):
		return current_face_data
	var faces_dict = EmbeddedDiceFaces.get_dice_faces("enemy_equipment" if is_enemy else "equipment")
	for face_data in faces_dict.values():
		if _face_matches_equipment_id(face_data, equipment_id):
			return face_data
	return null

func _face_matches_equipment_id(face_data, equipment_id: String) -> bool:
	if face_data == null or equipment_id == "":
		return false
	if typeof(face_data) == TYPE_DICTIONARY:
		if str(face_data.get("id", "")) == equipment_id:
			return true
		return GameDataManager.get_equipment_id_by_name(str(face_data.get("equipment_name", ""))) == equipment_id
	if str(face_data.id) == equipment_id:
		return true
	return GameDataManager.get_equipment_id_by_name(str(face_data.equipment_name)) == equipment_id

func _get_forged_variant_id_from_face_data(face_data) -> String:
	if face_data == null:
		return ""
	if typeof(face_data) == TYPE_DICTIONARY:
		return str(face_data.get("forged_variant_id", ""))
	return str(face_data.forged_variant_id)

func _get_forged_face_outgoing_modifiers(face_data) -> Dictionary:
	var status_name := ""
	match _get_forged_variant_id_from_face_data(face_data):
		"sharp":
			status_name = "sharp"
		"thick":
			status_name = "pressed"
	if status_name == "":
		return {"add": 0, "mul": 1.0}
	var status_data = GameDataManager.get_status_data_by_name(status_name)
	if status_data.is_empty():
		return {"add": 0, "mul": 1.0}
	var effects = status_data.get("effects", {})
	return {
		"add": int(effects.get("outgoing_damage_add", 0)),
		"mul": float(effects.get("outgoing_damage_mul", 1.0))
	}

func _apply_mythic_bonus_damage(is_enemy: bool) -> void:
	var equip_info = _get_equipment_face_up(is_enemy)
	var face_data = equip_info.get("face_data", null)
	if _get_forged_variant_id_from_face_data(face_data) != "mythic":
		return
	var target_id := ""
	if is_enemy:
		target_id = _get_face_up_player_id()
	else:
		target_id = get_face_up_enemy_id()
	if target_id == "" and typeof(last_target) == TYPE_DICTIONARY:
		target_id = str(last_target.get("name", ""))
	if target_id == "":
		return
	apply_separate_damage(target_id, 3, {"damage_kind": "mythic"})

func apply_shield_change(effect: Dictionary, targets: Array, read_targets: Array = []) -> void:
	print("[BattleManager] Starting shield change application")
	var base_value = _resolve_shield_change_value(effect, read_targets)
	
	# Calculate bonus from equipment (Defense Bonus)
	var is_source_enemy = false
	if current_caster:
		is_source_enemy = enemy_data.enemy_fiends.has(_resolve_runtime_entity_id(current_caster))
	
	var equipment_stats = get_current_equipment_stats(is_source_enemy)
	var final_value = base_value + equipment_stats.defense_bonus
	
	print("[BattleManager] Shield change: Base=", base_value, " Bonus=", equipment_stats.defense_bonus, " Final=", final_value)
	
	for target in targets:
		var target_id = _resolve_runtime_entity_id(target)
		if target_id == "":
			print("[BattleManager] Skipping shield change, unresolved target: ", target)
			continue
		update_character_shield(target_id, final_value)
		

func _get_sorted_party_slots(is_enemy: bool) -> Array:
	var slots: Array = []
	var faces = EmbeddedDiceFaces.enemy_frien_dice_faces if is_enemy else EmbeddedDiceFaces.frien_dice_faces
	for i in range(6):
		if not faces.has(i):
			continue
		var face = faces[i]
		var char_id = _get_party_face_character_id(face, is_enemy)
		if char_id != "" and not slots.has(char_id):
			slots.append(char_id)
	return slots

func _get_character_slot_index(character_name: String, is_enemy: bool) -> int:
	var slots = _get_sorted_party_slots(is_enemy)
	var index = slots.find(character_name)
	if index == -1:
		return 999
	return index

func _tick_action_sorter(a: Dictionary, b: Dictionary) -> bool:
	if a.is_enemy != b.is_enemy:
		return not a.is_enemy
	var a_slot = _get_character_slot_index(a.char_id, a.is_enemy)
	var b_slot = _get_character_slot_index(b.char_id, b.is_enemy)
	return a_slot < b_slot

func _get_equipment_face_up(is_enemy: bool) -> Dictionary:
	var dice_type = "enemy_equipment" if is_enemy else "equipment"
	var face_index = -1
	for result in dice_results:
		if result.dice_type == dice_type:
			face_index = result.face_up_value
			break
	if face_index < 0:
		var dice_node = _get_dice_node_by_type(dice_type)
		if dice_node:
			face_index = int(dice_node.current_face_index)
	if face_index < 0:
		return {"dice_type": dice_type, "face_index": -1, "equipment_id": "", "face_data": null, "stats": {"attack_bonus": 0, "defense_bonus": 0}}
	var faces_dict = EmbeddedDiceFaces.get_dice_faces(dice_type)
	if not faces_dict.has(face_index):
		return {"dice_type": dice_type, "face_index": face_index, "equipment_id": "", "face_data": null, "stats": {"attack_bonus": 0, "defense_bonus": 0}}
	var face_data = faces_dict[face_index]
	if EmbeddedDiceFaces.is_default_face(face_data):
		return {"dice_type": dice_type, "face_index": face_index, "equipment_id": "", "face_data": null, "stats": {"attack_bonus": 0, "defense_bonus": 0}}
	var equipment_id = str(face_data.id)
	if equipment_id == "":
		equipment_id = GameDataManager.get_equipment_id_by_name(str(face_data.equipment_name))
	return {
		"dice_type": dice_type,
		"face_index": face_index,
		"equipment_id": equipment_id,
		"face_data": face_data,
		"stats": {
			"attack_bonus": int(face_data.attack_bonus),
			"defense_bonus": int(face_data.defense_bonus)
		}
	}

func _get_hex_face_up(is_enemy: bool) -> Dictionary:
	var dice_type = "enemy_hex2" if is_enemy else "hex2"
	var face_index = -1
	for result in dice_results:
		if result.dice_type == dice_type:
			face_index = result.face_up_value
			break
	if face_index < 0:
		var dice_node = _get_dice_node_by_type(dice_type)
		if dice_node:
			face_index = int(dice_node.current_face_index)
	var faces_dict = EmbeddedDiceFaces.enemy_hex_dice_faces if is_enemy else EmbeddedDiceFaces.hex_dice_faces
	if face_index < 0 or not faces_dict.has(face_index):
		return {"face_index": -1, "hex_data": null}
	var face_data = faces_dict[face_index]
	if EmbeddedDiceFaces.is_default_face(face_data):
		return {"face_index": face_index, "hex_data": null}
	return {"face_index": face_index, "hex_data": face_data}

func get_unit_imminent_spell_preview(unit_id: String) -> Dictionary:
	var result := {
		"visible": false,
		"hex_id": "",
		"hex_texture_path": "",
		"is_enemy": false,
		"layout_variant": "single",
		"entries": []
	}
	if unit_id == "":
		return result
	var is_enemy := false
	var unit_state: Dictionary = {}
	if player_data.player_characters.has(unit_id):
		unit_state = player_data.player_characters.get(unit_id, {})
	elif enemy_data.enemy_fiends.has(unit_id):
		unit_state = enemy_data.enemy_fiends.get(unit_id, {})
		is_enemy = true
	else:
		return result
	result["is_enemy"] = is_enemy
	if typeof(unit_state) != TYPE_DICTIONARY or unit_state.is_empty():
		return result
	if int(unit_state.get("current_health", 0)) <= 0:
		return result
	if int(unit_state.get("countdown", 0)) != 1:
		return result
	var hex_info := _get_hex_face_up(is_enemy)
	var hex_data = hex_info.get("hex_data", null)
	if hex_data == null or EmbeddedDiceFaces.is_default_face(hex_data):
		return result
	var hex_id := str(hex_data.id)
	var hex_texture_path := str(hex_data.texture_path)
	if hex_id == "" or hex_texture_path == "":
		return result
	var entries := _build_imminent_spell_preview_entries(hex_data, unit_id, is_enemy)
	if entries.is_empty():
		return result
	result["visible"] = true
	result["hex_id"] = hex_id
	result["hex_texture_path"] = hex_texture_path
	result["layout_variant"] = "double" if entries.size() >= 2 else "single"
	result["entries"] = entries
	return result

func _build_imminent_spell_preview_entries(hex_data: HexData, caster_id: String, caster_is_enemy: bool) -> Array:
	var entries: Array = []
	if hex_data == null:
		return entries
	var use_effect_conditions := _has_any_effect_cast_condition(hex_data)
	if not _can_preview_hex_for_face_up(hex_data, use_effect_conditions):
		return entries
	var resolved_targets_by_index := _resolve_preview_targets_by_index(hex_data, caster_id, caster_is_enemy)
	for effect in hex_data.effect_data:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if not _should_include_preview_effect(hex_data, effect, use_effect_conditions):
			continue
		var effect_type := int(effect.get("type", -1))
		var target_indices = effect.get("target_index", [])
		if typeof(target_indices) != TYPE_ARRAY:
			target_indices = [target_indices]
		var read_target_indices = effect.get("read_target_index", [])
		var read_targets: Array = _resolve_effect_targets_by_indices(resolved_targets_by_index, read_target_indices)
		for raw_target_index in target_indices:
			var target_index := int(raw_target_index)
			var resolved_targets: Array = resolved_targets_by_index.get(target_index, [])
			if resolved_targets.is_empty():
				continue
			var target_block := _find_hex_target_block_by_index(hex_data, target_index)
			if target_block.is_empty():
				continue
			if int(target_block.get("type", TargetType.CHARACTER)) != TargetType.CHARACTER:
				continue
			var entry := _build_imminent_spell_preview_entry(effect, effect_type, target_block, target_index, read_targets, caster_id)
			if entry.is_empty():
				continue
			entries.append(entry)
	return entries

func _should_include_preview_effect(hex_data: HexData, effect: Dictionary, use_effect_conditions: bool) -> bool:
	var effect_type := int(effect.get("type", -1))
	if effect_type != EffectType.HEALTH_CHANGE and effect_type != EffectType.SHIELD_CHANGE:
		return false
	if effect.has("cast_condition"):
		return int(effect.get("cast_condition", DiceFace.UP)) == DiceFace.UP
	if use_effect_conditions:
		return true
	return int(hex_data.cast_condition) == DiceFace.UP

func _can_preview_hex_for_face_up(hex_data: HexData, use_effect_conditions: bool) -> bool:
	if use_effect_conditions:
		return _has_effect_for_cast_condition(hex_data, DiceFace.UP)
	return int(hex_data.cast_condition) == DiceFace.UP

func _resolve_preview_targets_by_index(hex_data: HexData, caster_id: String, caster_is_enemy: bool) -> Dictionary:
	var resolved_targets: Dictionary = {}
	if hex_data == null:
		return resolved_targets
	for raw_target_block in _get_hex_target_blocks(hex_data):
		if typeof(raw_target_block) != TYPE_DICTIONARY:
			continue
		var target_block: Dictionary = raw_target_block
		var target_index := int(target_block.get("index", resolved_targets.size()))
		resolved_targets[target_index] = _resolve_preview_targets_for_block(target_block, caster_id, caster_is_enemy)
	return resolved_targets

func _resolve_preview_targets_for_block(target_block: Dictionary, caster_id: String, caster_is_enemy: bool) -> Array:
	var previous_caster = current_caster
	current_caster = {"name": caster_id}
	var resolved_targets: Array = _resolve_hex_targets(target_block, caster_is_enemy)
	current_caster = previous_caster
	return resolved_targets

func _find_hex_target_block_by_index(hex_data: HexData, target_index: int) -> Dictionary:
	if hex_data == null:
		return {}
	for raw_target_block in _get_hex_target_blocks(hex_data):
		if typeof(raw_target_block) != TYPE_DICTIONARY:
			continue
		var target_block: Dictionary = raw_target_block
		var block_index := int(target_block.get("index", -1))
		if block_index == target_index:
			return target_block
	return {}

func _build_imminent_spell_preview_entry(effect: Dictionary, effect_type: int, target_block: Dictionary, target_index: int, read_targets: Array, caster_id: String = "") -> Dictionary:
	var entry := {}
	var target_scope := _resolve_imminent_spell_preview_target_scope(target_block)
	if effect_type == EffectType.HEALTH_CHANGE:
		var value := _resolve_health_change_value(effect, read_targets)
		if value > 0 and caster_id != "":
			value += get_source_healing_bonus(caster_id)
		if value == 0:
			return {}
		if value < 0:
			var damage_value = abs(value)
			if damage_value <= 0:
				return {}
			entry = {
				"kind": "damage",
				"icon_key": _build_imminent_spell_preview_icon_key("damage", target_scope),
				"value": damage_value,
				"target_scope": target_scope,
				"target_index": target_index
			}
		else:
			if bool(effect.get("overflow_to_shield", false)):
				entry = {
					"kind": "heal",
					"icon_key": "heal_overflow_shield",
					"value": value,
					"target_scope": "special",
					"target_index": target_index
				}
			else:
				entry = {
					"kind": "heal",
					"icon_key": _build_imminent_spell_preview_icon_key("heal", target_scope),
					"value": value,
					"target_scope": target_scope,
					"target_index": target_index
				}
	elif effect_type == EffectType.SHIELD_CHANGE:
		var shield_value := _resolve_shield_change_value(effect, read_targets)
		if shield_value <= 0:
			return {}
		entry = {
			"kind": "shield",
			"icon_key": _build_imminent_spell_preview_icon_key("shield", target_scope),
			"value": shield_value,
			"target_scope": target_scope,
			"target_index": target_index
		}
	return entry

func _resolve_imminent_spell_preview_target_scope(target_block: Dictionary) -> String:
	if typeof(target_block) != TYPE_DICTIONARY:
		return "single"
	var condition = target_block.get("condition", {})
	if typeof(condition) != TYPE_DICTIONARY:
		return "single"
	if bool(condition.get("self", false)):
		return "self"
	var selector := str(condition.get("selector", condition.get("selecter", "")))
	match selector:
		"front_enemy", "front_ally":
			return "front"
		"back_enemy", "back_ally":
			return "back"
		_:
			pass
	var target_type := int(target_block.get("type", TargetType.CHARACTER))
	var target_team := int(target_block.get("team", -1))
	var target_index := int(target_block.get("index", -1))
	if condition.is_empty() and target_type == TargetType.CHARACTER and target_index == 0 and (target_team == TargetTeam.ALLY or target_team == TargetTeam.ENEMY):
		return "all"
	return "single"

func _build_imminent_spell_preview_icon_key(kind: String, target_scope: String) -> String:
	return "%s_%s" % [kind, target_scope]

func trigger_global_tick() -> void:
	current_battle_stats["total_ticks"] = int(current_battle_stats.get("total_ticks", 0)) + 1
	var tick_context = {
		"phase": StatusTickPhase.GLOBAL_TICK,
		"sequence_id": _runtime_sequence_id
	}
	_tick_all_statuses(tick_context)
	await wait_health_queue_flushed()
	_tick_timed_escape_enemies()
	if battle_result != "":
		return
	var pending_actions: Array = []
	var frien_face_owner = _get_face_up_player_id()
	for char_name in player_data.player_characters.keys():
		var char_state = player_data.player_characters[char_name]
		if int(char_state.get("current_health", 0)) <= 0:
			continue
		var old_countdown = int(char_state.get("countdown", 0))
		char_state["countdown"] = max(old_countdown - 1, 0)
		emit_signal("character_countdown_changed", char_name, int(char_state.get("countdown", 0)))
		print("[BattleManager] Tick: ", char_name, " countdown=", char_state.countdown)
		if old_countdown > 0 and int(char_state.get("countdown", 0)) <= 0:
			countdown_zero_context[char_name] = {
				"dice_type": _last_roll_context.get("dice_type", ""),
				"face_up": _last_roll_context.get("face_up", -1),
				"frien_face_owner": frien_face_owner,
				"sequence_id": _runtime_sequence_id
			}
			pending_actions.append({"char_id": char_name, "is_enemy": false})
	
	for enemy_id in enemy_data.enemy_fiends.keys():
		var enemy_state = enemy_data.enemy_fiends[enemy_id]
		if int(enemy_state.get("current_health", 0)) <= 0:
			continue
		var old_enemy_countdown = int(enemy_state.get("countdown", 0))
		enemy_state["countdown"] = max(old_enemy_countdown - 1, 0)
		emit_signal("character_countdown_changed", enemy_id, int(enemy_state.get("countdown", 0)))
		var new_enemy_countdown = int(enemy_state.get("countdown", 0))
		if new_enemy_countdown != old_enemy_countdown:
			_trigger_enemy_trait_event("enemy_countdown_changed", {
				"actor_id": enemy_id,
				"old_countdown": old_enemy_countdown,
				"new_countdown": new_enemy_countdown,
				"cause": "tick"
			})
		if new_enemy_countdown < old_enemy_countdown:
			_trigger_enemy_trait_event("enemy_countdown_reduced", {
				"actor_id": enemy_id,
				"old_countdown": old_enemy_countdown,
				"new_countdown": new_enemy_countdown,
				"cause": "tick"
			})
		print("[BattleManager] Tick: ", enemy_id, " countdown=", enemy_state.countdown)
		if old_enemy_countdown > 0 and new_enemy_countdown <= 0:
			countdown_zero_context[enemy_id] = {
				"dice_type": _last_roll_context.get("dice_type", ""),
				"face_up": _last_roll_context.get("face_up", -1),
				"frien_face_owner": frien_face_owner,
				"sequence_id": _runtime_sequence_id
			}
			_trigger_enemy_trait_event("enemy_countdown_zero", {
				"actor_id": enemy_id,
				"old_countdown": old_enemy_countdown,
				"new_countdown": new_enemy_countdown
			})
			pending_actions.append({"char_id": enemy_id, "is_enemy": true})

	var player_equipment_id := get_face_up_equipment_owner_id(false)
	if player_equipment_id != "":
		trigger_equipment_trait_event(player_equipment_id, "equipment_countdown_tick", {
			"sequence_id": _runtime_sequence_id,
			"equipment_is_enemy": false
		})
	var enemy_equipment_id := get_face_up_equipment_owner_id(true)
	if enemy_equipment_id != "":
		trigger_equipment_trait_event(enemy_equipment_id, "equipment_countdown_tick", {
			"sequence_id": _runtime_sequence_id,
			"equipment_is_enemy": true
		})
	
	if not pending_actions.is_empty():
		pending_actions.sort_custom(Callable(self, "_tick_action_sorter"))
		for action in pending_actions:
			await _execute_character_action(action.char_id, action.is_enemy)


func _execute_character_action(char_id: String, is_enemy: bool) -> void:
	var char_state = enemy_data.enemy_fiends.get(char_id) if is_enemy else player_data.player_characters.get(char_id)
	if char_state == null:
		return
	var after_action_status_snapshot = _capture_after_action_status_snapshot(char_state.get("status_effects", {}))
	var had_escape_status_before_action := false
	var escape_status_id_before_action := ""
	if is_enemy:
		var timed_escape_state = char_state.get("timed_escape_state", {})
		if typeof(timed_escape_state) == TYPE_DICTIONARY and not timed_escape_state.is_empty():
			escape_status_id_before_action = str(timed_escape_state.get("escape_status_id", ""))
			if escape_status_id_before_action != "":
				had_escape_status_before_action = has_character_status(char_id, escape_status_id_before_action, "")
	if _has_crowd_control_flag(StatusTarget.CHARACTER, char_id, "skip_action") or _status_map_has_crowd_control_flag(char_state.get("status_effects", {}), "skip_action"):
		print("[BattleManager] Tick action skipped by crowd control: ", char_id)
		char_state["countdown"] = int(char_state.get("base_countdown", 5))
		emit_signal("character_countdown_changed", char_id, int(char_state.get("countdown", 0)))
		countdown_zero_context.erase(char_id)
		return

	var countdown_ctx = countdown_zero_context.get(char_id, {})
	var countdown_signal_ctx = {
		"actor_id": char_id,
		"is_enemy": is_enemy
	}
	emit_signal("on_countdown_before", countdown_signal_ctx)
	_trigger_trait_event("ambush", countdown_signal_ctx)
	if is_enemy:
		_trigger_enemy_trait_event("enemy_action_before", countdown_signal_ctx)

	if not is_enemy:
		var self_action_ctx = {
			"actor_id": char_id
		}
		emit_signal("on_self_action_before", self_action_ctx)
		_trigger_trait_event("rally", self_action_ctx)
		var current_equipment_id = get_face_up_equipment_owner_id(false)
		if current_equipment_id != "":
			trigger_equipment_trait_event(current_equipment_id, "ally_action_before", self_action_ctx)
			await wait_health_queue_flushed()

		if typeof(countdown_ctx) == TYPE_DICTIONARY and str(countdown_ctx.get("frien_face_owner", "")) == char_id:
			var chosen_ctx = {
				"actor_id": char_id,
				"countdown_context": countdown_ctx
			}
			emit_signal("on_self_perform", chosen_ctx)
			_trigger_trait_event("chosen", chosen_ctx)

	countdown_zero_context.erase(char_id)

	char_state["countdown"] = int(char_state.get("base_countdown", 5))
	emit_signal("character_countdown_changed", char_id, int(char_state.get("countdown", 0)))
	var deferred_countdown_delta = _consume_deferred_countdown_delta(char_id)
	if deferred_countdown_delta != 0:
		modify_character_countdown(char_id, deferred_countdown_delta)
	var slot_index = _get_character_slot_index(char_id, is_enemy)
	var equip_info = _get_equipment_face_up(is_enemy)
	var hex_info = _get_hex_face_up(is_enemy)
	var equip_name = "None"
	if equip_info.face_data:
		if typeof(equip_info.face_data) == TYPE_OBJECT and "equipment_name" in equip_info.face_data:
			equip_name = equip_info.face_data.equipment_name
		elif typeof(equip_info.face_data) == TYPE_DICTIONARY and equip_info.face_data.has("equipment_name"):
			equip_name = equip_info.face_data.equipment_name
	var hex_name = "None"
	var hex_data = hex_info.hex_data
	if hex_data and hex_data.hex_name != "":
		hex_name = hex_data.hex_name
	print("[BattleManager] TICK ACTION: [", "Enemy" if is_enemy else "Player", "] ", char_id, " (Slot ", slot_index, ") acts! FaceUp Equipment: ", equip_name, ", FaceUp Hex: ", hex_name)
	var skip_swift_hex = false
	if hex_data and hex_data.hex_name != "":
		skip_swift_hex = _should_skip_swift_hex_action(char_id, str(hex_data.id), countdown_ctx)

	var current_equipment_stats = get_current_equipment_stats(is_enemy)
	_forced_equipment_context = {
		"dice_type": equip_info.dice_type,
		"face_index": equip_info.face_index,
		"face_data": equip_info.face_data,
		"stats": current_equipment_stats
	}
	
	if hex_data and hex_data.hex_name != "" and not skip_swift_hex:
		if is_enemy:
			await cast_enemy_hex(hex_data, char_id, DiceFace.UP)
		else:
			var caster_ref = {"character_name": char_id, "name": char_id}
			await cast_hex(hex_data, caster_ref, DiceFace.UP)
	if not is_enemy:
		var post_action_equipment_id = get_face_up_equipment_owner_id(false)
		if post_action_equipment_id != "":
			trigger_equipment_trait_event(post_action_equipment_id, "ally_action_after", {"actor_id": char_id})
	else:
		_trigger_enemy_trait_event("enemy_action_after", {
			"actor_id": char_id,
			"is_enemy": true
		})
	_tick_after_action_statuses_for_character(char_id, is_enemy, after_action_status_snapshot)
	if is_enemy and had_escape_status_before_action and battle_result == "":
		if not enemy_data.enemy_fiends.has(char_id):
			return
		var enemy_state_after = enemy_data.enemy_fiends[char_id]
		var timed_escape_state_after = enemy_state_after.get("timed_escape_state", {})
		if typeof(timed_escape_state_after) == TYPE_DICTIONARY and not timed_escape_state_after.is_empty():
			var countdown_mode = str(timed_escape_state_after.get("countdown_mode", TIMED_ESCAPE_MODE_TICK))
			if countdown_mode == TIMED_ESCAPE_MODE_ACTION_STATUS and escape_status_id_before_action != "":
				if not has_character_status(char_id, escape_status_id_before_action, ""):
					_attempt_timed_escape(char_id)

	_forced_equipment_context = {}

func update_dice_result(dice_type:String, face_up_value:int, trigger_runtime_events: bool = true) -> void:
	var previous_equipment_id = ""
	var is_enemy_equipment_roll := false
	if trigger_runtime_events and (dice_type == "equipment" or dice_type == "enemy_equipment"):
		is_enemy_equipment_roll = dice_type == "enemy_equipment"
		previous_equipment_id = get_face_up_equipment_owner_id(is_enemy_equipment_roll)
	var new_bottom_value = 5 - face_up_value
	var result_found = false
	for result in dice_results:
		if result.dice_type == dice_type:
			result.face_up_value = face_up_value
			result.face_down_value = new_bottom_value
			dice_result = result # Update current reference
			result_found = true
			print("[BattleManager] Updated existing result for ", dice_type, ": ", face_up_value)
			break
	
	if not result_found:
		var result = DiceResult.new()
		result.dice_type = dice_type
		result.face_up_value = face_up_value
		result.face_down_value = new_bottom_value
		dice_result = result
		dice_results.append(result)
		rolled_dice.append(dice_type)
		print(dice_type, " dice rolled (new)")
		print("last rolled dice: ", dice_type, " dice result: ", dice_result.face_up_value)
	
	_last_face_up[dice_type] = face_up_value
	_last_face_down[dice_type] = new_bottom_value
	_last_roll_context = {
		"dice_type": dice_type,
		"face_up": face_up_value
	}

	if not trigger_runtime_events:
		return

	_consume_forced_roll_expose(dice_type, face_up_value)
	_consume_roll_exclusion_stealth(dice_type)

	_runtime_sequence_id += 1

	if dice_type == "frien" or dice_type == "enemy_frien":
		var promoted_layout := promote_front_unit(dice_type, face_up_value)
		if not promoted_layout.is_empty():
			await animate_battle_layout_transition(
				promoted_layout,
				_get_battle_layout_duration(FRONT_UNIT_MOVE_DURATION),
				_get_battle_layout_gap(BATTLE_LAYOUT_TRANSITION_GAP)
			)

	var rolled_ctx = {
		"dice_type": dice_type,
		"face_up": face_up_value
	}
	emit_signal("on_tick_after", rolled_ctx)
	_trigger_trait_event("rolled", rolled_ctx)

	if dice_type == "frien":
		var frien_ctx = {
			"dice_type": dice_type,
			"face_up": face_up_value
		}
		emit_signal("on_frien_roll_after", frien_ctx)
		_trigger_trait_event("reinforce", frien_ctx)
		var shown_character = _get_face_up_player_id()
		if shown_character != "":
			var deploy_ctx = {
				"actor_id": shown_character,
				"dice_type": dice_type,
				"face_up": face_up_value
			}
			emit_signal("on_self_show", deploy_ctx)
			_trigger_trait_event("deploy", deploy_ctx)
	elif dice_type == "equipment":
		var current_equipment_id = get_face_up_equipment_owner_id(false)
		if previous_equipment_id != "" and previous_equipment_id != current_equipment_id:
			trigger_equipment_trait_event(previous_equipment_id, "equipment_face_up_lost", {
				"previous_equipment_id": previous_equipment_id,
				"current_equipment_id": current_equipment_id
			})
		if current_equipment_id != "":
			trigger_equipment_trait_event(current_equipment_id, "equipment_face_up", {
				"equipment_id": current_equipment_id,
				"face_up": face_up_value
			})
	elif dice_type == "enemy_equipment":
		var current_enemy_equipment_id = get_face_up_equipment_owner_id(true)
		if previous_equipment_id != "" and previous_equipment_id != current_enemy_equipment_id:
			trigger_equipment_trait_event(previous_equipment_id, "equipment_face_up_lost", {
				"previous_equipment_id": previous_equipment_id,
				"current_equipment_id": current_enemy_equipment_id,
				"equipment_is_enemy": true
			})
		if current_enemy_equipment_id != "":
			trigger_equipment_trait_event(current_enemy_equipment_id, "equipment_face_up", {
				"equipment_id": current_enemy_equipment_id,
				"face_up": face_up_value,
				"equipment_is_enemy": true
			})
	elif dice_type == "hex2" or dice_type == "enemy_hex2":
		await _try_trigger_swift_hex_on_roll(dice_type, face_up_value)
	
	await trigger_global_tick()

func get_certain_dice_result(dice_type:String):
	var face_up_index: int = -1
	for dice_face_result in dice_results:
		if dice_face_result.dice_type == dice_type:
			face_up_index = dice_face_result.face_up_value
			return face_up_index
	return -1

func _get_face_up_player_id() -> String:
	var face_index = get_certain_dice_result("frien")
	if face_index < 0:
		var dice_node = _get_dice_node_by_type("frien")
		if dice_node:
			face_index = int(dice_node.current_face_index)
	return _resolve_face_up_character_id("frien", face_index)

func _get_front_player_id() -> String:
	return _get_front_unit_id("frien")

func _get_front_enemy_id() -> String:
	return _get_front_unit_id("enemy")

func _get_back_player_id() -> String:
	return _get_back_unit_id("frien")

func _get_back_enemy_id() -> String:
	return _get_back_unit_id("enemy")

func _get_front_unit_id(group_name: String) -> String:
	_sync_team_display_order(group_name)
	var order := _get_team_display_order(group_name)
	if order.is_empty():
		return ""
	if group_name == "enemy":
		for unit_id in order:
			var candidate := str(unit_id)
			if enemy_data.enemy_fiends.has(candidate):
				return candidate
	else:
		for i in range(order.size() - 1, -1, -1):
			var candidate := str(order[i])
			if player_data.player_characters.has(candidate):
				return candidate
	return ""

func _get_back_unit_id(group_name: String) -> String:
	_sync_team_display_order(group_name)
	var order := _get_team_display_order(group_name)
	if order.is_empty():
		return ""
	if group_name == "enemy":
		for i in range(order.size() - 1, -1, -1):
			var candidate := str(order[i])
			if enemy_data.enemy_fiends.has(candidate):
				return candidate
	else:
		for unit_id in order:
			var candidate := str(unit_id)
			if player_data.player_characters.has(candidate):
				return candidate
	return ""

func _get_ordered_alive_team_ids(is_enemy_team: bool) -> Array[String]:
	var group_name := "enemy" if is_enemy_team else "frien"
	var state_map: Dictionary = enemy_data.enemy_fiends if is_enemy_team else player_data.player_characters
	_sync_team_display_order(group_name)
	var ordered_ids: Array[String] = []
	for raw_unit_id in _get_team_display_order(group_name):
		var unit_id := str(raw_unit_id)
		if unit_id == "" or not state_map.has(unit_id):
			continue
		if int(state_map[unit_id].get("current_health", 0)) <= 0:
			continue
		ordered_ids.append(unit_id)
	return ordered_ids

func _resolve_rank_target_ids(is_enemy_team: bool, prefer_front: bool) -> Array[String]:
	var ordered_ids := _get_ordered_alive_team_ids(is_enemy_team)
	if ordered_ids.is_empty():
		return _empty_string_array()
	if prefer_front:
		var front_id := _get_front_enemy_id() if is_enemy_team else _get_front_player_id()
		if front_id != "" and ordered_ids.has(front_id):
			var front_result: Array[String] = []
			front_result.append(front_id)
			return front_result
		return _empty_string_array()
	var back_id := _get_back_enemy_id() if is_enemy_team else _get_back_player_id()
	if back_id != "" and ordered_ids.has(back_id):
		var back_result: Array[String] = []
		back_result.append(back_id)
		return back_result
	return _empty_string_array()

func _resolve_health_extreme_target_ids(is_enemy_team: bool, find_highest: bool) -> Array[String]:
	var ordered_ids := _get_ordered_alive_team_ids(is_enemy_team)
	if ordered_ids.is_empty():
		return _empty_string_array()
	var state_map: Dictionary = enemy_data.enemy_fiends if is_enemy_team else player_data.player_characters
	var best_health: int = -1
	var results: Array[String] = []
	for unit_id in ordered_ids:
		var current_health := int(state_map[unit_id].get("current_health", 0))
		if best_health == -1:
			best_health = current_health
			results.clear()
			results.append(unit_id)
			continue
		if find_highest:
			if current_health > best_health:
				best_health = current_health
				results.clear()
				results.append(unit_id)
			elif current_health == best_health:
				results.append(unit_id)
		else:
			if current_health < best_health:
				best_health = current_health
				results.clear()
				results.append(unit_id)
			elif current_health == best_health:
				results.append(unit_id)
	return results

func _resolve_status_target_ids(is_enemy_team: bool, status_id: String) -> Array[String]:
	if status_id == "":
		return _empty_string_array()
	var ordered_ids := _get_ordered_alive_team_ids(is_enemy_team)
	if ordered_ids.is_empty():
		return _empty_string_array()
	var results: Array[String] = []
	for unit_id in ordered_ids:
		if has_status_on_target({"name": unit_id}, status_id, ""):
			results.append(unit_id)
	return results

func _resolve_face_up_character_id(dice_type: String, face_index: int) -> String:
	var resolved_id = EmbeddedDiceFaces.resolve_face_up_character_id(dice_type, face_index)
	if resolved_id == "":
		return ""
	if dice_type == "frien" and player_data.player_characters.has(resolved_id):
		return resolved_id
	if dice_type == "enemy_frien" and enemy_data.enemy_fiends.has(resolved_id):
		return resolved_id
	return ""

func _resolve_current_source_id() -> String:
	if current_caster == null:
		return ""
	if typeof(current_caster) == TYPE_DICTIONARY:
		var candidate = str(current_caster.get("unique_id", current_caster.get("name", current_caster.get("character_name", current_caster.get("enemy_name", "")))))
		if player_data.player_characters.has(candidate):
			return candidate
		if enemy_data.enemy_fiends.has(candidate):
			return candidate
	elif typeof(current_caster) == TYPE_OBJECT:
		if "unique_id" in current_caster:
			var candidate_unique = str(current_caster.unique_id)
			if player_data.player_characters.has(candidate_unique):
				return candidate_unique
			if enemy_data.enemy_fiends.has(candidate_unique):
				return candidate_unique
		if "character_name" in current_caster:
			var candidate_obj = str(current_caster.character_name)
			if player_data.player_characters.has(candidate_obj):
				return candidate_obj
			if enemy_data.enemy_fiends.has(candidate_obj):
				return candidate_obj
		if "enemy_name" in current_caster:
			var candidate_enemy = str(current_caster.enemy_name)
			if player_data.player_characters.has(candidate_enemy):
				return candidate_enemy
			if enemy_data.enemy_fiends.has(candidate_enemy):
				return candidate_enemy
		if "name" in current_caster:
			var candidate_name = str(current_caster.name)
			if player_data.player_characters.has(candidate_name):
				return candidate_name
			if enemy_data.enemy_fiends.has(candidate_name):
				return candidate_name
	return ""

func _trigger_trait_event(event_name: String, context: Dictionary = {}) -> void:
	if not TraitManager:
		return
	TraitManager.process_event(event_name, context)

func _trigger_enemy_trait_event(event_name: String, context: Dictionary = {}) -> void:
	if not TraitManager:
		return
	TraitManager.process_enemy_event(event_name, context)

func _resolve_enemy_dice_texture(enemy_name: String, fallback_texture_path: String) -> String:
	var candidates: Array = []
	if enemy_name != "":
		candidates.append("res://Assets/dice-" + enemy_name + ".png")
		candidates.append("res://Assets/dice-" + enemy_name.replace(" ", "-") + ".png")
	if fallback_texture_path != "" and fallback_texture_path.find("enemy-") != -1:
		candidates.append(fallback_texture_path.replace("enemy-", "dice-"))
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return fallback_texture_path

func _resolve_player_portrait_texture(character_id: String, character_name: String, fallback_texture_path: String = "") -> String:
	var candidates: Array = []
	var resolved_character_id := character_id
	if resolved_character_id == "" and character_name != "":
		resolved_character_id = GameDataManager.get_character_id_by_name(character_name)
	if resolved_character_id != "":
		var char_data := GameDataManager.get_character_data(resolved_character_id)
		var legacy_name := str(char_data.get("legacy_name", ""))
		if legacy_name != "":
			candidates.append("res://Assets/char-" + legacy_name + ".png")
	if fallback_texture_path != "" and fallback_texture_path.find("dice-") != -1:
		candidates.append(fallback_texture_path.replace("dice-", "char-"))
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return "res://Assets/blank-dice.png"

func _resolve_enemy_portrait_texture(enemy_id: String, enemy_name: String, fallback_texture_path: String = "") -> String:
	var candidates: Array = []
	var resolved_enemy_id := enemy_id
	if resolved_enemy_id == "" and enemy_name != "":
		for candidate_id in GameDataManager.enemies.keys():
			var enemy_data := GameDataManager.get_enemy_data(str(candidate_id))
			if str(enemy_data.get("legacy_name", enemy_data.get("enemy_name", ""))) == enemy_name:
				resolved_enemy_id = str(candidate_id)
				break
	if resolved_enemy_id != "":
		var canonical_enemy := GameDataManager.get_enemy_data(resolved_enemy_id)
		var legacy_name := str(canonical_enemy.get("legacy_name", ""))
		if legacy_name != "":
			candidates.append("res://Assets/enemy-" + legacy_name + ".png")
	if fallback_texture_path != "" and fallback_texture_path.find("dice-") != -1:
		candidates.append(fallback_texture_path.replace("dice-", "enemy-"))
	if fallback_texture_path != "" and fallback_texture_path.find("enemy-") != -1:
		candidates.append(fallback_texture_path)
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return "res://Assets/blank-dice.png"

func is_dice_roll_disabled(dice_type: String) -> bool:
	if dice_statuses.has(dice_type) and _status_map_has_crowd_control_flag(dice_statuses[dice_type], "disable_roll"):
		return true
	var up_face = get_certain_dice_result(dice_type)
	if up_face < 0:
		return false
	if face_statuses.has(dice_type) and face_statuses[dice_type].has(up_face):
		if _status_map_has_crowd_control_flag(face_statuses[dice_type][up_face], "disable_roll"):
			return true
	if _has_crowd_control_flag(StatusTarget.DICE, dice_type, "disable_roll"):
		return true
	if _has_crowd_control_flag(StatusTarget.DICE_FACE, {"dice_type": dice_type, "face_index": up_face}, "disable_roll"):
		return true
	return false

func is_dice_flip_disabled(dice_type: String) -> bool:
	if dice_statuses.has(dice_type) and _status_map_has_crowd_control_flag(dice_statuses[dice_type], "disable_flip"):
		return true
	var up_face = get_certain_dice_result(dice_type)
	if up_face < 0:
		return false
	if face_statuses.has(dice_type) and face_statuses[dice_type].has(up_face):
		if _status_map_has_crowd_control_flag(face_statuses[dice_type][up_face], "disable_flip"):
			return true
	if _has_crowd_control_flag(StatusTarget.DICE, dice_type, "disable_flip"):
		return true
	if _has_crowd_control_flag(StatusTarget.DICE_FACE, {"dice_type": dice_type, "face_index": up_face}, "disable_flip"):
		return true
	return false


func _get_dice_node_by_type(dice_type: String):
	var dice_nodes = get_tree().get_nodes_in_group("dice")
	for dice in dice_nodes:
		var node_type = dice.get("dice_type")
		if node_type == dice_type:
			return dice
	return null

func reroll_single_dice(dice_node) -> void:
	var dice_type = dice_node.dice_type
	print("[BattleManager] Rerolling dice: ", dice_type)
	
	dice_node.play_rotate_animation()
	await dice_node.anim_sprite.animation_finished
	
	var new_face_value = dice_node.current_face_index
	update_dice_result(dice_type, new_face_value)

func check_hex_triggers(caster) -> void:
	# Iterate all hex faces; trigger only when effect exists for that face direction.
	for face_index in [0,1,2,3,4,5]:
		var hex_data = EmbeddedDiceFaces.hex_dice_faces[face_index]
		if not hex_data or hex_data.hex_name.is_empty():
			continue
		
		var use_effect_conditions = _has_any_effect_cast_condition(hex_data)
		var up_face = get_certain_dice_result("hex2")
		if face_index == up_face:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.UP)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.UP):
				print("cast hex faced up: ", hex_data)
				await cast_hex(hex_data, caster, DiceFace.UP)
		elif face_index == dice_result.face_down_value:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.DOWN)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.DOWN):
				await cast_hex(hex_data, caster, DiceFace.DOWN)
		else:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.SIDE)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.SIDE):
				await cast_hex(hex_data, caster, DiceFace.SIDE)

# BattleManager reset helpers
func reset_battle_state() -> void:
	is_test_mode = false
	is_simulation_mode = false
	simulation_fast_mode = false
	is_tutorial_battle = false
	battle_result = ""
	_battle_end_scene_transition_requested = false
	rolled_dice.clear()
	dice_results.clear()
	_roll_bias_state.clear()
	dice_statuses.clear()
	face_statuses.clear()
	equipment_trait_states.clear()
	_tick_control_flags.clear()
	_last_face_up.clear()
	_last_face_down.clear()
	_pending_enemy_action_damage_negated = false
	current_caster = null
	last_target = null
	_current_spell_context = {}
	countdown_zero_context.clear()
	_last_roll_context.clear()
	_swift_hex_skip_context.clear()
	_ally_display_order.clear()
	_enemy_display_order.clear()
	simulation_context = {}
	current_battle_stats = {}
	last_battle_summary = {}
	reset_special_battle_state()
	player_data = PlayerData.new()
	enemy_data = EnemyTeam.new()

func reset_special_battle_state() -> void:
	_special_battle_state = {
		"escape_available": false,
		"escape_source_enemy_id": "",
		"escape_triggered_enemy_ids": {}
	}
	emit_signal("battle_escape_state_changed", false, "")

func get_special_battle_state_dict() -> Dictionary:
	return {
		"escape_available": bool(_special_battle_state.get("escape_available", false)),
		"escape_source_enemy_id": str(_special_battle_state.get("escape_source_enemy_id", "")),
		"escape_triggered_enemy_ids": _special_battle_state.get("escape_triggered_enemy_ids", {}).duplicate(true)
	}

func restore_special_battle_state(state: Dictionary) -> void:
	reset_special_battle_state()
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return
	_special_battle_state["escape_available"] = bool(state.get("escape_available", false))
	_special_battle_state["escape_source_enemy_id"] = str(state.get("escape_source_enemy_id", ""))
	var triggered_raw = state.get("escape_triggered_enemy_ids", {})
	if typeof(triggered_raw) == TYPE_ARRAY:
		var triggered_map := {}
		for raw_enemy_id in triggered_raw:
			var enemy_id = str(raw_enemy_id)
			if enemy_id != "":
				triggered_map[enemy_id] = true
		_special_battle_state["escape_triggered_enemy_ids"] = triggered_map
	elif typeof(triggered_raw) == TYPE_DICTIONARY:
		_special_battle_state["escape_triggered_enemy_ids"] = triggered_raw.duplicate(true)
	emit_signal(
		"battle_escape_state_changed",
		bool(_special_battle_state.get("escape_available", false)),
		str(_special_battle_state.get("escape_source_enemy_id", ""))
	)

func enable_battle_escape_for_enemy(enemy_id: String) -> void:
	if enemy_id == "":
		return
	var triggered: Dictionary = _special_battle_state.get("escape_triggered_enemy_ids", {})
	if triggered.has(enemy_id):
		return
	triggered[enemy_id] = true
	_special_battle_state["escape_triggered_enemy_ids"] = triggered
	if not bool(_special_battle_state.get("escape_available", false)):
		_special_battle_state["escape_available"] = true
		_special_battle_state["escape_source_enemy_id"] = enemy_id
	emit_signal(
		"battle_escape_state_changed",
		bool(_special_battle_state.get("escape_available", false)),
		str(_special_battle_state.get("escape_source_enemy_id", ""))
	)

func has_battle_escape_triggered_for_enemy(enemy_id: String) -> bool:
	if enemy_id == "":
		return false
	return _special_battle_state.get("escape_triggered_enemy_ids", {}).has(enemy_id)

func is_battle_escape_available() -> bool:
	return bool(_special_battle_state.get("escape_available", false))

func get_battle_escape_source_enemy_id() -> String:
	return str(_special_battle_state.get("escape_source_enemy_id", ""))

func perform_emergency_escape() -> bool:
	if not is_battle_escape_available():
		return false
	if battle_result != "":
		return false
	if is_test_mode:
		print("[BattleManager] Emergency escape is disabled in test mode")
		return false
	_sync_player_health_to_run()
	GameManager.save_game()
	GameManager.save_current_scene_state()
	var current_room = MapStateManager.get_current_room()
	MapStateManager.mark_room_as_explored(current_room)
	MapStateManager.set_room_battle_state(current_room, GameManager.current_scene_state.duplicate(true))
	get_tree().change_scene_to_file("res://Scenes/map_scene.tscn")
	return true

# Sync current player health back to run data
func _sync_player_health_to_run() -> void:
	if is_test_mode:
		return
	if not GameManager.current_run:
		return

	for char_name in player_data.player_characters.keys():
		var state = player_data.player_characters[char_name]
		GameManager.current_run.character_current_health[char_name] = state.current_health

	# If the whole team is down, mark dice-face characters as 0 HP
	if _is_team_defeated(player_data.player_characters):
		for face in EmbeddedDiceFaces.frien_dice_faces.values():
			if face.character_name != "":
				if not GameManager.current_run.character_current_health.has(face.character_name):
					GameManager.current_run.character_current_health[face.character_name] = 0


func _sync_single_player_health_to_run(character_id: String, current_health: int) -> void:
	if is_test_mode:
		return
	if not GameManager.current_run:
		return
	GameManager.current_run.character_current_health[character_id] = max(current_health, 0)

# Check whether battle ended
func check_battle_end():
	var player_defeated = _is_team_defeated(player_data.player_characters)
	var enemy_defeated = _is_team_defeated(enemy_data.enemy_fiends)
	
	if (player_defeated or enemy_defeated) and not is_test_mode and not is_tutorial_battle:
		_sync_player_health_to_run()
		MapStateManager.clear_room_battle_state(MapStateManager.get_current_room())
	
	if player_defeated:
		#GameManager.end_current_game(false)
		battle_result = "defeat"
		if not is_test_mode and not is_tutorial_battle:
			GameManager.save_game()
	elif enemy_defeated:
		battle_result = "victory"  
		if not is_test_mode and not is_tutorial_battle:
			GameManager.save_game()
		emit_signal("battle_won")
	if battle_result != "":
		last_battle_summary = _build_battle_summary()

func _finalize_battle_end_if_needed() -> void:
	check_battle_end()
	if battle_result == "":
		return
	if _battle_end_scene_transition_requested:
		return
	_battle_end_scene_transition_requested = true
	var victory := battle_result == "victory"
	last_battle_summary = _build_battle_summary()
	emit_signal("battle_ended", victory)
	if is_simulation_mode:
		emit_signal("battle_simulation_completed", last_battle_summary.duplicate(true))
		return
	get_tree().change_scene_to_file("res://Scenes/battle_result.tscn")



func _is_team_defeated(team: Dictionary) -> bool:
	if team.is_empty():
		return true

	
	for character in team.values():
		if character.current_health > 0:
			return false  
	
	return true 

func check_enemy_hex_triggers(caster_name: String) -> void:
	# Iterate all hex faces; trigger only when effect exists for that face direction.
	for face_index in [0,1,2,3,4,5]:
		var hex_data = EmbeddedDiceFaces.enemy_hex_dice_faces[face_index]
		if not hex_data or hex_data.hex_name.is_empty():
			continue
		
		var use_effect_conditions = _has_any_effect_cast_condition(hex_data)
		var up_face = get_certain_dice_result("enemy_hex2")
		if face_index == up_face:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.UP)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.UP):
				print("enemy cast hex faced up: ", hex_data)
				await cast_enemy_hex(hex_data, caster_name, DiceFace.UP)
		elif face_index == dice_result.face_down_value:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.DOWN)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.DOWN):
				await cast_enemy_hex(hex_data, caster_name, DiceFace.DOWN)
		else:
			if (use_effect_conditions and _has_effect_for_cast_condition(hex_data, DiceFace.SIDE)) or \
			(not use_effect_conditions and hex_data.cast_condition == DiceFace.SIDE):
				await cast_enemy_hex(hex_data, caster_name, DiceFace.SIDE)

func _has_any_effect_cast_condition(hex_data: HexData) -> bool:
	if not hex_data:
		return false
	for effect in hex_data.effect_data:
		if effect.has("cast_condition"):
			return true
	return false

func _has_effect_for_cast_condition(hex_data: HexData, cast_condition: int) -> bool:
	if not hex_data:
		return false
	for effect in hex_data.effect_data:
		if not effect.has("cast_condition"):
			continue
		if int(effect.cast_condition) == cast_condition:
			return true
	return false

func cast_enemy_hex(hex_data: HexData, unique_id: String, trigger_face: int = DiceFace.UP) -> void:
	var skip_health_wait := _should_skip_spell_resolution_health_wait(hex_data)
	
	print("Checking caster status for: ", unique_id)
	if not enemy_data.enemy_fiends.has(unique_id):
		print("[BattleManager] Enemy caster is dead or invalid, cancelling hex cast")
		check_battle_end()
		return

	
	var caster = enemy_data.enemy_fiends[unique_id]

	print("[BattleManager] Enemy Cast hex called with data:", JSON.stringify({
		"hex_name": hex_data.hex_name,
		"effect_data": hex_data.effect_data,
		"target_data": hex_data.target_data
	}))
	current_caster = caster
	last_target = null
	_begin_spell_resolution(unique_id, true, hex_data)
	var targets = get_all_enemy_targets(hex_data)
	print("[BattleManager] Got enemy targets:", targets)
	_emit_spell_visual_request(hex_data, unique_id, targets, true)
	await apply_all_effects(hex_data, targets, trigger_face)
	if not skip_health_wait:
		await wait_health_queue_flushed()
		await get_tree().process_frame
		await wait_health_queue_flushed()
	_trigger_hex_trait_event(hex_data, "spell_cast_after", trigger_face, true)
	_finish_enemy_spell_resolution()
	if not skip_health_wait:
		await wait_health_queue_flushed()

func _should_skip_spell_resolution_health_wait(hex_data: HexData) -> bool:
	if hex_data == null:
		return false
	if simulation_fast_mode:
		return false
	var spell_id := str(hex_data.id)
	return GameDataManager.get_hex_visual_total_duration(spell_id) > HEALTH_QUEUE_INTERVAL

func _get_spell_visual_health_delay(spell_id: String) -> float:
	return GameDataManager.get_hex_visual_total_duration(spell_id)

func _emit_spell_visual_request(hex_data: HexData, caster_id: String, targets: Dictionary, is_enemy_cast: bool) -> void:
	if hex_data == null:
		return
	if simulation_fast_mode:
		return
	var spell_id := str(hex_data.id)
	if GameDataManager.get_hex_animation_entries(spell_id).is_empty():
		return
	var target_ids := _collect_spell_visual_target_ids(targets)
	if target_ids.is_empty():
		return
	emit_signal("spell_visual_requested", {
		"hex_id": spell_id,
		"caster_id": caster_id,
		"target_ids": target_ids,
		"is_enemy_cast": is_enemy_cast,
		"mirror_x": is_enemy_cast
	})

func _collect_spell_visual_target_ids(targets: Dictionary) -> Array:
	var target_ids: Array = []
	var seen: Dictionary = {}
	for raw_target_group in targets.values():
		if typeof(raw_target_group) != TYPE_ARRAY:
			continue
		for raw_target in raw_target_group:
			var target_id := _resolve_runtime_entity_id(raw_target)
			if target_id == "":
				continue
			if not player_data.player_characters.has(target_id) and not enemy_data.enemy_fiends.has(target_id):
				continue
			if seen.has(target_id):
				continue
			seen[target_id] = true
			target_ids.append(target_id)
	return target_ids

func get_all_enemy_targets(hex_data: HexData) -> Dictionary:
	var targets = {}
	var target_blocks = _get_hex_target_blocks(hex_data)
	for i in range(target_blocks.size()):
		var target_block = target_blocks[i]
		var target_key = i
		if typeof(target_block) == TYPE_DICTIONARY and target_block.has("index"):
			target_key = int(target_block.get("index", i))
		targets[target_key] = get_enemy_targets(target_block)
		if not targets[target_key].is_empty():
			last_target = targets[target_key][0]
	return targets

func get_enemy_targets(target_info: Dictionary) -> Array:
	print("[BattleManager] Enemy getting targets with info: ", target_info)
	return _resolve_hex_targets(target_info, true)

func initialize_character_dice_faces(dice_type: String, team_dict: Dictionary) -> void:
	var team_members = team_dict.values()
	if team_members.is_empty():
		return
		
	print("[BattleManager] Initializing dice faces for ", dice_type, " with ", team_members.size(), " characters")
	EmbeddedDiceFaces.clear_all_dice_faces(dice_type)
	
	var faces_to_use = []
	while faces_to_use.size() < 6:
		for char_data in team_members:
			if faces_to_use.size() < 6:
				faces_to_use.append(char_data)
	
	faces_to_use.shuffle()
	
	for i in range(6):
		var char_data = faces_to_use[i]
		var data_dict = {}
		
		# Construct data dict based on dice type (frien or enemy_frien)
		if dice_type == "frien":
			data_dict = {
				"character_name": char_data.name,
				"texture_path": char_data.texture_path,
				"health": char_data.current_health,
				"traits": char_data.traits
			}
		elif dice_type == "enemy_frien":
			var texture_path = _resolve_enemy_dice_texture(
				str(char_data.get("enemy_name", "")),
				str(char_data.get("texture_path", ""))
			)

			data_dict = {
				"unique_id": char_data.name,
				"enemy_name": char_data.get("enemy_name", ""),
				"texture_path": texture_path,
				"health": char_data.current_health,
				"traits": char_data.traits
			}
		
		# Update DiceFaceChanger (Visuals)
		DiceFaceChanger.update_dice_face(dice_type, i, data_dict.texture_path)
		
		# Update EmbeddedDiceFaces (Logic)
		EmbeddedDiceFaces.update_dice_face(dice_type, i, data_dict)
		
	print("[BattleManager] Dice faces initialized for ", dice_type)

func apply_damage(target_node: Node, amount: int) -> void:
	# Calculate total damage with equipment stats
	# Assuming items are used by the player
	var is_player_source = true
	var stats = get_current_equipment_stats(not is_player_source) # false = player
	
	var total_damage = amount + stats.attack_bonus
	print("[BattleManager] Item Damage: Base=", amount, " + Bonus=", stats.attack_bonus, " = Total=", total_damage)
	
	var target_id = _resolve_item_target_character_id(target_node)
	if target_id == "":
		print("[BattleManager] Item damage failed: invalid target node")
		return
	print("[BattleManager] Item damage target resolved: ", target_node.name if target_node else "null", " -> ", target_id)
	# Damage is negative health change
	update_character_health(target_id, -total_damage)

func apply_heal(target_node: Node, amount: int) -> void:
	# Calculate total heal with equipment stats (attack bonus usually applies to healing too)
	# Assuming items are used by the player, so we use player equipment stats.
	# If enemies use items, we might need to check source. But for now items are player-only.
	
	var is_player_source = true # Items are used by player
	var stats = get_current_equipment_stats(not is_player_source) # false = player
	
	var total_heal = amount + stats.attack_bonus
	print("[BattleManager] Base heal: ", amount, " + Equipment Attack: ", stats.attack_bonus, " = Total: ", total_heal)

	var target_id = _resolve_item_target_character_id(target_node)
	if target_id == "":
		print("[BattleManager] Item heal failed: invalid target node")
		return
	update_character_health(target_id, total_heal)
	print("[BattleManager] Healed ", target_id, " for ", total_heal)

func _resolve_item_target_character_id(target_node: Node) -> String:
	if target_node == null:
		return ""
	var node_name = str(target_node.name)
	if player_data.player_characters.has(node_name) or enemy_data.enemy_fiends.has(node_name):
		return node_name
	# Fallback to character script data when runtime node name differs from logical id.
	if "character_data" in target_node and target_node.character_data:
		var player_id = str(target_node.character_data.character_name)
		if player_data.player_characters.has(player_id):
			return player_id
	if "enemy_data" in target_node and target_node.enemy_data:
		var enemy_id = str(target_node.enemy_data.unique_id if target_node.enemy_data.unique_id != "" else target_node.enemy_data.enemy_name)
		if enemy_data.enemy_fiends.has(enemy_id):
			return enemy_id
	var parent = target_node.get_parent()
	if parent != null:
		var parent_name = str(parent.name)
		if player_data.player_characters.has(parent_name) or enemy_data.enemy_fiends.has(parent_name):
			return parent_name
		if "character_data" in parent and parent.character_data:
			var parent_player_id = str(parent.character_data.character_name)
			if player_data.player_characters.has(parent_player_id):
				return parent_player_id
		if "enemy_data" in parent and parent.enemy_data:
			var parent_enemy_id = str(parent.enemy_data.unique_id if parent.enemy_data.unique_id != "" else parent.enemy_data.enemy_name)
			if enemy_data.enemy_fiends.has(parent_enemy_id):
				return parent_enemy_id
	return ""


func get_reroll_count() -> int:
	if is_test_mode:
		return test_reroll_count
	if GameManager.current_run:
		return GameManager.current_run.reroll_count
	return 0

func use_reroll() -> bool:
	if is_test_mode:
		if test_reroll_count <= 0:
			return false
		test_reroll_count -= 1
		return true
	if GameManager.current_run:
		return GameManager.current_run.use_reroll()
	return false

func gain_reroll(amount: int) -> void:
	if is_test_mode:
		test_reroll_count += amount
		print("[BattleManager] Gained ", amount, " test rerolls. Total: ", test_reroll_count)
		return
	if GameManager.current_run:
		GameManager.current_run.gain_reroll(amount)
		print("[BattleManager] Gained ", amount, " rerolls")


func remove_certain_portrait(character_name: String) -> void:
	var scene = get_tree().current_scene
	if scene.has_node(character_name):
		var node = scene.get_node(character_name)
		if not node.tree_exited.is_connected(queue_battle_layout_refresh):
			node.tree_exited.connect(queue_battle_layout_refresh, CONNECT_ONE_SHOT)
		node.queue_free()
		print("[BattleManager] Removed portrait for: ", character_name)
	else:
		print("[BattleManager] Could not find portrait for: ", character_name)


func get_random_encounter(floor_num: int, type: String) -> Array:
	if type == "boss":
		var bosses = GameDataManager.bosses.keys()
		if bosses.is_empty():
			print("[BattleManager] No bosses found in database!")
			return []
		var boss_id = bosses.pick_random()
		print("[BattleManager] Selected boss: ", boss_id)
		return [boss_id]

	var valid_encounters = GameDataManager.get_valid_encounters(floor_num, type)
	if valid_encounters.is_empty():
		print("[BattleManager] No valid encounters found for floor ", floor_num, " type ", type)
		return []
	
	var encounter_id = valid_encounters.pick_random()
	var encounter_data = GameDataManager.encounters[encounter_id]
	var enemies = encounter_data.enemies.duplicate()
	if QuestManager:
		enemies = QuestManager.consume_encounter_override(enemies, type)
	return enemies
