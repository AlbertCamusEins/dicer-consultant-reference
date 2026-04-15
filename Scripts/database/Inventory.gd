extends Node

class_name Inventory


var frien_faces: Dictionary = {}  
var equipment_faces: Dictionary = {} 
var common_action_faces: Dictionary = {}  
var uncommon_action_faces: Dictionary = {}  
var hex_faces: Dictionary = {}   
var items: Dictionary = {}      

signal inventory_updated

func _init():
	
	frien_faces.clear()
	common_action_faces.clear()
	uncommon_action_faces.clear()
	hex_faces.clear()
	items.clear()

func _remove_duplicate_frien_by_identity(character_id: String, character_name: String, keep_face_id: String) -> void:
	if character_id == "" and character_name == "":
		return
	var ids_to_remove: Array = []
	for existing_id in frien_faces.keys():
		if str(existing_id) == keep_face_id:
			continue
		var existing_face = frien_faces[existing_id]
		if existing_face != null and (str(existing_face.id) == character_id or str(existing_face.character_name) == character_name):
			ids_to_remove.append(existing_id)
	for existing_id in ids_to_remove:
		frien_faces.erase(existing_id)

func _remove_duplicate_equipment_by_identity(equipment_id: String, equipment_name: String, keep_face_id: String) -> void:
	if equipment_id == "" and equipment_name == "":
		return
	var ids_to_remove: Array = []
	for existing_id in equipment_faces.keys():
		if str(existing_id) == keep_face_id:
			continue
		var existing_face = equipment_faces[existing_id]
		if existing_face != null and (str(existing_face.id) == equipment_id or str(existing_face.equipment_name) == equipment_name):
			ids_to_remove.append(existing_id)
	for existing_id in ids_to_remove:
		equipment_faces.erase(existing_id)

func _remove_duplicate_hex_by_identity(hex_id: String, hex_name: String, keep_face_id: String) -> void:
	if hex_id == "" and hex_name == "":
		return
	var ids_to_remove: Array = []
	for existing_id in hex_faces.keys():
		if str(existing_id) == keep_face_id:
			continue
		var existing_face = hex_faces[existing_id]
		if existing_face != null and (str(existing_face.id) == hex_id or str(existing_face.hex_name) == hex_name):
			ids_to_remove.append(existing_id)
	for existing_id in ids_to_remove:
		hex_faces.erase(existing_id)


func _has_existing_frien_identity(character_id: String, character_name: String) -> bool:
	if character_id != "" and frien_faces.has(character_id):
		return true
	for existing_face in frien_faces.values():
		if existing_face != null and (str(existing_face.id) == character_id or str(existing_face.character_name) == character_name):
			return true
	return false


func _has_existing_equipment_identity(equipment_id: String, equipment_name: String) -> bool:
	if equipment_id != "" and equipment_faces.has(equipment_id):
		return true
	for existing_face in equipment_faces.values():
		if existing_face != null and (str(existing_face.id) == equipment_id or str(existing_face.equipment_name) == equipment_name):
			return true
	return false


func _has_existing_hex_identity(hex_id: String, hex_name: String) -> bool:
	if hex_id != "" and hex_faces.has(hex_id):
		return true
	for existing_face in hex_faces.values():
		if existing_face != null and (str(existing_face.id) == hex_id or str(existing_face.hex_name) == hex_name):
			return true
	return false


