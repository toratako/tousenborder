extends Control
## Composes services and screens; owns navigation and completed-session persistence.
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const WrongAnswerRetry = preload("res://src/app/wrong_answer_retry.gd")
@export_dir var content_root := "res://data"
const Workspace = preload("res://src/ui/inspection/inspection_workspace.gd")
var workspace: Workspace
const StartScreen = preload("res://src/ui/screens/start_screen.gd")
var start_screen: StartScreen
const ToolGuide = preload("res://src/ui/screens/tool_guide_screen.gd")
var tool_guide: ToolGuide
const LicenseScreen = preload("res://src/ui/screens/license_screen.gd")
var license_overlay: LicenseScreen
const SummaryScreen = preload("res://src/ui/results/summary_screen.gd")
var summary_screen: SummaryScreen
const HistoryScreen = preload("res://src/ui/screens/history_screen.gd")
var history_overlay: HistoryScreen
const HowToPanel = preload("res://src/ui/help/how_to_panel.gd")
var how_to_overlay: HowToPanel
const RulesPanel = preload("res://src/ui/help/rules_panel.gd")
var rules_overlay: RulesPanel
const GlossaryPanel = preload("res://src/ui/help/glossary_panel.gd")
var glossary_overlay: GlossaryPanel
const PauseMenu = preload("res://src/ui/inspection/pause_menu.gd")
var pause_menu: PauseMenu
const AuditPanel = preload("res://src/ui/inspection/audit_panel.gd")
var audit_overlay: AuditPanel
const ExternalPreview = preload("res://src/ui/inspection/external_preview.gd")
var external_preview: ExternalPreview

var library := ProblemLibrary.new()
var import_store := ContentImportStore.new()
var actions: Array[Dictionary] = ContentLabels.actions()
var feedback := {
	"correct_heading": "対象の判定：正解",
	"incorrect_heading": "対象の判定：誤判定",
	"show_reason": true,
	"show_expected": true,
}
var rules: Array[Dictionary] = []
var shift := InspectionShift.new()
var rules_previous_focus: Control
var how_to_previous_focus: Control
var menu_previous_focus: Control
var pending_external: Dictionary = { }
var glossary_previous_focus: Control
var history_store := HistoryStore.new()
var completed_snapshot: Dictionary = { }
var summary_from_history := false
var retry_cases: Array[Dictionary] = []
var retry_source_id := ""


