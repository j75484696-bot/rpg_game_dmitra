# CI: compile every .gd in the project and exit non-zero if any fails.
#
#   godot --headless --path . -s tools/ci_check_scripts.gd
#
# Runs as a SceneTree and does its work in _initialize(), which fires after the
# autoloads in project.godot are registered. Loading them any earlier — or via
# `godot --check-only -s file.gd`, which never registers them — makes every
# script that touches Elements/Party/Combat/... fail for the wrong reason.
extends SceneTree

const SKIP_DIRS := [".godot", ".git", "build", "addons"]


func _initialize() -> void:
	var failed: Array[String] = []
	var checked := 0
	for path in _collect_scripts("res://"):
		checked += 1
		if not _compiles(path):
			failed.append(path)
	print("ci_check_scripts: %d scripts checked, %d failed" % [checked, failed.size()])
	for path in failed:
		printerr("  FAILED: %s" % path)
	quit(1 if failed.size() > 0 else 0)


func _compiles(path: String) -> bool:
	# load() parses and compiles; a script that fails either comes back null or
	# cannot be instantiated. Don't reload() here — the autoload scripts already
	# have live instances and reloading them corrupts the run.
	var script := load(path) as GDScript
	return script != null and script.can_instantiate()


func _collect_scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		printerr("ci_check_scripts: cannot open %s" % root)
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := root.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				out.append_array(_collect_scripts(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
