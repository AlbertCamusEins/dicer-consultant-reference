extends Node

class_name RunData

const STATE_PENDING_SETUP := "pending_setup"
const STATE_ACTIVE := "active"

var current_floor: int = 1
var inventory: Inventory
var embedded_dice_faces: Dictionary = {}
var completed_dice_customization: Dictionary = {
	"frien": false,
	"equipment": false,
	"hex2": false
}
var saved_dice_layouts: Dictionary = {}  # stored as key: layout_name, value: layout_data (Array of face IDs)
var gold: int = 0
var shop_reroll_price: int = 10
var rest_available: bool = true
var rest_cooldown: int = 0
var dispatch_state: String = "idle" # idle / dispatching / returned
var dispatch_character_name: String = ""
var dispatch_battles_remaining: int = 0
var dispatch_reward_gold: int = 0
var task_offers: Array = []
var active_tasks: Dictionary = {}
var completed_tasks: Dictionary = {}
var failed_tasks: Dictionary = {}
var task_counters: Dictionary = {}
var goals_progress: Dictionary = {}
var character_current_health: Dictionary = {} # key: character_name, value: current_health
var reroll_count: int = 0
var forge_points: int = 0
var battle_scene_enter_count: int = 0
var run_state: String = STATE_PENDING_SETUP
var frontdesk_entered_floors: Dictionary = {}
var pending_map_notice_key: String = ""
var pending_map_notice_meta: Dictionary = {}
var pending_face_install_notice_types: Array = []


func _init():
	inventory = Inventory.new()
	

func start_new_run() -> void:
	current_floor = 1
	gold = 0
	shop_reroll_price = 10
	rest_available = true
	rest_cooldown = 0
	dispatch_state = "idle"
	dispatch_character_name = ""
	dispatch_battles_remaining = 0
	dispatch_reward_gold = 0
	task_offers.clear()
	active_tasks.clear()
	completed_tasks.clear()
	failed_tasks.clear()
	task_counters.clear()
	reroll_count = 0
	forge_points = 0
	battle_scene_enter_count = 0
	run_state = STATE_PENDING_SETUP
	frontdesk_entered_floors.clear()
	pending_map_notice_key = ""
	pending_map_notice_meta.clear()
	pending_face_install_notice_types.clear()
	goals_progress.clear()
	embedded_dice_faces.clear()
	saved_dice_layouts.clear()  
	character_current_health.clear()
	completed_dice_customization = {
		"frien": false,
		"equipment": false,
		"hex2": false	
	}
	
	
	inventory.clear_all()


func activate_run() -> void:
	run_state = STATE_ACTIVE


func is_pending_setup() -> bool:
	return run_state == STATE_PENDING_SETUP


func is_active_run() -> bool:
	return run_state == STATE_ACTIVE


func has_entered_frontdesk_on_floor(floor: int) -> bool:
	return bool(frontdesk_entered_floors.get(str(floor), false))


func has_entered_frontdesk_current_floor() -> bool:
	return has_entered_frontdesk_on_floor(current_floor)


func mark_frontdesk_entered_current_floor() -> void:
	frontdesk_entered_floors[str(current_floor)] = true


func queue_face_install_notice(face_type: String) -> void:
	if not is_active_run():
		return
	if face_type != "frien" and face_type != "equipment" and face_type != "hex2":
		return
	if not pending_face_install_notice_types.has(face_type):
		pending_face_install_notice_types.append(face_type)
	pending_map_notice_key = "ui.map.new_face_reminder"
	pending_map_notice_meta = {}


func clear_face_install_notice(face_type: String) -> void:
	if pending_face_install_notice_types.has(face_type):
		pending_face_install_notice_types.erase(face_type)
	if pending_face_install_notice_types.is_empty():
		clear_pending_map_notice()
	elif pending_map_notice_key == "":
		pending_map_notice_key = "ui.map.new_face_reminder"


func has_pending_face_install_notice() -> bool:
	return not pending_face_install_notice_types.is_empty()


func clear_pending_map_notice() -> void:
	pending_map_notice_key = ""
	pending_map_notice_meta.clear()
	pending_face_install_notice_types.clear()
	



func acquire_face(face_type: String, face_id: String, face_data: Dictionary) -> void:
	inventory.add_face(face_type, face_id, face_data)