func _ready() -> void:
	theme = Chrome.create(preload("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	rules.assign(JSON.parse_string(FileAccess.get_file_as_string("res://data/help/rules.json")))
	library.load_builtin(content_root)
	var import_errors := library.errors.duplicate()
	for source in import_store.sources():
		var prepared := library.prepare_source(source)
		if prepared.errors.is_empty():
			library.commit_source(prepared)
		else:
			import_errors.append_array(prepared.errors)
	workspace = Workspace.new()
	add_child(workspace)
	workspace.setup(
		shift,
		actions,
		_investigation_paused,
		func():
			return glossary_overlay.visible,
	)
	workspace.categories = library.categories
	workspace.menu_requested.connect(_toggle_menu)
	workspace.how_to_requested.connect(_open_how_to)
	workspace.rules_requested.connect(_open_rules)
	workspace.glossary_requested.connect(_open_glossary)
	workspace.cleared.connect(_clear_case_help)
	workspace.case_presented.connect(_on_case_presented)
	workspace.result_viewed.connect(_on_result_viewed)
	workspace.external_requested.connect(_preview_external)
	workspace.refresh_started.connect(_hide_audit)
	workspace.audit_requested.connect(_show_audit)
	workspace.completed.connect(_show_summary)
	audit_overlay = AuditPanel.new()
	add_child(audit_overlay)
	audit_overlay.setup()
	audit_overlay.continued.connect(shift.advance)
	start_screen = StartScreen.new()
	add_child(start_screen)
	start_screen.setup(library)
	start_screen.start_requested.connect(_start_shift)
	start_screen.guide_requested.connect(_show_tool_guide)
	start_screen.licenses_requested.connect(_show_licenses)
	start_screen.history_requested.connect(_show_history)
	start_screen.import_requested.connect(_import_content)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup()
	pause_menu.resume_requested.connect(_close_menu)
	pause_menu.restart_requested.connect(_start_shift)
	pause_menu.home_requested.connect(_show_start_screen)
	rules_overlay = RulesPanel.new()
	add_child(rules_overlay)
	rules_overlay.setup(rules)
	rules_overlay.closed.connect(_close_rules)
	how_to_overlay = HowToPanel.new()
	add_child(how_to_overlay)
	how_to_overlay.setup()
	how_to_overlay.closed.connect(_close_how_to)
	external_preview = ExternalPreview.new()
	add_child(external_preview)
	external_preview.setup()
	external_preview.decided.connect(_finish_external)
	glossary_overlay = GlossaryPanel.new()
	add_child(glossary_overlay)
	glossary_overlay.setup()
	glossary_overlay.closed.connect(_close_glossary)
	history_overlay = HistoryScreen.new()
	add_child(history_overlay)
	history_overlay.setup()
	history_overlay.closed.connect(_close_history)
	history_overlay.entry_requested.connect(_open_history_entry)
	_show_start_screen()
	if not library.errors.is_empty() or not import_errors.is_empty():
		start_screen.content_notice.text = "一部の教材を読み込めませんでした。"
		start_screen.content_notice.tooltip_text = "\n".join(import_errors)
	start_screen.tool_guide_button.disabled = library.cases.is_empty()


func _investigation_paused() -> bool:
	return (
		pause_menu.visible or rules_overlay.visible or how_to_overlay.visible
		or external_preview.visible or glossary_overlay.visible
	)


func _process(delta: float) -> void:
	workspace.refresh_hover_targets()
	if not workspace.playing or _investigation_paused():
		return
	shift.tick(delta)
	workspace.refresh_elapsed_time()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if glossary_overlay.visible:
			_close_glossary()
		elif summary_from_history and is_instance_valid(summary_screen):
			_back_to_history()
		elif history_overlay.visible:
			_close_history()
		else:
			_handle_inspection_input(event)
			return
		get_viewport().set_input_as_handled()
		return
	_handle_inspection_input(event)


func _handle_inspection_input(event: InputEvent) -> void:
	if is_instance_valid(how_to_overlay) and how_to_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if not event.is_echo():
				_close_how_to()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			if not event.is_echo():
				how_to_overlay.change_slide(-1 if event.is_action_pressed("ui_left") else 1)
		return
	if (
		is_instance_valid(rules_overlay) and rules_overlay.visible
		and event.is_action_pressed("ui_cancel")
	):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_close_rules()
		return
	if (
		is_instance_valid(external_preview) and external_preview.visible
		and event.is_action_pressed("ui_cancel")
	):
		get_viewport().set_input_as_handled()
		_finish_external(false)
		return
	if workspace.playing and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_toggle_menu()


func _toggle_menu() -> void:
	if (
		not workspace.playing or rules_overlay.visible or how_to_overlay.visible
		or glossary_overlay.visible
	):
		return
	if pause_menu.visible:
		_close_menu()
		return
	workspace.stop_dragging()
	menu_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(pause_menu, -1)
	pause_menu.show()
	pause_menu.resume_button.grab_focus()


func _close_menu() -> void:
	if not is_instance_valid(pause_menu) or not pause_menu.visible:
		return
	pause_menu.hide()
	if is_instance_valid(menu_previous_focus) and menu_previous_focus.is_visible_in_tree():
		menu_previous_focus.grab_focus()
	else:
		workspace.menu_button.grab_focus()
	menu_previous_focus = null


func _show_tool_guide() -> void:
	if (
		workspace.playing or not start_screen.visible
		or (is_instance_valid(license_overlay) and license_overlay.visible)
	):
		return
	if not is_instance_valid(tool_guide):
		tool_guide = ToolGuide.new()
		add_child(tool_guide)
		tool_guide.setup(library.guide_tools(), library.categories)
		tool_guide.closed.connect(_close_tool_guide)
	start_screen.hide()
	tool_guide.body.scroll_to_line(0)
	tool_guide.show()
	tool_guide.close_button.grab_focus()


func _close_tool_guide() -> void:
	tool_guide.hide()
	start_screen.show()
	start_screen.tool_guide_button.grab_focus()


func _show_licenses() -> void:
	if workspace.playing or not start_screen.visible:
		return
	if not is_instance_valid(license_overlay):
		license_overlay = LicenseScreen.new()
		add_child(license_overlay)
		license_overlay.setup()
		license_overlay.closed.connect(_close_licenses)
	start_screen.start_button.disabled = true
	start_screen.tool_guide_button.disabled = true
	start_screen.license_button.disabled = true
	license_overlay.select_license(0)
	license_overlay.show()
	license_overlay.close_button.grab_focus()


func _close_licenses() -> void:
	license_overlay.hide()
	start_screen.refresh_selection()
	start_screen.tool_guide_button.disabled = library.cases.is_empty()
	start_screen.license_button.disabled = false
	start_screen.license_button.grab_focus()


func _close_summary() -> void:
	if is_instance_valid(summary_screen):
		summary_screen.hide()
		summary_screen.queue_free()
		summary_screen = null


func _show_start_screen() -> void:
	retry_cases.clear()
	retry_source_id = ""
	summary_from_history = false
	_close_glossary(false)
	glossary_overlay.reset()
	history_overlay.hide()
	_close_how_to(false)
	_close_rules(false)
	_clear_external()
	_close_menu()
	workspace.playing = false
	workspace.stamp_pending = false
	workspace.desk_generation += 1
	_close_summary()
	audit_overlay.hide()
	workspace.hide()
	start_screen.show()
	start_screen.start_button.grab_focus()


func _start_shift() -> void:
	if library.cases.is_empty() or history_overlay.visible:
		return
	if is_instance_valid(tool_guide) and tool_guide.visible:
		return
	if is_instance_valid(license_overlay) and license_overlay.visible:
		return
	var selected := start_screen.selected_cases() if retry_source_id.is_empty() else retry_cases
	if selected.is_empty():
		return
	_begin_shift(selected)


func _retry_wrong_answers() -> void:
	var plan := WrongAnswerRetry.plan(summary_screen.snapshot, library)
	if plan.cases.is_empty():
		return
	retry_cases.assign(plan.cases)
	retry_source_id = summary_screen.snapshot.session_id
	_begin_shift(retry_cases)


func _retry_same_cases() -> void:
	retry_cases.assign(shift.cases)
	retry_source_id = summary_screen.snapshot.session_id
	_start_shift()


func _begin_shift(selected: Array[Dictionary]) -> void:
	workspace.displayed_index = -1
	completed_snapshot.clear()
	summary_from_history = false
	history_overlay.hide()
	_close_how_to(false)
	_close_rules(false)
	_close_menu()
	_close_summary()
	start_screen.hide()
	workspace.show()
	workspace.playing = true
	workspace.clear_case()
	shift.start(selected)
	workspace.menu_button.grab_focus()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("070e1b"))
	for y in range(16, 800, 32):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("112336"), 1)
	for x in range(0, 1280, 32):
		draw_line(Vector2(x, 0), Vector2(x, 800), Color("112336"), 1)


