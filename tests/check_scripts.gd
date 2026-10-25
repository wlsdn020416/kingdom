extends Node
## 프로젝트의 모든 .gd 파일과 .tscn 파일을 불러서 파싱·컴파일·로딩 오류가 없는지 확인한다.
## 실행: godot --headless --path . res://tests/check_scripts.tscn
## `godot --check-only --script`는 오토로드(Events, Session)를 몰라서 정상 코드도 실패로 보고하고,
## 오류가 있어도 종료 코드가 0이라 쓸 수 없다. 그래서 게임처럼 씬으로 실행해서 검사한다.

const SKIP_DIRS := [".godot", ".git"]


func _ready() -> void:
	var failures := PackedStringArray()
	var scripts := _find_files("res://", "gd")
	# 실행 중인 자기 자신을 CACHE_MODE_IGNORE로 다시 불러오면 엔진이 죽는다 (signal 11)
	scripts.erase(get_script().resource_path)
	for path in scripts:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if script == null or not script.can_instantiate():
			failures.append(path)
	# 씬은 불러오기만 한다 (인스턴스는 만들지 않음).
	# ext_resource 경로가 깨져도 load()는 씬을 돌려주므로 의존 파일이 있는지 따로 확인한다.
	var scenes := _find_files("res://", "tscn")
	for path in scenes:
		var scene := ResourceLoader.load(path) as PackedScene
		if scene == null or not scene.can_instantiate() or not _dependencies_exist(path):
			failures.append(path)
	for path in failures:
		print("  FAIL ", path)
	print("CHECK SCRIPTS %s (스크립트 %d개, 씬 %d개, 실패 %d)" % [
		"PASS" if failures.is_empty() else "FAIL", scripts.size(), scenes.size(), failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


## 의존 항목은 "res://a.gd" 또는 "uid://...::Type::res://a.gd" 형태다
func _dependencies_exist(path: String) -> bool:
	for dependency in ResourceLoader.get_dependencies(path):
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if not ResourceLoader.exists(dependency_path):
			return false
	return true


func _find_files(dir_path: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == extension:
			found.append(dir_path.path_join(file))
	for dir in DirAccess.get_directories_at(dir_path):
		if not dir in SKIP_DIRS:
			found.append_array(_find_files(dir_path.path_join(dir), extension))
	return found
