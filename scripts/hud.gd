extends CanvasLayer
## In-game HUD. Retints its panels to the current chair's color while seated,
## shows the weapon inventory and the burning passive bars, and handles the
## restart input (it stays active while the tree is paused).

const NEUTRAL_THEME := Color(0.45, 0.48, 0.52)
const PASSIVE_BAR_SCENE := preload("res://scenes/ui/passive_bar.tscn")

@onready var top_left_panel: PanelContainer = %TopLeftPanel
@onready var top_right_panel: PanelContainer = %TopRightPanel
@onready var hp_bar: ProgressBar = %HpBar
@onready var passives_box: VBoxContainer = %PassivesBox
@onready var time_label: Label = %TimeLabel
@onready var kills_label: Label = %KillsLabel
@onready var hint_label: Label = %HintLabel
@onready var weapon_panel: PanelContainer = %WeaponPanel
@onready var weapon_label: Label = %WeaponLabel
@onready var carried_label: Label = %CarriedLabel
@onready var chair_panel: PanelContainer = %ChairPanel
@onready var chair_name_label: Label = %ChairNameLabel
@onready var chair_hp_bar: ProgressBar = %ChairHpBar
@onready var meter_bar: ProgressBar = %MeterBar
@onready var secondary_label: Label = %SecondaryLabel
@onready var toast_label: Label = %ToastLabel
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_stats: Label = %GameOverStats

var _player: Player
var _toast_tween: Tween
var _passive_bars := {}

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_player.hp_changed.connect(_on_player_hp_changed)
	_player.seated_on.connect(_on_seated)
	_player.stood_up.connect(_on_stood_up)
	_player.near_chair_changed.connect(_on_near_chair_changed)
	_player.died.connect(_on_player_died)
	_player.weapons_changed.connect(_refresh_weapons)
	_player.pickup_rejected.connect(func() -> void: _toast("WEAPONS FULL"))
	RunState.passive_granted.connect(_on_passive_granted)
	RunState.passive_expired.connect(_on_passive_expired)
	RunState.passives_changed.connect(_sync_passive_bars)
	RunState.kills_changed.connect(_on_kills_changed)
	hp_bar.max_value = Player.MAX_HP
	hp_bar.value = _player.hp
	_style_bar(hp_bar, Color(0.85, 0.25, 0.25))
	_style_bar(meter_bar, Color(1.0, 0.8, 0.2))
	_style_bar(chair_hp_bar, NEUTRAL_THEME)
	chair_panel.visible = false
	hint_label.visible = false
	game_over_panel.visible = false
	toast_label.modulate.a = 0.0
	_apply_theme(NEUTRAL_THEME)
	_refresh_weapons()
	_sync_passive_bars()

func _process(_delta: float) -> void:
	time_label.text = _format_time(RunState.run_time)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_player_hp_changed(hp: float, _max_hp: float) -> void:
	hp_bar.value = hp

func _on_seated(chair: Chair) -> void:
	chair_panel.visible = true
	hint_label.visible = false
	chair_name_label.text = chair.data.display_name
	chair_hp_bar.max_value = chair.data.max_hp
	chair_hp_bar.value = chair.hp
	meter_bar.max_value = chair.data.meter_time
	meter_bar.value = chair.meter
	chair.hp_changed.connect(func(hp: float, _max_hp: float) -> void: chair_hp_bar.value = hp)
	chair.meter_changed.connect(func(value: float, _max_value: float) -> void: meter_bar.value = value)
	chair.secondary_changed.connect(_on_secondary_changed)
	secondary_label.visible = chair.data.secondary_id != &""
	if secondary_label.visible:
		_on_secondary_changed(chair.secondary_cooldown_left, chair.secondary_uses_left)
	_style_bar(chair_hp_bar, chair.data.color)
	_apply_theme(chair.data.color)

func _on_stood_up() -> void:
	chair_panel.visible = false
	_apply_theme(NEUTRAL_THEME)

func _on_secondary_changed(cooldown_left: float, uses_left: int) -> void:
	var chair := _player.current_chair
	if chair == null:
		return
	var parts: Array[String] = ["RMB: %s" % String(chair.data.secondary_id).capitalize()]
	if uses_left >= 0:
		parts.append("%d uses" % uses_left)
	if uses_left == 0:
		parts.append("spent")
	elif cooldown_left > 0.0:
		parts.append("%.1fs" % cooldown_left)
	else:
		parts.append("ready")
	secondary_label.text = "  •  ".join(parts)

func _on_near_chair_changed(chair: Chair) -> void:
	hint_label.visible = chair != null
	if chair:
		hint_label.text = "Press E to sit on the %s" % chair.data.display_name

func _refresh_weapons() -> void:
	var weapon := _player.current_weapon()
	if weapon.is_empty():
		weapon_label.text = "Unarmed"
		carried_label.text = "Find a weapon!"
		return
	weapon_label.text = "%s  %d / %d" % [weapon.data.display_name, weapon.ammo, weapon.data.max_ammo]
	var lines: Array[String] = []
	for i in _player.weapons.size():
		var entry: Dictionary = _player.weapons[i]
		var marker := "> " if i == _player.current_weapon_index else "   "
		lines.append("%s%s (%d)" % [marker, entry.data.display_name, entry.ammo])
	carried_label.text = "\n".join(lines)

func _sync_passive_bars() -> void:
	for id in RunState.passives:
		if id not in _passive_bars:
			var bar: PassiveBar = PASSIVE_BAR_SCENE.instantiate()
			bar.passive_id = id
			passives_box.add_child(bar)
			_passive_bars[id] = bar
	for id in _passive_bars.keys():
		if id not in RunState.passives:
			_passive_bars[id].queue_free()
			_passive_bars.erase(id)

func _on_passive_granted(passive_id: StringName, level: int) -> void:
	_sync_passive_bars()
	_toast("%s Lv%d" % [RunState.passive_name(passive_id).to_upper(), level])

func _on_passive_expired(passive_id: StringName) -> void:
	_toast("%s burned out" % RunState.passive_name(passive_id))

func _on_kills_changed(kills: int) -> void:
	kills_label.text = "Kills: %d" % kills

func _on_player_died() -> void:
	game_over_panel.visible = true
	game_over_stats.text = "You survived %s\nKills: %d" % [_format_time(RunState.run_time), RunState.kills]

func _toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)

func _apply_theme(color: Color) -> void:
	for panel in [top_left_panel, top_right_panel, weapon_panel, chair_panel, game_over_panel]:
		panel.add_theme_stylebox_override("panel", _make_panel_style(color))
	hint_label.add_theme_color_override("font_color", color.lightened(0.4))

func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.9)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	return style

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.45)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