func lose_face(face_type: String, face_id: String) -> void:
	inventory.remove_face(face_type, face_id)

func lose_item(item_id: String) -> void:
	inventory.remove_item(item_id)


func gain_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	_emit_quest_event("gold_gained", {
		"count": amount,
		"total_gold": gold
	})


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		_emit_quest_event("gold_spent", {
			"count": amount,
			"total_gold": gold
		})
		return true
	return false


func update_goal_progress(goal_id: String, progress: float) -> void:
	goals_progress[goal_id] = progress


func get_goal_progress(goal_id: String) -> float:
	return goals_progress.get(goal_id, 0.0)


func advance_to_next_floor() -> void:
	current_floor += 1
	_emit_quest_event("floor_advanced", {
		"count": 1,
		"floor": current_floor
	})
	MapStateManager.reset()
	MapScene.clear_saved_state()


func gain_reroll(amount: int = 1) -> void:
	reroll_count += amount


func use_reroll() -> bool:
	if reroll_count > 0:
		reroll_count -= 1
		return true
	return false


func begin_rest_cooldown(battle_count: int = 3) -> void:
	rest_available = false
	rest_cooldown = max(0, battle_count)


func advance_rest_cooldown_after_battle() -> void:
	if rest_available:
		return
	if rest_cooldown > 0:
		rest_cooldown -= 1
	if rest_cooldown <= 0:
		rest_cooldown = 0
		rest_available = true


func begin_dispatch(character_name: String, battle_count: int = 3, reward_gold: int = 0) -> bool:
	var trimmed_name := character_name.strip_edges()
	if trimmed_name == "":
		return false
	if dispatch_state != "idle":
		return false
	dispatch_state = "dispatching"
	dispatch_character_name = trimmed_name
	dispatch_battles_remaining = max(0, battle_count)
	dispatch_reward_gold = max(0, reward_gold)
	if dispatch_battles_remaining <= 0:
		dispatch_state = "returned"
		dispatch_battles_remaining = 0
	_emit_quest_event("dispatch_started", {
		"count": 1,
		"character_name": dispatch_character_name,
		"battles_required": dispatch_battles_remaining
	})
	return true


func is_dispatch_available() -> bool:
	return dispatch_state == "idle"


func advance_dispatch_after_battle() -> void:
	if dispatch_state != "dispatching":
		return
	if dispatch_battles_remaining > 0:
		dispatch_battles_remaining -= 1
		_emit_quest_event("dispatch_battle_advanced", {
			"count": 1,
			"character_name": dispatch_character_name,
			"battles_remaining": dispatch_battles_remaining
		})
	if dispatch_battles_remaining <= 0:
		dispatch_battles_remaining = 0
		dispatch_state = "returned"
		_emit_quest_event("dispatch_returned", {
			"count": 1,
			"character_name": dispatch_character_name
		})


func can_claim_dispatch_reward() -> bool:
	return dispatch_state == "returned"


func claim_dispatch_reward() -> int:
	if dispatch_state != "returned":
		return 0
	var reward: int = max(0, int(dispatch_reward_gold))
	if reward > 0:
		gain_gold(reward)
		_emit_quest_event("dispatch_complete", {
			"count": 1,
			"reward_gold": reward
		})
	dispatch_state = "idle"
	dispatch_character_name = ""
	dispatch_battles_remaining = 0
	dispatch_reward_gold = 0
	return reward

func _emit_quest_event(event_id: String, payload: Dictionary = {}) -> void:
	if QuestProgressBus:
		QuestProgressBus.emit_event(event_id, payload)

func save_embedded_dice_faces() -> void:
	embedded_dice_faces = EmbeddedDiceFaces.to_dict()


func load_embedded_dice_faces() -> void:
	if not embedded_dice_faces.is_empty():
		EmbeddedDiceFaces.from_dict(embedded_dice_faces)


func set_dice_customization_completed(dice_type: String, completed: bool) -> void:
	if completed_dice_customization.has(dice_type):
		completed_dice_customization[dice_type] = completed


func is_dice_customization_completed(dice_type: String) -> bool:
	return completed_dice_customization.get(dice_type, false)


func save_dice_layout(key: String, layout_data: Array) -> void:
	saved_dice_layouts[key] = layout_data


func get_dice_layout(key: String) -> Array:
	return saved_dice_layouts.get(key, [])


