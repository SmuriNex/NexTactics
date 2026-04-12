extends Node

signal settings_changed

const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const DEFAULT_MASTER_VOLUME := 0.8

var config_path: String = DEFAULT_CONFIG_PATH
var language: String = "pt_BR"
var master_volume: float = DEFAULT_MASTER_VOLUME
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var load_result: int = config.load(config_path)
	if load_result != OK:
		_reset_defaults()
		return

	language = _normalize_language(str(config.get_value("general", "language", language)))
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(config_path)

func apply_settings() -> void:
	_apply_language()
	_apply_master_volume()
	_apply_window_mode()
	settings_changed.emit()

func set_language(value: String) -> void:
	language = _normalize_language(value)
	_apply_language()
	save_settings()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	save_settings()
	settings_changed.emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_mode()
	save_settings()
	settings_changed.emit()

func _reset_defaults() -> void:
	language = _normalize_language(language)
	master_volume = DEFAULT_MASTER_VOLUME
	fullscreen = false

func _apply_language() -> void:
	var app_text := _app_text_node()
	if app_text != null:
		app_text.set_language(language)

func _apply_master_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		master_bus_index = 0
	AudioServer.set_bus_volume_db(master_bus_index, _linear_to_db_safe(master_volume))

func _apply_window_mode() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _normalize_language(value: String) -> String:
	var app_text := _app_text_node()
	if app_text != null:
		return app_text.normalize_language_code(value)
	return value if not value.is_empty() else language

func _linear_to_db_safe(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped <= 0.0001:
		return -80.0
	return linear_to_db(clamped)

func _app_text_node() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.get_node_or_null("AppText")
	return null
