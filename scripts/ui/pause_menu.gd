extends CanvasLayer
## In-game pause menu (Esc): Resume + Options -> Audio (Master/Music/SFX volume)
## and Video (resolution, fullscreen, HDR, brightness, VSync). Built entirely in
## code to match the project's procedural-UI style (see hud.gd). Every control is
## wired to SettingsManager, which applies and persists each change immediately.

const ACCENT := Color(0.45, 0.48, 0.52) # matches hud.gd NEUTRAL_THEME

var _open := false
var _root: Control
var _pages: Dictionary = {} # name -> Control
var _current := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_root.visible = false

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _open:
		_go_back()
	elif not RunState.game_over: # the HUD owns the screen while dead
		_open_menu()
	else:
		return
	get_viewport().set_input_as_handled()

# --- open / close / navigation ---

func _open_menu() -> void:
	_open = true
	_root.visible = true
	_show_page("main")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("crosshair", "hide")

func _close_menu() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_tree().call_group("crosshair", "show")

func _go_back() -> void:
	match _current:
		"audio", "video":
			_show_page("options")
		"options":
			_show_page("main")
		_:
			_close_menu()

func _show_page(page_name: String) -> void:
	_current = page_name
	for key in _pages:
		_pages[key].visible = key == page_name

# --- construction ---

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var holder := VBoxContainer.new()
	margin.add_child(holder)

	_pages["main"] = _build_main_page()
	_pages["options"] = _build_options_page()
	_pages["audio"] = _build_audio_page()
	_pages["video"] = _build_video_page()
	for key in _pages:
		holder.add_child(_pages[key])

# --- pages ---

func _build_main_page() -> VBoxContainer:
	var v := _page()
	v.add_child(_title("Paused", 30))
	v.add_child(_spacer(6))
	v.add_child(_button("Resume", _close_menu))
	v.add_child(_button("Options", _show_page.bind("options")))
	v.add_child(_button("Quit", get_tree().quit))
	return v

func _build_options_page() -> VBoxContainer:
	var v := _page()
	v.add_child(_title("Options", 26))
	v.add_child(_spacer(6))
	v.add_child(_button("Audio", _show_page.bind("audio")))
	v.add_child(_button("Video", _show_page.bind("video")))
	v.add_child(_button("Back", _show_page.bind("main")))
	return v

func _build_audio_page() -> VBoxContainer:
	var v := _page()
	v.add_child(_title("Audio", 26))
	v.add_child(_slider_row("Master", SettingsManager.master_volume,
		0.0, 1.0, 0.01, SettingsManager.set_master_volume, true))
	v.add_child(_slider_row("Music", SettingsManager.music_volume,
		0.0, 1.0, 0.01, SettingsManager.set_music_volume, true))
	v.add_child(_slider_row("SFX", SettingsManager.sfx_volume,
		0.0, 1.0, 0.01, SettingsManager.set_sfx_volume, true))
	v.add_child(_spacer(6))
	v.add_child(_button("Back", _show_page.bind("options")))
	return v

func _build_video_page() -> VBoxContainer:
	var v := _page()
	v.add_child(_title("Video", 26))

	var res_row := _labeled_row("Resolution")
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 16)
	# The popup is shown while the tree is paused, so it must process then too.
	opt.get_popup().process_mode = Node.PROCESS_MODE_ALWAYS
	for res in SettingsManager.RESOLUTIONS:
		opt.add_item("%d x %d" % [res.x, res.y])
	var cur: int = SettingsManager.RESOLUTIONS.find(SettingsManager.resolution)
	opt.selected = cur if cur >= 0 else 0
	opt.item_selected.connect(func(i: int) -> void:
		SettingsManager.set_resolution(SettingsManager.RESOLUTIONS[i]))
	res_row.add_child(opt)
	v.add_child(res_row)

	v.add_child(_check_row("Fullscreen", SettingsManager.fullscreen,
		SettingsManager.set_fullscreen))
	v.add_child(_check_row("HDR", SettingsManager.hdr, SettingsManager.set_hdr))
	v.add_child(_check_row("VSync", SettingsManager.vsync, SettingsManager.set_vsync))
	v.add_child(_slider_row("Brightness", SettingsManager.brightness,
		0.5, 1.5, 0.01, SettingsManager.set_brightness, false))
	v.add_child(_spacer(6))
	v.add_child(_button("Back", _show_page.bind("options")))
	return v

# --- widget builders ---

func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(400, 0)
	return v

func _title(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(callback)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(ACCENT.r * 0.28, ACCENT.g * 0.28, ACCENT.b * 0.28, 0.9)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(ACCENT.r * 0.45, ACCENT.g * 0.45, ACCENT.b * 0.45, 0.95)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(ACCENT.r * 0.16, ACCENT.g * 0.16, ACCENT.b * 0.16, 0.95)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

## An HBox with a left-aligned label that expands, ready for a control on the
## right (added by the caller).
func _labeled_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

func _slider_row(text: String, value: float, min_v: float, max_v: float,
		step: float, setter: Callable, percent: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var val_label := Label.new()
	val_label.custom_minimum_size = Vector2(56, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.text = _format_value(value, percent)
	row.add_child(val_label)
	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = _format_value(v, percent)
		setter.call(v))
	return row

func _check_row(text: String, value: bool, setter: Callable) -> HBoxContainer:
	var row := _labeled_row(text)
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(on: bool) -> void: setter.call(on))
	row.add_child(check)
	return row

func _format_value(value: float, percent: bool) -> String:
	return "%d%%" % roundi(value * 100.0) if percent else "%.2f" % value

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(ACCENT.r * 0.18, ACCENT.g * 0.18, ACCENT.b * 0.18, 0.96)
	s.border_color = ACCENT
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s
