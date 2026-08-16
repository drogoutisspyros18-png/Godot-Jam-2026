extends Node
## Node for opening a pause menu when detecting a 'ui_cancel' event.

@export var pause_menu_packed: PackedScene
@export var focused_viewport: Viewport

var pause_menu: Node


func _ready() -> void:
	pause_menu = pause_menu_packed.instantiate()
	pause_menu.hide()

	# 1. Create a CanvasLayer dynamically
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # Give it a high layer number so it renders on top of everything

	# 2. Add the pause menu to the CanvasLayer
	canvas_layer.add_child(pause_menu)

	# 3. Add the CanvasLayer (which now holds your menu) to the current scene
	get_tree().current_scene.call_deferred("add_child", canvas_layer)


# If pause menu should take precedence, override _input() instead.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause()


func pause() -> void:
	if pause_menu.visible:
		return
	if not focused_viewport:
		focused_viewport = get_viewport()
	var _initial_focus_control = focused_viewport.gui_get_focus_owner()
	pause_menu.show()
	if pause_menu is CanvasLayer:
		await pause_menu.visibility_changed
	else:
		await pause_menu.hidden
	if is_inside_tree() and _initial_focus_control:
		_initial_focus_control.grab_focus()