func _open_how_to() -> void:
	if not workspace.playing or shift.finished() or shift.judged or _investigation_paused():
		return
	workspace.stop_dragging()
	how_to_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(how_to_overlay, -1)
	how_to_overlay.change_slide(0)
	how_to_overlay.show()
	how_to_overlay.close_button.grab_focus()


func _close_how_to(restore_focus := true) -> void:
	if not is_instance_valid(how_to_overlay) or not how_to_overlay.visible:
		return
	how_to_overlay.hide()
	if restore_focus:
		if is_instance_valid(how_to_previous_focus) and how_to_previous_focus.is_visible_in_tree():
			how_to_previous_focus.grab_focus()
		else:
			workspace.how_to_button.grab_focus()
	how_to_previous_focus = null


func _open_rules() -> void:
	if not workspace.playing or shift.finished() or shift.judged or _investigation_paused():
		return
	workspace.stop_dragging()
	rules_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(rules_overlay, -1)
	rules_overlay.body.scroll_to_line(0)
	rules_overlay.show()
	rules_overlay.close_button.grab_focus()


func _close_rules(restore_focus := true) -> void:
	if not is_instance_valid(rules_overlay) or not rules_overlay.visible:
		return
	rules_overlay.hide()
	if restore_focus:
		if is_instance_valid(rules_previous_focus) and rules_previous_focus.is_visible_in_tree():
			rules_previous_focus.grab_focus()
		else:
			workspace.rules_button.grab_focus()
	rules_previous_focus = null


