extends SceneTree

const SCAN_ROOTS := [
	"Scripts",
	"Scenes"
]
const SKIP_PATTERNS := [
	"print(",
	"push_error(",
	"push_warning("
]
const KEY_PREFIXES := [
	"ui.",
	"char.",
	"equipment.",
	"hex.",
	"status.",
	"item.",
	"trait.",
	"quest."
]

func _init() -> void:
	var root := _resolve_root_dir()
	var findings: Array = []
	for scan_root in SCAN_ROOTS:
		_scan_dir(_join_path(root, scan_root), root, findings)
	if findings.is_empty():
		print("[scan_hardcoded_ui] OK")
		print("[scan_hardcoded_ui] EXIT=0")
		quit(0)
	else:
		for finding in findings:
			printerr("[scan_hardcoded_ui] %s" % finding)
		printerr("[scan_hardcoded_ui] EXIT=1")
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

func _display_path(path: String, root: String) -> String:
	var normalized_root := _normalize_root(root)
	if normalized_root == ".":
		return path.replace("\\", "/")
	var prefix := normalized_root.replace("\\", "/").trim_suffix("/") + "/"
	var normalized_path := path.replace("\\", "/")
	if normalized_path.begins_with(prefix):
		return normalized_path.trim_prefix(prefix)
	return normalized_path

func _scan_dir(path: String, display_root: String, findings: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var child_path := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_scan_dir(child_path, display_root, findings)
		elif child_path.ends_with(".gd") or child_path.ends_with(".tscn"):
			_scan_file(child_path, display_root, findings)
	dir.list_dir_end()

func _scan_file(path: String, display_root: String, findings: Array) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_no := 0
	while not file.eof_reached():
		line_no += 1
		var line := file.get_line()
		var extracted := _extract_literal_text(line)
		if extracted == "":
			continue
		if path.ends_with(".gd"):
			var skip := false
			for pattern in SKIP_PATTERNS:
				if pattern in line:
					skip = true
					break
			if skip:
				continue
		if not _is_localized_key(extracted) and not _is_safe_literal(extracted):
			findings.append("%s:%d %s" % [_display_path(path, display_root), line_no, line.strip_edges()])

func _extract_literal_text(line: String) -> String:
	var patterns := [
		".text = \"",
		"text = \"",
		"dialog_text = \"",
		"title = \""
	]
	for pattern in patterns:
		var index := line.find(pattern)
		if index == -1:
			continue
		var start = index + pattern.length()
		var ending := line.find("\"", start)
		if ending == -1:
			return ""
		return line.substr(start, ending - start)
	return ""

func _is_localized_key(value: String) -> bool:
	for prefix in KEY_PREFIXES:
		if value.begins_with(prefix):
			return true
	return false

func _is_safe_literal(value: String) -> bool:
	var trimmed := value.strip_edges()
	if trimmed == "" or trimmed == "text" or trimmed == "text2":
		return true
	if trimmed == "->":
		return true
	if trimmed.replace("%s", "").replace("%d", "").replace("%f", "").replace("\\n", "").replace(" ", "").replace(":", "").replace("/", "").replace("+", "").replace("-", "") == "":
		return true
	if trimmed.is_valid_int():
		return true
	return false
