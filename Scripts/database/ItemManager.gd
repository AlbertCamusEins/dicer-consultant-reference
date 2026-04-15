extends Node

# ItemManager.gd
# Central handler for item logic: Usage, Charging, Target Validation.

signal item_used(item: ItemData, target: Node)
signal item_charged(item: ItemData)
signal item_consumed(item: ItemData)

func _ready() -> void:
	_bind_battle_events()

func _bind_battle_events() -> void:
	var rally_cb = Callable(self, "_on_battle_rally")
	if not BattleManager.on_self_action_before.is_connected(rally_cb):
		BattleManager.on_self_action_before.connect(rally_cb)
	var tick_cb = Callable(self, "_on_battle_tick")
	if not BattleManager.on_tick_after.is_connected(tick_cb):
		BattleManager.on_tick_after.connect(tick_cb)

func _on_battle_rally(_context: Dictionary) -> void:
	charge_items(ItemData.ChargeType.RALLY, 1)

func _on_battle_tick(_context: Dictionary) -> void:
	charge_items(ItemData.ChargeType.TICK, 1)

# --- Usage Logic ---

func can_use_item(item: ItemData) -> bool:
	if item.type == ItemData.ItemType.PASSIVE:
		return false # Passives are not "used" actively
	
	if item.max_uses != -1 and item.current_uses <= 0:
		return false
		
	if item.max_charge > 0 and item.current_charge < item.max_charge:
		return false
		
	return true

func use_item(item: ItemData, target_node: Node = null) -> void:
	if not can_use_item(item):
		print("[ItemManager] Cannot use item: ", item.item_name)
		return

	var target_type = get_item_target_type(item)
	if target_type != "none":
		if target_node == null:
			print("[ItemManager] Missing target for item: ", item.item_name)
			return
		if not is_valid_target(item, target_node):
			print("[ItemManager] Invalid target for item: ", item.item_name)
			return
	
	print("[ItemManager] Using item: ", item.item_name, " on target: ", target_node.name if target_node else "null")
	
	# Apply Effect
	_apply_effect(item, target_node)
	
	# Consume Charge
	if item.max_charge > 0:
		item.current_charge = 0
		emit_signal("item_charged", item) # Update UI
	
	# Consume Use
	if item.max_uses != -1:
		item.current_uses -= 1
		if item.current_uses <= 0:
			_consume_item(item)
	
	emit_signal("item_used", item, target_node)

func _consume_item(item: ItemData) -> void:
	print("[ItemManager] Item consumed: ", item.item_name)
	GameManager.current_run.inventory.remove_item(item.item_id)
	emit_signal("item_consumed", item)

func _apply_effect(item: ItemData, target_node: Node) -> void:
	# Compatibility override: turn Refresh Scroll into a gold test item even in old saves.
	if item.item_id == "it004":
		var gold_amount = int(item.effect_params.get("amount", 10))
		if GameManager.current_run:
			GameManager.current_run.gain_gold(gold_amount)
			print("[ItemManager] Gained gold from item ", item.item_name, ": +", gold_amount)
		return

	match item.effect_id:
		"heal":
			var amount = item.effect_params.get("amount", 0)
			BattleManager.apply_heal(target_node, amount)
		"damage":
			var amount = item.effect_params.get("amount", 0)
			BattleManager.apply_damage(target_node, amount)
		"gain_gold":
			var amount = int(item.effect_params.get("amount", 0))
			if GameManager.current_run:
				GameManager.current_run.gain_gold(amount)
				print("[ItemManager] Gained gold: +", amount)
		"reroll":
			var amount = item.effect_params.get("amount", 0)
			BattleManager.gain_reroll(amount)
		"buff_damage":
			pass # Passive, handled elsewhere or on equip
		_:
			print("[ItemManager] Unknown effect: ", item.effect_id)

# --- Charging Logic ---

func charge_items(charge_type: int, amount: int = 1) -> void:
	if amount <= 0:
		return
	if not GameManager.current_run:
		if BattleManager.is_test_mode:
			print("[ItemManager] Test mode without run data, skipping item charge")
		return
	var items = GameManager.current_run.inventory.items.values()
	for item in items:
		if item.type != ItemData.ItemType.ACTIVE:
			continue
		if item.charge_type == charge_type and item.max_charge > 0:
			if item.current_charge < item.max_charge:
				item.current_charge = min(item.current_charge + amount, item.max_charge)
				print("[ItemManager] Charged item: ", item.item_name, " ", item.current_charge, "/", item.max_charge)
				emit_signal("item_charged", item)

# --- Target Validation ---

func get_item_target_type(item: ItemData) -> String:
	if item.item_id == "it004":
		return "none"
	match item.effect_id:
		"heal": return "ally"
		"damage": return "enemy"
		"gain_gold": return "none"
		"reroll": return "none"
		_: return "none"

func is_valid_target(item: ItemData, target_node: Node) -> bool:
	var target_type = get_item_target_type(item)
	
	if target_type == "none":
		return true # No target needed
		
	if target_type == "ally":
		# Assuming ally nodes are in "characters" group or have specific script
		# For now, check if it's a player character node (usually Area2D parent)
		# In BattleScene, characters are instantiated.
		# We need a reliable way to identify them.
		# Let's assume target_node is the CharacterBody2D or Area2D.
		# BattleManager.player_data keys are names.
		# Let's check if the node is in the "player_characters" group (if it exists) or check name.
		# Better: Check if it has "is_player" property or similar.
		# For now, let's assume the UI passes a valid node found via raycast/area.
		# We can check group "frien" or "enemy".
		return target_node.is_in_group("frien")
		
	if target_type == "enemy":
		return target_node.is_in_group("enemy")
		
	return false
