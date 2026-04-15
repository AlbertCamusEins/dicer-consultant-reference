extends SceneTree

const DATA_FILES := [
	"GameData/characters.json",
	"GameData/equipments_v2.json",
	"GameData/hexes.json",
	"GameData/items.json",
	"GameData/statuses_v2.json",
	"GameData/traits_v2.json",
	"GameData/quests.json"
]

func _init() -> void:
	var root := _resolve_root_dir()
	var failures: Array = []
	for relative_path in DATA_FILES:
		var full_path := _join_path(root, relative_path)
		var data := _load_json(full_path)
		if data.is_empty():
			failures.append("failed_to_load:%s" % relative_path)
			continue
		_validate_keys(relative_path, data, failures)
	if failures.is_empty():
		print("[validate_localization_data] OK")
		print("[validate_localization_data] EXIT=0")
		quit(0)
	else:
		for failure in failures:
			printerr("[validate_localization_data] %s" % failure)
		printerr("[validate_localization_data] EXIT=1")
		quit(1)

func _resolve_root_dir() -> String:
	var user_args := OS.get_cmdline_user_args()
	for index in range(user_args.size()):
		if user_args[index] == "--root" and index + 1 < user_args.size():
			return _normalize_root(user_args[index + 1])
	if _has_project_marker("."):
		return "."
	if _has_project_marker(".."):
		return ".."
	return "."

func _normalize_root(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed == "":
		return "."
	return trimmed.trim_suffix("/").trim_suffix("\\")

func _has_project_marker(root: String) -> bool:
	return FileAccess.file_exists(_join_path(root, "project.godot"))

func _join_path(base: String, child: String) -> String:
	if base == "" or base == ".":
		return child
	if base.ends_with("/") or base.ends_with("\\"):
		return "%s%s" % [base, child]
	return "%s/%s" % [base, child]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.get_data()
	return data if typeof(data) == TYPE_DICTIONARY else {}

func _validate_keys(path: String, data: Dictionary, failures: Array) -> void:
	for top_key in data.keys():
		var entries = data[top_key]
		if typeof(entries) != TYPE_DICTIONARY:
			continue
		for entry_id in entries.keys():
			var entry = entries[entry_id]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var visible_fields = [
				"display_name_key",
				"description_key",
				"title_key"
			]
			for field in visible_fields:
				if entry.has(field) and str(entry[field]).strip_edges() == "":
					failures.append("%s:%s empty %s" % [path, entry_id, field])
