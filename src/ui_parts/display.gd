extends VBoxContainer

signal view_settings_updated(show_grid: bool, show_handles: bool, rasterized_svg: bool)
signal snap_settings_updated(snap_enabled: bool, snap_amount: float)

const NumberEditType = preload("res://src/ui_widgets/number_edit.gd")
const BetterToggleButtonType = preload("res://src/ui_widgets/BetterToggleButton.gd")

const NumberField = preload("res://src/ui_widgets/number_field.tscn")
const ConfirmDialog := preload("res://src/ui_parts/confirm_dialog.tscn")

@onready var viewport: SubViewport = %Viewport
@onready var controls: Control = %Viewport/Controls
@onready var grid_visuals: Control = %Viewport/Camera
@onready var reference_texture = %Viewport/ReferenceTexture
@onready var reference_button = %LeftMenu/Reference
@onready var visuals_button: Button = %LeftMenu/Visuals
@onready var more_button: Button = %LeftMenu/MoreOptions
@onready var snapper: NumberEditType = %LeftMenu/Snapping/SnapNumberEdit
@onready var snap_button: BetterToggleButtonType = %LeftMenu/Snapping/SnapButton
@onready var panel_container: PanelContainer = $PanelContainer
@onready var viewport_panel: PanelContainer = $ViewportPanel
@onready var debug_container: MarginContainer = $ViewportPanel/DebugMargins
@onready var debug_label: Label = %DebugContainer/DebugLabel
@onready var input_debug_label: Label = %DebugContainer/InputDebugLabel

var reference_overlay := false

func _ready() -> void:
	Configs.language_changed.connect(update_translations)
	Configs.snap_changed.connect(update_snap_config)
	Configs.theme_changed.connect(update_theme)
	update_translations()
	update_theme()
	update_snap_config()
	get_window().window_input.connect(_update_input_debug)
	view_settings_updated.emit(grid_visuals.visible, controls.visible,
			viewport.display_texture.rasterized)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("debug"):
		if debug_container.visible:
			debug_container.hide()
		else:
			debug_container.show()
			update_debug()
			input_debug_label.text = ""
	elif ShortcutUtils.is_action_pressed(event, "load_reference"):
		FileUtils.open_image_import_dialog(finish_reference_import)
	elif ShortcutUtils.is_action_pressed(event, "view_show_grid"):
		toggle_grid_visuals()
	elif ShortcutUtils.is_action_pressed(event, "view_show_handles"):
		toggle_handles_visuals()
	elif ShortcutUtils.is_action_pressed(event, "view_rasterized_svg"):
		toggle_rasterization()
	elif ShortcutUtils.is_action_pressed(event, "view_show_reference"):
		toggle_reference_image()
	elif ShortcutUtils.is_action_pressed(event, "view_overlay_reference"):
		toggle_reference_overlay()
	elif ShortcutUtils.is_action_pressed(event, "toggle_snap"):
		toggle_snap()


func update_translations() -> void:
	%LeftMenu/Settings.tooltip_text = Translator.translate("Settings")
	%LeftMenu/Visuals.tooltip_text = Translator.translate("Visuals")
	%LeftMenu/Snapping/SnapButton.tooltip_text =\
			TranslationUtils.get_shortcut_description("toggle_snap")
	%LeftMenu/Snapping/SnapNumberEdit.tooltip_text = Translator.translate(
			"Snap size")

func update_theme() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = ThemeUtils.overlay_panel_inner_color
	stylebox.set_content_margin_all(6)
	panel_container.add_theme_stylebox_override("panel", stylebox)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_width_left = 2
	frame.border_width_top = 2
	frame.border_color = ThemeUtils.connected_button_border_color_pressed
	frame.content_margin_left = 2
	frame.content_margin_top = 2
	viewport_panel.add_theme_stylebox_override("panel", frame)

func update_snap_config() -> void:
	var snap_config := Configs.savedata.snap
	var snap_enabled := snap_config > 0.0
	snap_button.button_pressed = snap_enabled
	snapper.editable = snap_enabled
	snapper.set_value(absf(snap_config))
	snap_settings_updated.emit(snap_enabled, absf(snap_config))


func _on_settings_pressed() -> void:
	ShortcutUtils.fn_call("open_settings")

func open_savedata_folder() -> void:
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://"))


func _on_reference_pressed() -> void:
	var btn_arr: Array[Button] = [
		ContextPopup.create_button(Translator.translate("Load reference image"),
			FileUtils.open_image_import_dialog.bind(finish_reference_import), false,
			load("res://visual/icons/Reference.svg"), "load_reference"),
		ContextPopup.create_checkbox(Translator.translate("Show reference"),
			toggle_reference_image, reference_texture.visible, "view_show_reference"),
		ContextPopup.create_checkbox(Translator.translate("Overlay reference"),
			toggle_reference_overlay, reference_overlay, "view_overlay_reference")
	]
	
	var reference_popup := ContextPopup.new()
	reference_popup.setup(btn_arr, true)
	HandlerGUI.popup_under_rect_center(reference_popup, reference_button.get_global_rect(),
			get_viewport())

func _on_visuals_button_pressed() -> void:
	var btn_arr: Array[Button] = [
		ContextPopup.create_checkbox(Translator.translate("Show grid"),
				toggle_grid_visuals, grid_visuals.visible, "view_show_grid"),
		ContextPopup.create_checkbox(Translator.translate("Show handles"),
				toggle_handles_visuals, controls.visible, "view_show_handles"),
		ContextPopup.create_checkbox(Translator.translate("Rasterized SVG"),
				toggle_rasterization, viewport.display_texture.rasterized,
				"view_rasterized_svg")]
	
	var visuals_popup := ContextPopup.new()
	visuals_popup.setup(btn_arr, true)
	HandlerGUI.popup_under_rect_center(visuals_popup, visuals_button.get_global_rect(),
			get_viewport())