func _clear_external() -> void:
	pending_external.clear()
	if is_instance_valid(external_preview):
		external_preview.hide()


func _finish_external(submit: bool) -> void:
	if pending_external.is_empty():
		return
	var pending := pending_external.duplicate(true)
	_clear_external()
	if (
		pending.generation != workspace.desk_generation
		or not workspace.playing or shift.finished() or shift.judged
	):
		return
	if submit:
		shift.inspect(pending.tool, pending.input)
	else:
		shift.decline_external(pending.tool, pending.input)
	for button in workspace.tool_buttons:
		if button.tool.id == pending.tool.id:
			button.grab_focus()
			break


func _show_audit(record: Dictionary, after_stamp := false) -> void:
	_close_glossary(false)
	audit_overlay.present(record, feedback, actions, shift.index == shift.cases.size() - 1)
	if after_stamp and pause_menu.visible:
		pause_menu.resume_button.grab_focus()


func _show_summary() -> void:
	_close_glossary(false)
	_close_how_to(false)
	_close_rules(false)
	if is_instance_valid(summary_screen):
		return
	_clear_external()
	for button in workspace.tool_buttons:
		button.disabled = true
	if completed_snapshot.is_empty():
		var selection := { }
		for pair in [
			["level", start_screen.difficulty_select],
			["category", start_screen.category_select],
			["platform", start_screen.platform_select],
		]:
			var option: OptionButton = pair[1]
			selection[pair[0]] = {
				"id": option.get_item_metadata(option.selected),
				"label": option.get_item_text(option.selected),
			}
		if (
			not retry_source_id.is_empty()
			or not str(
				start_screen.pack_select.get_item_metadata(start_screen.pack_select.selected)
			).is_empty()
		):
			selection = WrongAnswerRetry.selection(shift.cases, library)
		completed_snapshot = HistoryStore.snapshot(
			shift,
			_session_pack(),
			selection,
			feedback,
			actions,
		)
		if not retry_source_id.is_empty() and not completed_snapshot.is_empty():
			completed_snapshot.retry_of = retry_source_id
	if completed_snapshot.is_empty():
		return
	_display_summary(completed_snapshot, false)
	_save_summary()
	audit_overlay.next_button.visible = false
	for stamp in workspace.action_stamps:
		stamp.hide()
		stamp.disabled = true
	workspace.tool_message.text = "勤務終了。案件を振り返るか、同じ問題に再挑戦してください。"
	summary_screen.restart.grab_focus()


func _save_summary() -> void:
	if summary_from_history or completed_snapshot.is_empty():
		return
	var saved := history_store.save_completed(completed_snapshot)
	summary_screen.show_save_result(saved, history_store.error)


func _open_glossary() -> void:
	if not workspace.playing or shift.finished() or shift.judged or _investigation_paused():
		return
	workspace.stop_dragging()
	glossary_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(glossary_overlay, -1)
	glossary_overlay.show_terms(shift.current(), workspace.active_tools)
	workspace.refresh_controls(shift.current())


func _close_glossary(restore_focus := true) -> void:
	if not is_instance_valid(glossary_overlay) or not glossary_overlay.visible:
		return
	glossary_overlay.scroll_position = glossary_overlay.scroll.scroll_vertical
	glossary_overlay.hide()
	if workspace.playing and not shift.finished():
		workspace.refresh_controls(shift.current())
	if restore_focus:
		if (
			is_instance_valid(glossary_previous_focus)
			and glossary_previous_focus.is_visible_in_tree()
		):
			glossary_previous_focus.grab_focus()
		else:
			workspace.glossary_button.grab_focus()
	glossary_previous_focus = null


