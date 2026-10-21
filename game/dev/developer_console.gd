class_name DeveloperConsole
extends CanvasLayer
## In-game console mounted only by development builds.

var run: RoomRunSession
var runner: DeveloperCommandRunner = DeveloperCommandRunner.new()
var is_open: bool = false
var _resume_on_close: bool = false
var _history: PackedStringArray = []
var _command_history: PackedStringArray = []
var _history_index: int = 0

@onready var panel: PanelContainer = %ConsolePanel
@onready var output: RichTextLabel = %Output
@onready var entry: LineEdit = %Entry
@onready var hint: Label = %Hint


func _ready() -> void:
	panel.visible = false
	entry.text_submitted.connect(_on_text_submitted)
	entry.gui_input.connect(_on_entry_input)
	_append("Dead Circuit development console. Enter help for commands.")


func configure(value: RoomRunSession) -> void:
	run = value
	runner.configure(run)
	if not run.run_started.is_connected(_on_run_started):
		run.run_started.connect(_on_run_started)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_QUOTELEFT, KEY_F10]:
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and key.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	panel.visible = is_open
	hint.visible = not is_open
	if is_open:
		_resume_on_close = (
			is_instance_valid(run)
			and is_instance_valid(run.combat)
			and run.combat.state == CombatSession.State.ACTIVE
			and not run.combat.paused
		)
		if _resume_on_close:
			run.combat.set_paused(true)
		entry.grab_focus.call_deferred()
	else:
		entry.release_focus()
		if (
			_resume_on_close
			and is_instance_valid(run)
			and is_instance_valid(run.combat)
			and run.combat.state == CombatSession.State.ACTIVE
		):
			run.combat.set_paused(false)
		_resume_on_close = false


func execute_command(command_line: String) -> String:
	var stripped: String = command_line.strip_edges()
	if stripped.is_empty():
		return ""
	if stripped.to_lower() == "clear":
		_history.clear()
		output.text = ""
		return ""
	_command_history.append(stripped)
	if _command_history.size() > 50:
		_command_history.remove_at(0)
	_history_index = _command_history.size()
	_append("> %s" % stripped)
	var result: String = runner.execute(stripped)
	if not result.is_empty():
		_append(result)
	return result


func _on_text_submitted(command_line: String) -> void:
	entry.clear()
	execute_command(command_line)
	entry.grab_focus.call_deferred()


func _on_run_started() -> void:
	if is_open and run.combat.state == CombatSession.State.ACTIVE:
		_resume_on_close = true
		run.combat.set_paused(true)


func _on_entry_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo or _command_history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_index = maxi(0, _history_index - 1)
		entry.text = _command_history[_history_index]
		entry.caret_column = entry.text.length()
		entry.accept_event()
	elif key.keycode == KEY_DOWN:
		_history_index = mini(_command_history.size(), _history_index + 1)
		entry.text = (
			"" if _history_index == _command_history.size() else _command_history[_history_index]
		)
		entry.caret_column = entry.text.length()
		entry.accept_event()


func _append(message: String) -> void:
	_history.append(message)
	if _history.size() > 100:
		_history.remove_at(0)
	output.text = "\n".join(_history)
	output.scroll_to_line.call_deferred(maxi(0, output.get_line_count() - 1))