func add_face(face_type: String, face_id: String, face_data: Dictionary, emit_map_notice: bool = true) -> void:
	var normalized_face_id := str(face_id)
	var did_add := false
	var should_queue_notice := false
	match face_type:
		"frien":
			face_data = face_data.duplicate(true)
			if not face_data.has("id") or str(face_data.get("id", "")) == "":
				var resolved_character_id = GameDataManager.get_character_id_by_name(str(face_data.get("character_name", normalized_face_id)))
				face_data["id"] = resolved_character_id if resolved_character_id != "" else normalized_face_id
			normalized_face_id = str(face_data.get("id", normalized_face_id))
			var character_id = str(face_data.get("id", normalized_face_id))
			var character_name = str(face_data.get("character_name", ""))
			should_queue_notice = not _has_existing_frien_identity(character_id, character_name)
			var character = CharacterData.new()
			character.init(face_data)
			_remove_duplicate_frien_by_identity(str(character.id), str(character.character_name), normalized_face_id)
			frien_faces[normalized_face_id] = character
			did_add = true
		"equipment":
			face_data = face_data.duplicate(true)
			var equipment = EquipmentData.new()
			if not face_data.has("id"):
				var resolved_id = GameDataManager.get_equipment_id_by_name(str(face_data.get("equipment_name", normalized_face_id)))
				face_data["id"] = resolved_id if resolved_id != "" else normalized_face_id
			normalized_face_id = str(face_data.get("id", normalized_face_id))
			var equipment_id = str(face_data.get("id", normalized_face_id))
			var equipment_name = str(face_data.get("equipment_name", ""))
			should_queue_notice = not _has_existing_equipment_identity(equipment_id, equipment_name)
			equipment.init(face_data)
			_remove_duplicate_equipment_by_identity(str(equipment.id), str(equipment.equipment_name), normalized_face_id)
			equipment_faces[normalized_face_id] = equipment
			did_add = true
		"common_action":
			if not common_action_faces.has(normalized_face_id):
				var action = ActionData.new_common_action()
				action.init(face_data)
				common_action_faces[normalized_face_id] = action
				did_add = true
		"uncommon_action":
			if not uncommon_action_faces.has(normalized_face_id):
				var action = ActionData.new_uncommon_action()
				action.init(face_data)
				uncommon_action_faces[normalized_face_id] = action
				did_add = true
		"hex2":
			face_data = face_data.duplicate(true)
			if not face_data.has("id") or str(face_data.get("id", "")) == "":
				var resolved_hex_id = GameDataManager.get_hex_id_by_name(str(face_data.get("hex_name", normalized_face_id)))
				face_data["id"] = resolved_hex_id if resolved_hex_id != "" else normalized_face_id
			normalized_face_id = str(face_data.get("id", normalized_face_id))
			var hex_id = str(face_data.get("id", normalized_face_id))
			var hex_name = str(face_data.get("hex_name", ""))
			should_queue_notice = not _has_existing_hex_identity(hex_id, hex_name)
			var hex = HexData.new()
			hex.init(face_data)
			_remove_duplicate_hex_by_identity(str(hex.id), str(hex.hex_name), normalized_face_id)
			hex_faces[normalized_face_id] = hex
			did_add = true
	
	emit_signal("inventory_updated")
	if did_add and should_queue_notice and emit_map_notice and GameManager.current_run != null:
		GameManager.current_run.queue_face_install_notice(face_type)


func remove_face(face_type: String, face_id: String) -> void:
	match face_type:
		"frien":
			frien_faces.erase(face_id)
		"equipment":
			equipment_faces.erase(face_id)
		"common_action":
			common_action_faces.erase(face_id)
		"uncommon_action":
			uncommon_action_faces.erase(face_id)
		"hex2":
			hex_faces.erase(face_id)
	
	emit_signal("inventory_updated")


func remove_face_by_character(character_name: String) -> void:
	var target_ids = []
	for face_id in frien_faces:
		var face = frien_faces[face_id]
		if face.character_name == character_name:
			target_ids.append(face_id)
	
	for id in target_ids:
		frien_faces.erase(id)
	
	if not target_ids.is_empty():
		emit_signal("inventory_updated")


func get_faces(face_type: String) -> Array:
	match face_type:
		"frien":
			return frien_faces.values()
		"equipment":
			return equipment_faces.values()
		"common_action":
			return common_action_faces.values()
		"uncommon_action":
			return uncommon_action_faces.values()
		"hex2":
			return hex_faces.values()
	return []


func has_face(face_type: String, face_id: String) -> bool:
	match face_type:
		"frien":
			return frien_faces.has(face_id)
		"equipment":
			return equipment_faces.has(face_id)
		"common_action":
			return common_action_faces.has(face_id)
		"uncommon_action":
			return uncommon_action_faces.has(face_id)
		"hex2":
			return hex_faces.has(face_id)
	return false


func get_face_data(face_type: String, face_id: String):
	match face_type:
		"frien":
			return frien_faces.get(face_id)
		"equipment":
			return equipment_faces.get(face_id)
		"common_action":
			return common_action_faces.get(face_id)
		"uncommon_action":
			return uncommon_action_faces.get(face_id)
		"hex2":
			return hex_faces.get(face_id)
	return null


func add_item(item_id: String, item_data: Dictionary) -> void:
	var normalized_item_id := str(item_id)
	var payload := item_data.duplicate(true)
	if str(payload.get("item_id", "")) == "":
		var resolved_item_id = GameDataManager.get_item_id_by_name(str(payload.get("item_name", normalized_item_id)))
		payload["item_id"] = resolved_item_id if resolved_item_id != "" else normalized_item_id
	normalized_item_id = str(payload.get("item_id", normalized_item_id))
	if not items.has(normalized_item_id):
		var item = ItemData.new()
		item.init(payload)
		item.item_id = normalized_item_id
		items[normalized_item_id] = item
		emit_signal("inventory_updated")


func remove_item(item_id: String) -> void:
	if items.has(item_id):
		items.erase(item_id)
		emit_signal("inventory_updated")


func get_items() -> Array:
	return items.values()


func has_item(item_id: String) -> bool:
	return items.has(item_id)


func get_item_data(item_id: String) -> ItemData:
	return items.get(item_id)