func _show_history() -> void:
	if (
		workspace.playing or not start_screen.visible
		or (is_instance_valid(license_overlay) and license_overlay.visible)
	):
		return
	start_screen.hide()
	_refresh_history()


func _refresh_history() -> void:
	var entries := history_store.list_summaries()
	history_overlay.show_entries(entries, history_store.warnings)


func _open_history_entry(id: String) -> void:
	var snapshot := history_store.load_entry(id)
	if snapshot.is_empty():
		history_overlay.notice.text = "履歴を読み込めませんでした。"
		history_overlay.notice.tooltip_text = history_store.error
		return
	history_overlay.hide()
	_display_summary(snapshot, true)


func _back_to_history() -> void:
	_close_summary()
	summary_from_history = false
	_refresh_history()


func _close_history() -> void:
	history_overlay.hide()
	start_screen.show()
	start_screen.history_button.grab_focus()


func _import_content(path: String) -> void:
	if workspace.playing:
		return
	var source := ContentSource.open_file(path)
	var prepared := library.prepare_source(source)
	var errors: PackedStringArray = prepared.errors
	if errors.is_empty() and not import_store.save(source):
		errors.append(import_store.error)
	if not errors.is_empty():
		start_screen.content_notice.text = "教材を追加できませんでした。"
		start_screen.content_notice.tooltip_text = "\n".join(errors)
		return
	library.commit_source(prepared)
	start_screen.content_notice.text = "教材を追加しました。"
	start_screen.content_notice.tooltip_text = path.get_file()
	start_screen.refresh_options()
	start_screen.tool_guide_button.disabled = false
	if is_instance_valid(tool_guide):
		tool_guide.queue_free()
		tool_guide = null


func _session_pack() -> Dictionary:
	var key: String = start_screen.pack_select.get_item_metadata(start_screen.pack_select.selected)
	for pack in library.packs:
		if pack.key == key:
			return { "id": pack.key, "title": pack.title, "path": pack.source_id + "/" + pack.path }
	return { "id": "freeplay", "title": "自由演習", "path": content_root }


func _display_summary(snapshot: Dictionary, from_history: bool) -> void:
	_close_summary()
	summary_from_history = from_history
	summary_screen = SummaryScreen.new()
	add_child(summary_screen)
	var retry := WrongAnswerRetry.plan(snapshot, library)
	summary_screen.setup(snapshot, from_history, retry.cases.size(), retry.reason)
	summary_screen.back_requested.connect(_back_to_history if from_history else _show_start_screen)
	summary_screen.retry_wrong_requested.connect(_retry_wrong_answers)
	summary_screen.restart_requested.connect(_retry_same_cases)
	summary_screen.save_requested.connect(_save_summary)


func _clear_case_help() -> void:
	_close_glossary(false)
	glossary_overlay.reset()
	_close_how_to(false)
	_close_rules(false)
	_clear_external()


func _hide_audit() -> void:
	audit_overlay.hide()
	audit_overlay.next_button.visible = shift.judged and not workspace.stamp_pending


func _on_case_presented(item: Dictionary) -> void:
	glossary_overlay.viewed[LearningGlossary.key("initial_information", "initial")] = true
	for tool in workspace.active_tools:
		if ProblemContext.supports_target(tool, item):
			glossary_overlay.viewed[LearningGlossary.key(tool.id, "overview")] = true


func _on_result_viewed(tool_id: String) -> void:
	glossary_overlay.viewed[LearningGlossary.key(tool_id, "result")] = true


func _preview_external(tool: Dictionary, actual_input: Dictionary, generation: int) -> void:
	pending_external = {
		"tool": tool,
		"input": actual_input.duplicate(true),
		"generation": generation,
	}
	external_preview.present(tool, actual_input)
	glossary_overlay.viewed[LearningGlossary.key(tool.id, "submission")] = true
	external_preview.skip_button.grab_focus()
