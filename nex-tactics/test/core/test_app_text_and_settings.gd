extends GutTest

const AppTextScript := preload("res://autoload/app_text.gd")
const AppSettingsScript := preload("res://autoload/app_settings.gd")
const GameDataScript := preload("res://autoload/game_data.gd")

const TEST_SETTINGS_PATH := "user://test_settings.cfg"

var app_text: Node = null
var app_settings: Node = null
var game_data = null

func before_each() -> void:
	_cleanup_settings_file()
	app_text = AppTextScript.new()
	app_text.name = "AppText"
	get_tree().root.add_child(app_text)

	app_settings = AppSettingsScript.new()
	app_settings.name = "AppSettingsTest"
	app_settings.config_path = TEST_SETTINGS_PATH
	get_tree().root.add_child(app_settings)

	game_data = GameDataScript.new()

func after_each() -> void:
	if app_settings != null:
		app_settings.queue_free()
		app_settings = null
	if app_text != null:
		app_text.queue_free()
		app_text = null
	if game_data != null:
		game_data.free()
		game_data = null
	_cleanup_settings_file()

func test_settings_button_and_deck_presentation_are_localized() -> void:
	assert_eq(app_text.text("app.settings"), "Configurações")
	assert_eq(game_data.get_deck_presentation(GameDataScript.DECK_ID_THRAX, "pt_BR").get("menu_name", ""), "Rei Thrax")

	app_text.set_language("en")
	assert_eq(app_text.text("app.settings"), "Settings")
	assert_eq(game_data.get_deck_presentation(GameDataScript.DECK_ID_THRAX, "en").get("menu_name", ""), "King Thrax")

	app_text.set_language("es")
	assert_eq(app_text.text("app.settings"), "Configuración")
	assert_eq(game_data.get_deck_presentation(GameDataScript.DECK_ID_THRAX, "es").get("menu_name", ""), "Rey Thrax")

func test_settings_persist_language_volume_and_fullscreen() -> void:
	app_settings.language = "es"
	app_settings.master_volume = 0.35
	app_settings.fullscreen = true
	app_settings.save_settings()

	var loaded_settings := AppSettingsScript.new()
	loaded_settings.config_path = TEST_SETTINGS_PATH
	loaded_settings.load_settings()

	assert_eq(loaded_settings.language, "es")
	assert_almost_eq(loaded_settings.master_volume, 0.35, 0.001)
	assert_true(loaded_settings.fullscreen)

	loaded_settings.free()

func test_main_ui_scenes_instantiate_with_settings_and_localization() -> void:
	var scene_paths: Array[String] = [
		GameDataScript.START_SCREEN_SCENE_PATH,
		GameDataScript.DECK_SELECT_SCENE_PATH,
		GameDataScript.SETTINGS_SCENE_PATH,
		"res://scenes/ui/battle_hud.tscn",
		"res://scenes/ui/deploy_bar.tscn",
	]

	for scene_path in scene_paths:
		var packed_scene: PackedScene = load(scene_path)
		assert_not_null(packed_scene, "A cena deve carregar: %s" % scene_path)
		var instance: Node = packed_scene.instantiate()
		assert_not_null(instance, "A cena deve instanciar: %s" % scene_path)
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		instance.queue_free()

func _cleanup_settings_file() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)
