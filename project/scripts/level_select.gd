class_name LevelSelect
extends MarginContainer
## The list of the 40 levels: size or stars for each, a padlock on the ones not open yet.

signal chosen(level: int)
signal back

const BUTTON_SIZE := Vector2(84, 76)
const GAP := 12
## Space kept free below the list, so neither its last row nor its scroll bar sits under the round button
## the host page puts in the bottom-right corner (32 px at 16 px from the corner: 59 units on a phone).
const BOTTOM_CLEAR := 64

var _grid: GridContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		add_theme_constant_override("margin_" + side, 22)
	add_theme_constant_override("margin_bottom", BOTTOM_CLEAR)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.add_child(Ui.button("‹ Menu", back.emit))
	var title := Ui.label("Levels", 28)
	header.add_child(title)
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(center)
	inner.add_child(Ui.spacer(8))
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	center.add_child(_grid)
	for level in range(1, Levels.COUNT + 1):
		_grid.add_child(_level_button(level))
	resized.connect(_fit_columns)


func _level_button(level: int) -> Button:
	var button := Ui.button("", chosen.emit.bind(level))
	button.custom_minimum_size = BUTTON_SIZE
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	var number := Ui.label(str(level), 20)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := Ui.label("", 14, Ui.MUTED)
	detail.name = "Detail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := Stars.new(0, 14.0)
	row.name = "Stars"
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var padlock := LockIcon.new(16.0)
	padlock.name = "Lock"
	padlock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(number)
	content.add_child(detail)
	content.add_child(row)
	content.add_child(padlock)
	button.add_child(content)
	return button


## Shows the player's stars and which levels are open, and focuses the next level to play.
func refresh(progress: Progress) -> void:
	var next := progress.next_level()
	for level in range(1, Levels.COUNT + 1):
		var button: Button = _grid.get_child(level - 1)
		var star_count := progress.stars(level)
		var level_size := Levels.size_of(level)
		var content := button.get_child(0)
		var row: Stars = content.get_node("Stars")
		var detail: Label = content.get_node("Detail")
		var padlock: LockIcon = content.get_node("Lock")
		button.disabled = level > next
		row.filled = star_count
		row.visible = star_count > 0
		detail.text = "%d×%d" % [level_size.x, level_size.y]
		detail.visible = star_count == 0 and not button.disabled
		padlock.visible = button.disabled
		button.modulate = Color(1, 1, 1, 0.5) if button.disabled else Color.WHITE
		if button.disabled:
			button.tooltip_text = "Level %d, %d×%d, locked: solve level %d first" % [level, level_size.x, level_size.y, level - 1]
		else:
			button.tooltip_text = "Level %d, %d×%d, %d of 3 stars" % [level, level_size.x, level_size.y, star_count]
	_fit_columns()
	Ui.focus_later(_grid.get_child(clampi(next, 1, Levels.COUNT) - 1) as Button)


func _fit_columns() -> void:
	var width := size.x if size.x > 0.0 else get_viewport_rect().size.x
	_grid.columns = clampi(int((width - 44 + GAP) / (BUTTON_SIZE.x + GAP)), 3, 8)
