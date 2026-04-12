extends Control
class_name SettingsScreen

@onready var title_label: Label = $MarginContainer/MainColumn/HeaderColumn/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/MainColumn/HeaderColumn/SubtitleLabel
@onready var language_title_label: Label = $MarginContainer/MainColumn/LanguagePanel/MarginContainer/LanguageColumn/LanguageTitleLabel
@onready var language_option_button: OptionButton = $MarginContainer/MainColumn/LanguagePanel/MarginContainer/LanguageColumn/LanguageOptionButton
@onready var audio_title_label: Label = $MarginContainer/MainColumn/AudioPanel/MarginContainer/AudioColumn/AudioTitleLabel
@onready var master_volume_label: Label = $MarginContainer/MainColumn/AudioPanel/MarginContainer/AudioColumn/MasterVolumeLabel
@onready var master_volume_slider: HSlider = $MarginContainer/MainColumn/AudioPanel/MarginContainer/AudioColumn/MasterVolumeSlider
@onready var display_title_label: Label = $MarginContainer/MainColumn/DisplayPanel/MarginContainer/DisplayColumn/DisplayTitleLabel
@onready var window_mode_label: Label = $MarginContainer/MainColumn/DisplayPanel/MarginContainer/DisplayColumn/WindowModeLabel
@onready var window_mode_option_button: OptionButton = $MarginContainer/MainColumn/DisplayPanel/MarginContainer/DisplayColumn/WindowModeOptionButton
@onready var footer_label: Label = $MarginContainer/MainColumn/FooterLabel
@onready var back_button: Button = $MarginContainer/MainColumn/BackButton

var _updating_controls: bool = false

func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	language_option_button.item_selected.connect(_on_language_item_selected)
	window_mode_option_button.item_selected.connect(_on_window_mode_item_selected)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if AppText.language_changed.is_connected(_on_language_changed) == false:
		AppText.language_changed.connect(_on_language_changed)
	_refresh_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and AppText.language_changed.is_connected(_on_language_changed):
		AppText.language_changed.disconnect(_on_language_changed)

func _refresh_controls() -> void:
	_updating_controls = true
	title_label.text = AppText.text("settings.title")
	subtitle_label.text = AppText.text("settings.subtitle")
	language_title_label.text = AppText.text("settings.language")
	audio_title_label.text = AppText.text("settings.audio")
	master_volume_label.text = "%s: %d%%" % [
		AppText.text("settings.master_volume"),
		int(round(AppSettings.master_volume * 100.0)),
	]
	display_title_label.text = AppText.text("settings.display")
	window_mode_label.text = AppText.text("settings.window_mode")
	footer_label.text = AppText.text("settings.saved")
	back_button.text = AppText.text("app.back")
	_rebuild_language_options()
	_rebuild_window_mode_options()
	master_volume_slider.value = AppSettings.master_volume * 100.0
	_updating_controls = false

func _rebuild_language_options() -> void:
	language_option_button.clear()
	var languages: Array[Dictionary] = AppText.get_supported_languages()
	var selected_index: int = 0
	for index in range(languages.size()):
		var entry: Dictionary = languages[index]
		language_option_button.add_item(str(entry.get("native_name", "")))
		language_option_button.set_item_metadata(index, str(entry.get("code", "")))
		if str(entry.get("code", "")) == AppText.current_language:
			selected_index = index
	language_option_button.select(selected_index)

func _rebuild_window_mode_options() -> void:
	window_mode_option_button.clear()
	window_mode_option_button.add_item(AppText.text("settings.windowed"))
	window_mode_option_button.set_item_metadata(0, false)
	window_mode_option_button.add_item(AppText.text("settings.fullscreen"))
	window_mode_option_button.set_item_metadata(1, true)
	window_mode_option_button.select(1 if AppSettings.fullscreen else 0)

func _on_language_item_selected(index: int) -> void:
	if _updating_controls:
		return
	var code: String = str(language_option_button.get_item_metadata(index))
	AppSettings.set_language(code)
	_refresh_controls()

func _on_window_mode_item_selected(index: int) -> void:
	if _updating_controls:
		return
	AppSettings.set_fullscreen(bool(window_mode_option_button.get_item_metadata(index)))
	_refresh_controls()

func _on_master_volume_changed(value: float) -> void:
	if _updating_controls:
		return
	AppSettings.set_master_volume(value / 100.0)
	_refresh_controls()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(GameData.START_SCREEN_SCENE_PATH)

func _on_language_changed(_language_code: String) -> void:
	_refresh_controls()