func _on_more_options_pressed() -> void:
	var can_show_savedata_folder := DisplayServer.has_feature(
				DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	var buttons_arr: Array[Button] = []
	buttons_arr.append(ContextPopup.create_button(Translator.translate(
			"Check for updates"), ShortcutUtils.fn("check_updates"), false,
			load("res://visual/icons/Reload.svg"), "check_updates"))
	
	if can_show_savedata_folder:
		buttons_arr.append(ContextPopup.create_button(Translator.translate(
				"View savedata"), open_savedata_folder , false,
				load("res://visual/icons/OpenFolder.svg")))
	
	var about_btn := ContextPopup.create_button(Translator.translate("About…"),
			ShortcutUtils.fn("about_info"), false, load("res://visual/icon.png"),
			"about_info")
	about_btn.expand_icon = true
	buttons_arr.append(about_btn)
	buttons_arr.append(ContextPopup.create_button(Translator.translate(
			"Donate…"), ShortcutUtils.fn("about_donate"), false,
			load("res://visual/icons/Heart.svg"), "about_donate"))
	buttons_arr.append(ContextPopup.create_button(Translator.translate(
			"GodSVG repository"), ShortcutUtils.fn("about_repo"), false,
			load("res://visual/icons/Link.svg"), "about_repo"))
	buttons_arr.append(ContextPopup.create_button(Translator.translate(
			"GodSVG website"), ShortcutUtils.fn("about_website"), false,
			load("res://visual/icons/Link.svg"), "about_website"))
	var separator_indices := PackedInt32Array([1, 3])
	if can_show_savedata_folder:
		separator_indices = PackedInt32Array([2, 4])
	
	var more_popup := ContextPopup.new()
	more_popup.setup(buttons_arr, true, -1, -1, separator_indices)
	HandlerGUI.popup_under_rect_center(more_popup, more_button.get_global_rect(),
			get_viewport())


func toggle_grid_visuals() -> void:
	grid_visuals.visible = not grid_visuals.visible
	view_settings_updated.emit(grid_visuals.visible, controls.visible,
			viewport.display_texture.rasterized)

func toggle_handles_visuals() -> void:
	controls.visible = not controls.visible
	view_settings_updated.emit(grid_visuals.visible, controls.visible,
			viewport.display_texture.rasterized)

func toggle_rasterization() -> void:
	viewport.display_texture.rasterized = not viewport.display_texture.rasterized
	view_settings_updated.emit(grid_visuals.visible, controls.visible,
			viewport.display_texture.rasterized)

func toggle_reference_image() -> void:
	reference_texture.visible = not reference_texture.visible

func toggle_reference_overlay() -> void:
	reference_overlay = not reference_overlay
	if reference_overlay:
		viewport.move_child(reference_texture, viewport.get_child_count() - 1)
	else:
		viewport.move_child(reference_texture, 0)

func finish_reference_import(data: Variant, path: String) -> void:
	var img := Image.new()
	match path.get_extension().to_lower():
		"svg": img.load_svg_from_string(data)
		"png": img.load_png_from_buffer(data)
		"jpg", "jpeg": img.load_jpg_from_buffer(data)
		"webp": img.load_webp_from_buffer(data)
	reference_texture.texture = ImageTexture.create_from_image(img)
	reference_texture.show()

func toggle_snap() -> void:
	snap_button.button_pressed = not snap_button.button_pressed

func set_snap_amount(snap_value: float) -> void:
	snapper.set_value(snap_value)

func _on_snap_button_toggled(toggled_on: bool) -> void:
	Configs.savedata.snap = absf(Configs.savedata.snap) if toggled_on\
			else -absf(Configs.savedata.snap)

func _on_snap_number_edit_value_changed(new_value: float) -> void:
	Configs.savedata.snap = new_value * signf(Configs.savedata.snap)

# The strings here are intentionally not localized.
func update_debug() -> void:
	var debug_text := ""
	debug_text += "FPS: %s\n" % Performance.get_monitor(Performance.TIME_FPS)
	debug_text += "Static Mem: %s\n" % String.humanize_size(int(Performance.get_monitor(
			Performance.MEMORY_STATIC)))
	debug_text += "Nodes: %s\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	debug_text += "Stray nodes: %s\n" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	debug_text += "Objects: %s\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	debug_label.text = debug_text
	# Set up the next update if the container is still visible.
	if debug_container.visible:
		get_tree().create_timer(1.0).timeout.connect(update_debug)

var last_event_text := ""
var last_event_repeat_count := 1

func _update_input_debug(event: InputEvent) -> void:
	if debug_container.visible and event.is_pressed():
		var new_text := input_debug_label.text
		var event_text := event.as_text()
		if event_text == last_event_text:
			last_event_repeat_count += 1
			new_text = new_text.left(new_text.rfind("\n", new_text.length() - 2) + 1)
			event_text += " (%d)" % last_event_repeat_count
		else:
			last_event_text = event_text
			last_event_repeat_count = 1
		if new_text.count("\n") >= 5:
			new_text = new_text.right(-new_text.find("\n") - 1)
		new_text += event_text + "\n"
		input_debug_label.text = new_text