func get_sorted_items() -> Array:
	var sorted_items = []
	var passives = []
	var actives = []
	var consumables = []
	
	for item in items.values():
		match item.type:
			ItemData.ItemType.PASSIVE:
				passives.append(item)
			ItemData.ItemType.ACTIVE:
				actives.append(item)
			ItemData.ItemType.CONSUMABLE:
				consumables.append(item)
	
	sorted_items.append_array(passives)
	sorted_items.append_array(actives)
	sorted_items.append_array(consumables)
	
	return sorted_items


func clear_all() -> void:
	frien_faces.clear()
	equipment_faces.clear()
	common_action_faces.clear()
	uncommon_action_faces.clear()
	hex_faces.clear()
	items.clear()
	emit_signal("inventory_updated")


func save_data() -> Dictionary:
	return {
		"frien_faces": frien_faces,
		"equipment_faces": equipment_faces,
		"common_action_faces": common_action_faces,
		"uncommon_action_faces": uncommon_action_faces,
		"hex_faces": hex_faces,
		"items": items
	}


func load_data(data: Dictionary) -> void:
	clear_all()
	

	for face_id in data.get("frien_faces", {}):
		add_face("frien", face_id, data["frien_faces"][face_id], false)
	
	for face_id in data.get("equipment_faces", {}):
		add_face("equipment", face_id, data["equipment_faces"][face_id], false)
	
	for face_id in data.get("common_action_faces", {}):
		add_face("common_action", face_id, data["common_action_faces"][face_id], false)
	
	for face_id in data.get("uncommon_action_faces", {}):
		add_face("uncommon_action", face_id, data["uncommon_action_faces"][face_id], false)
	
	for face_id in data.get("hex_faces", {}):
		add_face("hex2", face_id, data["hex_faces"][face_id], false)
		
	for item_id in data.get("items", {}):
		add_item(item_id, data["items"][item_id])


func to_dict() -> Dictionary:
	print("[Inventory] Converting to dictionary")
	var dict = {
		"frien_faces": {},
		"equipment_faces": {},
		"common_action_faces": {},
		"uncommon_action_faces": {},
		"hex_faces": {},
		"items": {}
	}
	
	
	for face_id in frien_faces:
		var face = frien_faces[face_id]
		dict["frien_faces"][face_id] = {
			"id": face.id,
			"character_name": face.character_name,
			"texture_path": face.texture_path,
			"health": face.health,
			"traits": face.traits,
			"countdown": face.countdown,
			"prime_hex_id": face.prime_hex_id,
			"peak_hex_id": face.peak_hex_id,
			"soul_hex_id": face.soul_hex_id,
			"experience": face.experience,
			"slot_limit": face.slot_limit
		}
	
	
	for face_id in common_action_faces:
		var face = common_action_faces[face_id]
		dict["common_action_faces"][face_id] = {
			"action_name": face.action_name,
			"texture_path": face.texture_path,
			"effect": face.effect,
			"is_special": face.is_special,
			"owner_character": face.owner_character
		}
	
	
	for face_id in equipment_faces:
		var face = equipment_faces[face_id]
		dict["equipment_faces"][face_id] = face.to_dict()

	
	for face_id in uncommon_action_faces:
		var face = uncommon_action_faces[face_id]
		dict["uncommon_action_faces"][face_id] = {
			"action_name": face.action_name,
			"texture_path": face.texture_path,
			"effect": face.effect,
			"is_special": face.is_special,
			"owner_character": face.owner_character
		}
	
	
	for face_id in hex_faces:
		var face = hex_faces[face_id]
		dict["hex_faces"][face_id] = face.to_dict()
		
	
	for item_id in items:
		var item = items[item_id]
		dict["items"][item_id] = item.to_dict()
	
	print("[Inventory] Dictionary conversion completed")
	return dict

func from_dict(dict: Dictionary) -> void:
	print("[Inventory] Loading from dictionary")
	clear_all()  
	
	
	if dict.has("frien_faces"):
		for face_id in dict["frien_faces"]:
			var face_data = dict["frien_faces"][face_id]
			add_face("frien", face_id, face_data, false)
	
	
	if dict.has("equipment_faces"):
		for face_id in dict["equipment_faces"]:
			var face_data = dict["equipment_faces"][face_id]
			add_face("equipment", face_id, face_data, false)
	
	
	if dict.has("common_action_faces"):
		for face_id in dict["common_action_faces"]:
			var face_data = dict["common_action_faces"][face_id]
			add_face("common_action", face_id, face_data, false)
	
	
	if dict.has("uncommon_action_faces"):
		for face_id in dict["uncommon_action_faces"]:
			var face_data = dict["uncommon_action_faces"][face_id]
			add_face("uncommon_action", face_id, face_data, false)
	
	
	if dict.has("hex_faces"):
		for face_id in dict["hex_faces"]:
			add_face("hex2", face_id, dict["hex_faces"][face_id], false)
	
	
	if dict.has("items"):
		for item_id in dict["items"]:
			var item = ItemData.new()
			item.from_dict(dict["items"][item_id])
			items[item_id] = item
	
	print("[Inventory] Dictionary loading completed")
	emit_signal("inventory_updated")
