class_name Dialog
extends Control
## A panel over the dimmed screen: the results of a board and "How to play".

## True when Esc may close it (How to play); results stay until a button is chosen.
var closable := false
var _box: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.09, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	margin.add_child(_box)


## Shows `heading`, `star_count` stars (none when negative), `lines` of text and `buttons`, each
## [text, action, primary]. The first button takes the focus.
func open(heading: String, star_count: int, lines: Array[String], buttons: Array, can_close: bool) -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	closable = can_close
	var title := Ui.label(heading, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if star_count >= 0:
		var row := Stars.new(star_count, 44.0)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(row)
	for line in lines:
		var text := Ui.label(line, 17, Ui.MUTED)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(330, 0)
		_box.add_child(text)
	_box.add_child(Ui.spacer(4))
	var first: Button = null
	for entry: Array in buttons:
		var button := Ui.button(entry[0], entry[1])
		if entry[2]:
			Ui.accent(button)
		_box.add_child(button)
		if first == null:
			first = button
	visible = true
	if first:
		first.grab_focus.call_deferred()


## For the tests: the heading of the open dialog, or "" when it is closed.
func heading() -> String:
	if not visible or _box.get_child_count() == 0:
		return ""
	return (_box.get_child(0) as Label).text