func save_data() -> Dictionary:
	return {
		"current_floor": current_floor,
		"inventory": inventory.save_data(),
		"gold": gold,
		"shop_reroll_price": shop_reroll_price,
		"rest_available": rest_available,
		"rest_cooldown": rest_cooldown,
		"dispatch_state": dispatch_state,
		"dispatch_character_name": dispatch_character_name,
		"dispatch_battles_remaining": dispatch_battles_remaining,
		"dispatch_reward_gold": dispatch_reward_gold,
		"task_offers": task_offers,
		"active_tasks": active_tasks,
		"completed_tasks": completed_tasks,
		"failed_tasks": failed_tasks,
		"task_counters": task_counters,
		"goals_progress": goals_progress,
		"reroll_count": reroll_count,
		"forge_points": forge_points,
		"run_state": run_state,
		"embedded_dice_faces": embedded_dice_faces,
		"saved_dice_layouts": saved_dice_layouts,   
		"completed_dice_customization": completed_dice_customization,
		"character_current_health": character_current_health,
		"battle_scene_enter_count": battle_scene_enter_count,
		"frontdesk_entered_floors": frontdesk_entered_floors,
		"pending_map_notice_key": pending_map_notice_key,
		"pending_map_notice_meta": pending_map_notice_meta,
		"pending_face_install_notice_types": pending_face_install_notice_types
	}


func load_data(data: Dictionary) -> void:
	current_floor = data.get("current_floor", 1)
	inventory.load_data(data.get("inventory", {}))
	gold = data.get("gold", 0)
	shop_reroll_price = data.get("shop_reroll_price", 10)
	rest_available = data.get("rest_available", true)
	rest_cooldown = max(0, int(data.get("rest_cooldown", 0)))
	if rest_cooldown <= 0:
		rest_cooldown = 0
		rest_available = true
	dispatch_state = str(data.get("dispatch_state", "idle"))
	dispatch_character_name = str(data.get("dispatch_character_name", ""))
	dispatch_battles_remaining = max(0, int(data.get("dispatch_battles_remaining", 0)))
	dispatch_reward_gold = max(0, int(data.get("dispatch_reward_gold", 0)))
	task_offers = data.get("task_offers", [])
	active_tasks = data.get("active_tasks", {})
	completed_tasks = data.get("completed_tasks", {})
	failed_tasks = data.get("failed_tasks", {})
	task_counters = data.get("task_counters", {})
	if dispatch_state != "dispatching" and dispatch_state != "returned":
		dispatch_state = "idle"
	if dispatch_state == "idle":
		dispatch_character_name = ""
		dispatch_battles_remaining = 0
		dispatch_reward_gold = 0
	elif dispatch_state == "dispatching" and dispatch_battles_remaining <= 0:
		dispatch_state = "returned"
		dispatch_battles_remaining = 0
	goals_progress = data.get("goals_progress", {})
	reroll_count = data.get("reroll_count", 0)
	forge_points = int(data.get("forge_points", 0))
	run_state = str(data.get("run_state", STATE_ACTIVE))
	if run_state != STATE_PENDING_SETUP and run_state != STATE_ACTIVE:
		run_state = STATE_ACTIVE
	embedded_dice_faces = data.get("embedded_dice_faces", {})
	saved_dice_layouts = data.get("saved_dice_layouts", {})
	completed_dice_customization = data.get("completed_dice_customization", {
		"frien": false,
		"equipment": false,
		"hex2": false
	})
	character_current_health = data.get("character_current_health", {})
	battle_scene_enter_count = max(0, int(data.get("battle_scene_enter_count", 0)))
	frontdesk_entered_floors = data.get("frontdesk_entered_floors", {})
	if typeof(frontdesk_entered_floors) != TYPE_DICTIONARY:
		frontdesk_entered_floors = {}
	pending_map_notice_key = str(data.get("pending_map_notice_key", ""))
	pending_map_notice_meta = data.get("pending_map_notice_meta", {})
	if typeof(pending_map_notice_meta) != TYPE_DICTIONARY:
		pending_map_notice_meta = {}
	pending_face_install_notice_types = data.get("pending_face_install_notice_types", [])
	if typeof(pending_face_install_notice_types) != TYPE_ARRAY:
		pending_face_install_notice_types = []
	
	load_embedded_dice_faces()
