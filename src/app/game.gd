extends Control
## 画面遷移と操作を調整する。教材・判定はcore、部品の配置はdesk_layoutが担当。

const Layout = preload("res://src/ui/inspection/desk_layout.gd")
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const Analysis = preload("res://src/domain/result_analysis.gd")
const AnalysisView = preload("res://src/ui/results/result_analysis_view.gd")
const WrongAnswerRetry = preload("res://src/app/wrong_answer_retry.gd")

@export_dir var content_root := "res://data"

const PAPER = Layout.PAPER
const INK = Layout.INK
const MUTED = Layout.MUTED
const GREEN = Layout.GREEN
const RED = Layout.RED
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
var glossary_terms := LearningGlossary.common_terms()
var pack_select: OptionButton
var method_select: OptionButton
var content_dialog: FileDialog
var import_button: Button
var content_notice: Label
var chapter_overlay: Panel
var chapter_body: RichTextLabel
var chapter_continue: Button
var shown_chapters := { }
var displayed_index := -1
var shift := InspectionShift.new()
var workspace: Control
var tool_buttons: Array[Button] = []
var tool_guide: Panel
var tool_guide_button: Button
var tool_guide_close: Button
var tool_guide_body: RichTextLabel
var tool_guide_tabs: Array[Button] = []
var guide_tools: Array[Dictionary] = []
var status: Label
var elapsed_time: Label
var card_layer: Control
var cards: Array[DraggableCard] = []
var target_card: DraggableCard
var rules_overlay: Panel
var rules_body: RichTextLabel
var rules_close: Button
var rules_previous_focus: Control
var selected_information: Dictionary = { }
var displayed_case := ""
var displayed_observations := 0
var stamp_pending := false
var desk_generation := 0
var action_stamps: Array[StampTool] = []
var tool_panel: Panel
var how_to_button: Button
var how_to_overlay: Panel
var how_to_image: TextureRect
var how_to_previous: Button
var how_to_next: Button
var how_to_close: Button
var how_to_counter: Label
var how_to_previous_focus: Control
var how_to_index := 0
const HOW_TO_SLIDES := [
	"res://assets/how_to/01-target.png",
	"res://assets/how_to/02-tools.png",
	"res://assets/how_to/03-compare.png",
	"res://assets/how_to/04-external.png",
	"res://assets/how_to/05-stamp.png",
	"res://assets/how_to/06-audit.png",
]
var rules_button: Button
var tool_message: Label
var tool_scroll: ScrollContainer
var tool_rack: VBoxContainer
var active_tools: Array[Dictionary] = []
var reference_cards: Dictionary = { }
var tools_fit_pending := false
var stamp_rack: HBoxContainer
var active_card: DraggableCard
var next: Button
var summary: Panel
var summary_overlay: Panel
var summary_title: Label
var summary_stats: Label
var summary_review: RichTextLabel
var summary_analysis: ScrollContainer
var summary_advice_link: Button
var summary_tabs: Array[Button] = []
var summary_category_links: Array[Button] = []
var summary_restart: Button
var summary_home: Button
var start_screen: Panel
var start_button: Button
var difficulty_select: OptionButton
var category_select: OptionButton
var platform_select: OptionButton
var license_button: Button
var license_overlay: Panel
var license_body: RichTextLabel
var license_close: Button
var license_tabs: Array[Button] = []
var license_sections: Array[Dictionary] = []
var playing := false
var audit_overlay: Panel
var audit_heading: Label
var audit_body: RichTextLabel
var pause_menu: Panel
var menu_button: Button
var menu_resume: Button
var menu_restart: Button
var menu_home: Button
var menu_previous_focus: Control
var external_preview: Panel
var external_preview_body: RichTextLabel
var external_send: Button
var external_skip: Button
var pending_external: Dictionary = { }
var glossary_button: Button
var glossary_overlay: Panel
var glossary_scroll: ScrollContainer
var glossary_list: VBoxContainer
var glossary_close: Button
var glossary_search: LineEdit
var glossary_count: Label
var glossary_empty: Label
var glossary_previous_focus: Control
var glossary_viewed: Dictionary = { }
var glossary_expanded: Dictionary = { }
var glossary_scroll_position := 0
var history_store := HistoryStore.new()
var history_button: Button
var history_overlay: Panel
var history_list: VBoxContainer
var history_close: Button
var history_notice: Label
var summary_save_notice: Label
var summary_retry: Button
var summary_snapshot: Dictionary = { }
var completed_snapshot: Dictionary = { }
var summary_from_history := false
var summary_retry_wrong: Button
var retry_cases: Array[Dictionary] = []
var retry_source_id := ""


func _selected_cases() -> Array[Dictionary]:
	var pack: String = pack_select.get_item_metadata(pack_select.selected)
	if not pack.is_empty():
		return library.pack_cases(pack)
	return library.select_cases(
		difficulty_select.get_item_metadata(difficulty_select.selected),
		category_select.get_item_metadata(category_select.selected),
		platform_select.get_item_metadata(platform_select.selected),
		method_select.get_item_metadata(method_select.selected),
	)


func _refresh_selection(_index: int = 0) -> void:
	var count := _selected_cases().size()
	start_button.tooltip_text = "" if count > 0 else "該当する問題がありません。条件を変更してください。"
	start_button.disabled = count == 0
	for option in [difficulty_select, category_select, platform_select, method_select]:
		option.disabled = not str(pack_select.get_item_metadata(pack_select.selected)).is_empty()


func _ready() -> void:
	theme = Chrome.create(preload("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	_build()
	rules.assign(JSON.parse_string(FileAccess.get_file_as_string("res://data/help/rules.json")))
	library.load_builtin(content_root)
	var import_errors := library.errors.duplicate()
	for source in import_store.sources():
		var prepared := library.prepare_source(source)
		if prepared.errors.is_empty():
			library.commit_source(prepared)
		else:
			import_errors.append_array(prepared.errors)
	_build_tools()
	_build_actions()
	_build_audit()
	_build_start_screen()
	Layout.build_content_import(self)
	Layout.build_chapter(self)
	_refresh_content_options()
	_build_pause_menu()
	Layout.build_rules(self)
	Layout.build_how_to(self)
	Layout.build_external_preview(self)
	Layout.build_glossary(self)
	Layout.build_history(self)
	shift.changed.connect(_refresh)
	_show_start_screen()
	if not library.errors.is_empty() or not import_errors.is_empty():
		content_notice.text = "一部の教材を読み込めませんでした。"
		content_notice.tooltip_text = "\n".join(import_errors)
	tool_guide_button.disabled = library.cases.is_empty()


func _investigation_paused() -> bool:
	return (
		pause_menu.visible or rules_overlay.visible or how_to_overlay.visible
		or external_preview.visible or glossary_overlay.visible or chapter_overlay.visible
	)


func _process(delta: float) -> void:
	_update_hover_drop_targets()
	if not playing or _investigation_paused():
		return
	shift.tick(delta)
	_refresh_elapsed_time()


func _update_hover_drop_targets() -> void:
	var payload: Dictionary = { }
	if (
		playing and not shift.finished() and not shift.judged
		and not _investigation_paused() and not get_viewport().gui_is_dragging()
	):
		var source := get_viewport().gui_get_hovered_control()
		if (
			source is StampTool and not source.disabled
			and not source.preview_only and source.is_visible_in_tree()
		):
			payload = source.payload()
		elif (
			source is InformationToken and source.is_visible_in_tree()
			and source.information.draggable and source.information.tool_input
		):
			payload = { "kind": "information", "information": source.payload() }
	if is_instance_valid(target_card):
		target_card.hover_drop_available = target_card._can_drop_data(Vector2.ZERO, payload)
	for button in tool_buttons:
		button.hover_drop_ready = (
			button.is_visible_in_tree() and button._can_drop_data(Vector2.ZERO, payload)
		)


func _input(event: InputEvent) -> void:
	if is_instance_valid(chapter_overlay) and chapter_overlay.visible:
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			_close_chapter()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if glossary_overlay.visible:
			_close_glossary()
		elif summary_from_history and is_instance_valid(summary_overlay):
			_back_to_history()
		elif history_overlay.visible:
			_close_history()
		else:
			_input_existing(event)
			return
		get_viewport().set_input_as_handled()
		return
	_input_existing(event)


func _input_existing(event: InputEvent) -> void:
	if is_instance_valid(how_to_overlay) and how_to_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if not event.is_echo():
				_close_how_to()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			if not event.is_echo():
				_change_how_to(-1 if event.is_action_pressed("ui_left") else 1)
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
	if playing and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_toggle_menu()


func _build_pause_menu() -> void:
	Layout.build_pause_menu(self)


func _toggle_menu() -> void:
	if (
		not playing or rules_overlay.visible or how_to_overlay.visible
		or glossary_overlay.visible or chapter_overlay.visible
	):
		return
	if pause_menu.visible:
		_close_menu()
		return
	for card in cards:
		card.dragging = false
	menu_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(pause_menu, -1)
	pause_menu.show()
	menu_resume.grab_focus()


func _close_menu() -> void:
	if not is_instance_valid(pause_menu) or not pause_menu.visible:
		return
	pause_menu.hide()
	if is_instance_valid(menu_previous_focus) and menu_previous_focus.is_visible_in_tree():
		menu_previous_focus.grab_focus()
	else:
		menu_button.grab_focus()
	menu_previous_focus = null


func _refresh_elapsed_time() -> void:
	var seconds := floori(shift.elapsed_seconds)
	elapsed_time.text = "%02d:%02d" % [seconds / 60, seconds % 60]


func _build_start_screen() -> void:
	Layout.build_start_screen(self)
	_refresh_selection()


func _tool_description(tool: Dictionary) -> String:
	var input_text := "\n必要な入力: " + Information.input_hint(tool) if not tool \
			.get("accepted_information_types", []) \
			.is_empty() else ""
	var platform_text: String = "\nToolの主な利用環境: " + tool.platform_note if tool.has("platform_note") else ""
	return "対応対象: " + "、".join(tool.categories.map(_type_label)) + platform_text + input_text + "\n\n" + tool.description


func _show_tool_guide() -> void:
	if (
		playing or not start_screen.visible
		or (is_instance_valid(license_overlay) and license_overlay.visible)
	):
		return
	if not is_instance_valid(tool_guide):
		guide_tools = library.guide_tools()
		Layout.build_tool_guide(self)
		if not guide_tools.is_empty():
			_select_tool_guide(0)
		else:
			tool_guide_body.text = "登録されているツールはありません。"
	start_screen.hide()
	tool_guide_body.scroll_to_line(0)
	tool_guide.show()
	tool_guide_close.grab_focus()


func _select_tool_guide(index: int) -> void:
	var tool := guide_tools[index]
	tool_guide_body.clear()
	tool_guide_body.push_font_size(30)
	tool_guide_body.add_text(tool.label + "\n\n")
	tool_guide_body.pop()
	tool_guide_body.add_text(_tool_description(tool))
	tool_guide_body.scroll_to_line(0)
	for i in range(tool_guide_tabs.size()):
		tool_guide_tabs[i].set_pressed_no_signal(i == index)


func _close_tool_guide() -> void:
	tool_guide.hide()
	start_screen.show()
	tool_guide_button.grab_focus()


func _show_licenses() -> void:
	if playing or not start_screen.visible:
		return
	if not is_instance_valid(license_overlay):
		license_sections = preload("res://src/ui/screens/license_notices.gd").sections()
		Layout.build_licenses(self)
	start_button.disabled = true
	tool_guide_button.disabled = true
	license_button.disabled = true
	_select_license(0)
	license_overlay.show()
	license_close.grab_focus()


func _select_license(index: int) -> void:
	license_body.text = license_sections[index].body
	license_body.scroll_to_line(0)
	for i in range(license_tabs.size()):
		license_tabs[i].set_pressed_no_signal(i == index)


func _close_licenses() -> void:
	license_overlay.hide()
	_refresh_selection()
	tool_guide_button.disabled = library.cases.is_empty()
	license_button.disabled = false
	license_button.grab_focus()


func _close_summary() -> void:
	if is_instance_valid(summary_overlay):
		summary_overlay.hide()
		summary_overlay.queue_free()
		summary_overlay = null


func _show_start_screen() -> void:
	chapter_overlay.hide()
	retry_cases.clear()
	retry_source_id = ""
	summary_from_history = false
	_close_glossary(false)
	glossary_viewed.clear()
	glossary_expanded.clear()
	glossary_search.set_text("")
	glossary_scroll_position = 0
	history_overlay.hide()
	_close_how_to(false)
	_close_rules(false)
	_clear_external()
	_close_menu()
	playing = false
	stamp_pending = false
	desk_generation += 1
	_close_summary()
	audit_overlay.hide()
	workspace.hide()
	start_screen.show()
	start_button.grab_focus()


func _start_shift() -> void:
	if library.cases.is_empty() or history_overlay.visible:
		return
	if is_instance_valid(tool_guide) and tool_guide.visible:
		return
	if is_instance_valid(license_overlay) and license_overlay.visible:
		return
	var selected := _selected_cases() if retry_source_id.is_empty() else retry_cases
	if selected.is_empty():
		return
	_begin_shift(selected)


func _retry_wrong_answers() -> void:
	var plan := WrongAnswerRetry.plan(summary_snapshot, library)
	if plan.cases.is_empty():
		return
	retry_cases.assign(plan.cases)
	retry_source_id = summary_snapshot.session_id
	_begin_shift(retry_cases)


func _retry_same_cases() -> void:
	retry_cases.assign(shift.cases)
	retry_source_id = summary_snapshot.session_id
	_start_shift()


func _begin_shift(selected: Array[Dictionary]) -> void:
	shown_chapters.clear()
	chapter_overlay.hide()
	displayed_index = -1
	completed_snapshot.clear()
	summary_from_history = false
	history_overlay.hide()
	_close_how_to(false)
	_close_rules(false)
	_close_menu()
	_close_summary()
	start_screen.hide()
	workspace.show()
	playing = true
	_clear_desk()
	shift.start(selected)
	if not chapter_overlay.visible:
		menu_button.grab_focus()


func _draw() -> void:
	Layout.draw_background(self)


func _build() -> void:
	Layout.build_workspace(self)


func _build_tools() -> void:
	Layout.build_tools(self)
	_queue_tools_fit()


func _set_case_tools(item: Dictionary) -> void:
	var available := library.tools_for(item).filter(
		func(tool):
			return ToolRunner.supports_target(tool, item),
	)
	active_tools = available
	tool_buttons.clear()
	for child in tool_rack.get_children():
		tool_rack.remove_child(child)
		child.queue_free()
	Layout.build_case_tools(self, available)
	tool_scroll.scroll_vertical = 0
	_queue_tools_fit()


func _queue_tools_fit() -> void:
	if tools_fit_pending:
		return
	tools_fit_pending = true
	_fit_tools.call_deferred()


func _fit_tools() -> void:
	tools_fit_pending = false
	Layout.fit_tools(self)


func _build_actions() -> void:
	Layout.build_actions(self)


func get_stamp(action_id: String) -> StampTool:
	for stamp in action_stamps:
		if stamp.action.id == action_id:
			return stamp
	return null


func _clear_desk() -> void:
	_close_glossary(false)
	glossary_viewed.clear()
	glossary_expanded.clear()
	glossary_search.set_text("")
	glossary_scroll_position = 0
	_close_how_to(false)
	_close_rules(false)
	_clear_external()
	desk_generation += 1
	for card in cards:
		card_layer.remove_child(card)
		card.queue_free()
	cards.clear()
	reference_cards.clear()
	tool_message.text = ""
	target_card = null
	displayed_case = ""
	displayed_index = -1
	displayed_observations = 0
	selected_information.clear()
	stamp_pending = false
	active_card = null


func add_information_card(data: Dictionary, origin := Vector2(524, 116)) -> DraggableCard:
	var card := DraggableCard.new()
	card_layer.add_child(card)
	var dimensions := Vector2(380, 478)
	if data.get("category") == "target":
		dimensions = Vector2(480, 592)
		card_layer.move_child(card, 0)
	card.setup(data, origin, dimensions)
	card.clamp_to_desk()
	card.information_selected.connect(_select_information)
	card.stamp_dropped.connect(_receive_stamp)
	card.stamp_validator = _can_stamp
	card.activated.connect(_activate_card)
	cards.append(card)
	_activate_card(card)
	return card


func _activate_card(card: DraggableCard) -> void:
	active_card = card
	for entry in cards:
		entry.set_active(entry == card)


func _open_how_to() -> void:
	if not playing or shift.finished() or shift.judged or _investigation_paused():
		return
	for card in cards:
		card.dragging = false
	how_to_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(how_to_overlay, -1)
	_change_how_to(0)
	how_to_overlay.show()
	how_to_close.grab_focus()


func _change_how_to(direction: int) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	how_to_index = clampi(how_to_index + direction, 0, HOW_TO_SLIDES.size() - 1)
	how_to_image.texture = load(HOW_TO_SLIDES[how_to_index])
	how_to_counter.text = "%d / %d" % [how_to_index + 1, HOW_TO_SLIDES.size()]
	how_to_previous.disabled = how_to_index == 0
	how_to_next.disabled = how_to_index == HOW_TO_SLIDES.size() - 1
	# 無効になった端のボタンからフォーカスを戻し、Tabをギャラリー内に留める。
	var controls: Array[Button] = [how_to_close]
	for button in [how_to_previous, how_to_next]:
		if not button.disabled:
			controls.append(button)
		elif previous_focus == button:
			how_to_close.grab_focus()
	for i in range(controls.size()):
		var button := controls[i]
		button.focus_previous = button.get_path_to(
			controls[(i - 1 + controls.size()) % controls.size()]
		)
		button.focus_next = button.get_path_to(controls[(i + 1) % controls.size()])
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_bottom = button.focus_next


func _close_how_to(restore_focus := true) -> void:
	if not is_instance_valid(how_to_overlay) or not how_to_overlay.visible:
		return
	how_to_overlay.hide()
	if restore_focus:
		if is_instance_valid(how_to_previous_focus) and how_to_previous_focus.is_visible_in_tree():
			how_to_previous_focus.grab_focus()
		else:
			how_to_button.grab_focus()
	how_to_previous_focus = null


func _open_rules() -> void:
	if not playing or shift.finished() or shift.judged or _investigation_paused():
		return
	for card in cards:
		card.dragging = false
	rules_previous_focus = get_viewport().gui_get_focus_owner()
	move_child(rules_overlay, -1)
	rules_body.scroll_to_line(0)
	rules_overlay.show()
	rules_close.grab_focus()


func _close_rules(restore_focus := true) -> void:
	if not is_instance_valid(rules_overlay) or not rules_overlay.visible:
		return
	rules_overlay.hide()
	if restore_focus:
		if is_instance_valid(rules_previous_focus) and rules_previous_focus.is_visible_in_tree():
			rules_previous_focus.grab_focus()
		else:
			rules_button.grab_focus()
	rules_previous_focus = null


func _select_information(token: Dictionary) -> void:
	if glossary_overlay.visible:
		return
	selected_information = token.duplicate(true)
	for card in cards:
		for row in card.tokens:
			row.set_selected(not token.is_empty() and row.payload() == token)
	for button in tool_buttons:
		button.update_input(token)


func _inspect(tool: Dictionary, input: Dictionary = { }) -> void:
	if not playing or shift.finished() or shift.judged or _investigation_paused():
		return
	if not ToolRunner.supports_target(tool, shift.current()):
		tool_message.text = "この調査環境では利用できません。"
		return
	if (
		tool.kind == "references" and tool.get("case_id") == displayed_case
		and reference_cards.has(tool.id)
	):
		var card: DraggableCard = reference_cards[tool.id]
		card.show()
		card.bring_to_front()
		_update_case_controls(shift.current())
		return
	var actual_input := input
	if (
		not input.is_empty() and not Information.accepts(tool, input)
		and tool.accepted_information_types.is_empty()
	):
		actual_input = { }
	if (
		not tool.accepted_information_types.is_empty()
		and (input.is_empty() or not Information.accepts(tool, input))
	):
		tool_message.text = "「" + tool.label + "」の入力：" + Information.input_hint(tool) + "。情報を選択するか、ボタンへドラッグ。"
		return
	if tool.kind == "external_references":
		pending_external = {
			"tool": tool,
			"input": actual_input.duplicate(true),
			"generation": desk_generation,
		}
		external_preview_body.text = tool.label + "\n\n送信する情報：" + tool.submission.type + "\n送信内容：" + Information.display(
			actual_input.value
		) + "\n\n" + tool.submission.warning
		if not actual_input.is_empty():
			external_preview_body.text += "\n\n選んだ入力：" + actual_input.label + "\n" + Information.display(
				actual_input.value
			)
		external_preview_body.scroll_to_line(0)
		external_preview.show()
		glossary_viewed[LearningGlossary.key(tool.id, "submission")] = true
		external_skip.grab_focus()
		return
	var result := shift.inspect(tool, actual_input)
	if not result.ok:
		tool_message.text = result.output


func _clear_external() -> void:
	pending_external.clear()
	if is_instance_valid(external_preview):
		external_preview.hide()


func _finish_external(submit: bool) -> void:
	if pending_external.is_empty():
		return
	var pending := pending_external.duplicate(true)
	_clear_external()
	if pending.generation != desk_generation or not playing or shift.finished() or shift.judged:
		return
	if submit:
		shift.inspect(pending.tool, pending.input)
	else:
		shift.decline_external(pending.tool, pending.input)
	for button in tool_buttons:
		if button.tool.id == pending.tool.id:
			button.grab_focus()
			break


func _refresh() -> void:
	_refresh_elapsed_time()
	audit_overlay.hide()
	status.text = "問題: %d/%d" % [mini(shift.index + 1, shift.cases.size()), shift.cases.size()]
	if shift.finished():
		_show_summary()
		return
	var item := shift.current()
	if displayed_case != ProblemLoader.identity(item) or displayed_index != shift.index:
		_display_case(item)
	_display_observations(item)
	_update_case_controls(item)
	next.visible = shift.judged and not stamp_pending
	if shift.judged:
		if not stamp_pending:
			_show_audit(shift.records.back())


func _display_case(item: Dictionary) -> void:
	_clear_desk()
	displayed_case = ProblemLoader.identity(item)
	displayed_index = shift.index
	_set_case_tools(item)
	var information: Array = [
		{
			"id": "_request",
			"label": "申請内容",
			"value": item.request,
			"category": "request",
			"tool_input": false,
			"draggable": false,
		}
	]
	for fact in item.information:
		var displayed: Dictionary = fact.duplicate(true)
		displayed.draggable = (
			fact.draggable
			and active_tools.any(
				func(tool):
					return (
						ToolRunner.supports_target(tool, item) and Information.accepts(tool, fact)
					),
			)
		)
		information.append(displayed)
	target_card = add_information_card(
		{
			"id": item.id,
			"case_id": displayed_case,
			"title": "検査対象",
			"category": "target",
			"source": _type_label(item.category) + " / " + item.id,
			"icon": _target_icon(item),
			"information": information,
		},
		Vector2(20, 20),
	)
	_select_information({ })
	glossary_viewed[LearningGlossary.key("initial_information", "initial")] = true
	for tool in active_tools:
		if ToolRunner.supports_target(tool, item):
			glossary_viewed[LearningGlossary.key(tool.id, "overview")] = true
	if item.has("chapter") and not shown_chapters.has(item.chapter.id):
		shown_chapters[item.chapter.id] = true
		if not item.chapter.intro.is_empty():
			chapter_body.clear()
			chapter_body.add_text(item.chapter.title + "\n\n" + item.chapter.intro)
			chapter_overlay.show()
			chapter_continue.grab_focus()


func _target_icon(item: Dictionary) -> String:
	var icon: String = {
		"web": "web",
		"email": "email",
		"network": "packet",
		"process": "process",
		"account": "account",
		"package": "package",
	}.get(item.category, "document")
	if item.category == "file":
		# 初期情報だけを使い、解析後に判明する形式や判定結果は表示に含めない。
		for fact in item.information:
			if fact.data_type != "file" or not fact.value is String:
				continue
			match fact.value.get_extension().to_lower():
				"exe", "dll", "com", "msi", "bat", "cmd", "ps1", "sh", "bin", "app", "elf":
					icon = "executable"
				"zip", "7z", "rar", "tar", "gz", "bz2", "xz", "tgz", "zst":
					icon = "archive"
				"png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "ico", "tif", "tiff":
					icon = "image"
				"deb", "rpm", "apk", "whl":
					icon = "package"
			break
	return "res://assets/icons/%s.svg" % icon


func _display_observations(item: Dictionary) -> void:
	while displayed_observations < shift.observations.size():
		var entry := shift.observations[displayed_observations]
		if entry.ok and not entry.get("skipped", false):
			glossary_viewed[LearningGlossary.key(entry.tool_id, "result")] = true
		var info: Array = entry.get("information", [])
		if info.is_empty():
			info = [
				{
					"id": "status",
					"label": "調査の選択" if entry.get("skipped", false) else "取得不可",
					"value": entry.output,
					"tool_input": false,
				}
			]
		var card := add_information_card(
			{
				"id": "result_%d" % displayed_observations,
				"case_id": ProblemLoader.identity(item),
				"title": entry.tool + ("" if entry.ok else " · 取得不可"),
				"category": "analysis",
				"source": entry.tool,
				"information": info,
			},
			Vector2(
				524 + (displayed_observations % 3) * 18,
				116 + (displayed_observations % 3) * 24,
			),
		)
		if (
			entry.ok
			and active_tools.any(
				func(tool):
					return tool.id == entry.tool_id and tool.kind == "references",
			)
		):
			reference_cards[entry.tool_id] = card
		displayed_observations += 1


func _update_case_controls(item: Dictionary) -> void:
	for i in range(tool_buttons.size()):
		var button = tool_buttons[i]
		var tool: Dictionary = button.tool
		button.target_environment = ToolRunner.investigation_environment(item)
		button.case_id = ProblemLoader.identity(item)
		button.visible = ToolRunner.supports_target(tool, item)
		button.disabled = shift.judged or _investigation_paused()
		button.reviewed = reference_cards.has(tool.id)
		button.update_input(selected_information)
	for stamp in action_stamps:
		stamp.visible = not shift.judged
		stamp.disabled = shift.judged or _investigation_paused()
		stamp.modulate.a = 0.4 if stamp.disabled else 1.0
		stamp.tooltip_text = ""
		stamp.case_id = ProblemLoader.identity(item)
		stamp.generation = desk_generation
	tool_message.text = "必要に応じて調査し、判定してください。" if not active_tools.is_empty() else ""


func _can_stamp(data: Dictionary) -> bool:
	return (
		playing and not shift.finished() and not shift.judged
		and not _investigation_paused() and data.get("kind") == "stamp"
		and data.get("case_id") == displayed_case and data.get("generation") == desk_generation
		and is_instance_valid(get_stamp(data.get("action_id", "")))
	)


func _receive_stamp(card: DraggableCard, data: Dictionary) -> void:
	if card != target_card or not _can_stamp(data):
		return
	stamp_pending = true
	var generation := desk_generation
	if not shift.decide(data.action_id):
		stamp_pending = false
		return
	card.show_imprint(_verdict_label(data.action_id), get_stamp(data.action_id).stamp_color)
	await get_tree().create_timer(0.45).timeout
	if generation != desk_generation or not playing:
		return
	stamp_pending = false
	_show_audit(shift.records.back())
	if pause_menu.visible:
		menu_resume.grab_focus()


func _build_audit() -> void:
	Layout.build_audit(self)


func _show_audit(record: Dictionary) -> void:
	_close_glossary(false)
	audit_heading.text = feedback.get("correct_heading", "監査結果：規則に適合") if record.correct else feedback.get(
		"incorrect_heading",
		"SECURITY VIOLATION · 誤判定",
	)
	audit_heading.add_theme_color_override(
		"font_color",
		Color("57edc2") if record.correct else Color("ff718b"),
	)
	audit_body.text = "案件番号：%s / %s\nあなたの判定：%s\n調査操作数：%d件" % [
		record.id,
		record.title,
		_verdict_label(record.verdict),
		record.observations.size(),
	]
	if feedback.get("show_expected", true):
		audit_body.text += "\n正しい判定：" + _verdict_label(record.ground_truth)
	if feedback.get("show_reason", true):
		audit_body.text += "\n\n監査所見\n" + InspectionShift.review_text(record)
	next.show()
	audit_body.scroll_to_line(0)
	next.text = "勤務を終了  >" if shift.index == shift.cases.size() - 1 else "次の案件へ  >"
	audit_overlay.show()
	next.grab_focus()


func _show_summary() -> void:
	_close_glossary(false)
	_close_how_to(false)
	_close_rules(false)
	if is_instance_valid(summary_overlay):
		return
	_clear_external()
	for button in tool_buttons:
		button.disabled = true
	if completed_snapshot.is_empty():
		var selection := { }
		for pair in [
			["level", difficulty_select],
			["category", category_select],
			["platform", platform_select],
		]:
			var option: OptionButton = pair[1]
			selection[pair[0]] = {
				"id": option.get_item_metadata(option.selected),
				"label": option.get_item_text(option.selected),
			}
		if (
			not retry_source_id.is_empty()
			or not str(pack_select.get_item_metadata(pack_select.selected)).is_empty()
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
	next.visible = false
	for stamp in action_stamps:
		stamp.hide()
		stamp.disabled = true
	tool_message.text = "勤務終了。案件を振り返るか、同じ問題に再挑戦してください。"
	summary_restart.grab_focus()


func _display_summary(snapshot: Dictionary, from_history: bool) -> void:
	_close_summary()
	summary_snapshot = snapshot.duplicate(true)
	summary_from_history = from_history
	Layout.build_summary(self)
	var analysis := Analysis.analyze(summary_snapshot)
	var controls := AnalysisView.build(
		summary_analysis,
		analysis,
		summary_snapshot.feedback,
		func(category: String):
			_select_summary_tab(1, category),
		func(indices: Array):
			_select_summary_tab(1, "", indices),
	)
	summary_category_links = controls.categories
	summary_advice_link = controls.advice
	_render_summary_records()
	Layout.build_summary_actions(self)
	_select_summary_tab(0)
	if snapshot.has("retry_of"):
		summary_title.text = "再挑戦の結果"
	if from_history:
		summary_title.text = ("勤務履歴 · 再挑戦 · " if snapshot.has("retry_of") else "勤務履歴 · ") + HistoryStore.date_label(
			snapshot.completed_at
		)
		summary_title.add_theme_font_size_override("font_size", 23)
		summary_home.grab_focus()


func _select_summary_tab(index: int, category: String = "", indices: Array = []) -> void:
	summary_analysis.visible = index == 0
	summary_review.visible = index == 1
	for i in summary_tabs.size():
		summary_tabs[i].set_pressed_no_signal(i == index)
	if index == 1:
		_render_summary_records(category, indices)
		summary_review.scroll_to_line(0)
		summary_tabs[1].grab_focus()
	_update_summary_focus()


func _update_summary_focus() -> void:
	var controls: Array[Control] = []
	for tab in summary_tabs:
		controls.append(tab)
	if summary_analysis.visible:
		controls.append(summary_analysis)
		for link in summary_category_links:
			controls.append(link)
		if is_instance_valid(summary_advice_link):
			controls.append(summary_advice_link)
	else:
		controls.append(summary_review)
	if summary_retry.visible:
		controls.append(summary_retry)
	controls.append(summary_home)
	if not summary_retry_wrong.disabled:
		controls.append(summary_retry_wrong)
	if not summary_from_history:
		controls.append(summary_restart)
	Layout.focus_cycle(controls)


func _render_summary_records(category: String = "", indices: Array = []) -> void:
	summary_review.clear()
	if not indices.is_empty():
		summary_review.add_text("アドバイスに関連する問題（全件表示は上の振り返りタブ）\n\n")
	elif not category.is_empty():
		summary_review.add_text(
			str(Analysis.CATEGORY_LABELS.get(category, category)) + "の結果（全件表示は上の振り返りタブ）\n\n"
		)
	var feedback: Dictionary = summary_snapshot.feedback
	var labels: Dictionary = summary_snapshot.action_labels
	for index in summary_snapshot.records.size():
		var record: Dictionary = summary_snapshot.records[index]
		if not indices.is_empty() and not index in indices:
			continue
		if not category.is_empty() and record.category != category:
			continue
		_summary_item(
			record.title,
			record.id,
			"正解" if record.correct else "誤判定",
			"あなたの判定：" + labels[record.verdict]
			+ (" / 正しい判定：" + labels[record.ground_truth] if feedback.show_expected else "")
			+ (
				"\n" + record.explanation + "\n" + InspectionShift.investigation_feedback(record) if feedback.show_reason else ""
			),
			Color("57edc2") if record.correct else Color("ff718b"),
		)


func _save_summary() -> void:
	if summary_from_history or completed_snapshot.is_empty():
		return
	var saved := history_store.save_completed(completed_snapshot)
	summary_save_notice.text = "" if saved else "履歴を保存できませんでした。"
	summary_save_notice.tooltip_text = history_store.error
	summary_retry.visible = not saved
	_update_summary_focus()


func _summary_item(title: String, id: String, result: String, body: String, color: Color) -> void:
	# 教材の文字列を装飾タグとして解釈せず、案件名だけを大きく表示する。
	summary_review.push_font_size(22)
	summary_review.add_text(title + "\n")
	summary_review.pop()
	summary_review.push_color(color)
	summary_review.add_text("%s  /  %s\n" % [id, result])
	summary_review.pop()
	summary_review.add_text(body + "\n\n")


func _type_label(id: String) -> String:
	for category in library.categories:
		if category.id == id:
			return category.label
	return id


func _verdict_label(id: String) -> String:
	for action in actions:
		if action.id == id:
			return action.label
	return id


func _open_glossary() -> void:
	if not playing or shift.finished() or shift.judged or _investigation_paused():
		return
	for card in cards:
		card.dragging = false
	glossary_previous_focus = get_viewport().gui_get_focus_owner()
	for child in glossary_list.get_children():
		glossary_list.remove_child(child)
		child.queue_free()
	var terms := LearningGlossary.visible_terms(
		shift.current(),
		glossary_terms,
		active_tools,
		glossary_viewed,
	)
	for term in terms:
		var entry := Layout.glossary_entry(glossary_list, term, glossary_expanded.has(term.id))
		var button: Button = entry.button
		button.toggled.connect(
			func(open: bool):
				entry.body.visible = open
				if open:
					glossary_expanded[term.id] = true
				else:
					glossary_expanded.erase(term.id),
		)
	_filter_glossary(glossary_search.text)
	move_child(glossary_overlay, -1)
	glossary_overlay.show()
	_update_case_controls(shift.current())
	glossary_scroll.set_deferred("scroll_vertical", glossary_scroll_position)
	glossary_search.grab_focus()


func _filter_glossary(query: String) -> void:
	var needle := query.strip_edges().to_lower()
	var controls: Array[Control] = [glossary_close, glossary_search]
	var count := 0
	for entry in glossary_list.get_children():
		entry.visible = needle.is_empty() or str(entry.get_meta("search_text", "")).contains(needle)
		if entry.visible:
			count += 1
			controls.append(entry.get_child(0))
	glossary_count.text = "%d / %d 語" % [count, glossary_list.get_child_count()] if not needle.is_empty() else "%d 語" % count
	glossary_empty.text = "表示できる用語はありません。" if glossary_list.get_child_count() == 0 else "該当する用語はありません。"
	glossary_empty.visible = count == 0
	glossary_scroll.scroll_vertical = 0
	Layout.focus_cycle(controls)


func _close_glossary(restore_focus := true) -> void:
	if not is_instance_valid(glossary_overlay) or not glossary_overlay.visible:
		return
	glossary_scroll_position = glossary_scroll.scroll_vertical
	glossary_overlay.hide()
	if playing and not shift.finished():
		_update_case_controls(shift.current())
	if restore_focus:
		if (
			is_instance_valid(glossary_previous_focus)
			and glossary_previous_focus.is_visible_in_tree()
		):
			glossary_previous_focus.grab_focus()
		else:
			glossary_button.grab_focus()
	glossary_previous_focus = null


func _show_history() -> void:
	if (
		playing or not start_screen.visible
		or (is_instance_valid(license_overlay) and license_overlay.visible)
	):
		return
	start_screen.hide()
	_refresh_history()


func _refresh_history() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = [history_close]
	var entries := history_store.list_summaries()
	history_notice.text = "一部の履歴を読み込めませんでした。" if not history_store.warnings.is_empty() else ""
	history_notice.tooltip_text = "\n".join(history_store.warnings)
	if entries.is_empty():
		Layout.list_label(history_list, "保存された勤務履歴はありません。")
	for entry in entries:
		var caption := "%s  ·  %d / %d 正解\n%s / %s / %s" % [
			HistoryStore.date_label(entry.completed_at),
			entry.stats.correct,
			entry.stats.answered,
			entry.selection.level.label,
			entry.selection.category.label,
			entry.selection.platform.label,
		]
		if entry.has("retry_of"):
			caption = "再挑戦 · " + caption
		var button := Chrome.button(history_list, Rect2(0, 0, 860, 90), caption, PAPER)
		button.custom_minimum_size.y = 90
		button.clip_text = true
		button.tooltip_text = caption
		button.pressed.connect(_open_history_entry.bind(entry.session_id))
		buttons.append(button)
	Layout.focus_cycle(buttons)
	history_overlay.show()
	history_close.grab_focus()


func _open_history_entry(id: String) -> void:
	var snapshot := history_store.load_entry(id)
	if snapshot.is_empty():
		history_notice.text = "履歴を読み込めませんでした。"
		history_notice.tooltip_text = history_store.error
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
	history_button.grab_focus()


func _refresh_content_options() -> void:
	_fill_option(
		pack_select,
		library.packs.map(
			func(pack):
				return { "id": pack.key, "label": pack.title },
		),
		"自由演習",
	)
	_fill_option(difficulty_select, library.difficulties.values(), "すべて")
	_fill_option(category_select, library.categories, "すべて")
	_fill_option(platform_select, library.platforms.values(), "すべて")
	_fill_option(method_select, library.methods.values(), "すべて")
	_refresh_selection()


func _fill_option(option: OptionButton, choices: Array, all_label: String) -> void:
	var previous: Variant = option.get_item_metadata(option.selected) if option.selected >= 0 else ""
	option.clear()
	option.add_item(all_label)
	option.set_item_metadata(0, "")
	for entry in choices:
		option.add_item(entry.label)
		option.set_item_metadata(option.item_count - 1, entry.id)
		if entry.id == previous:
			option.select(option.item_count - 1)


func _import_content(path: String) -> void:
	if playing:
		return
	var source := ContentSource.open_file(path)
	var prepared := library.prepare_source(source)
	var errors: PackedStringArray = prepared.errors
	if errors.is_empty() and not import_store.save(source):
		errors.append(import_store.error)
	if not errors.is_empty():
		content_notice.text = "教材を追加できませんでした。"
		content_notice.tooltip_text = "\n".join(errors)
		return
	library.commit_source(prepared)
	content_notice.text = "教材を追加しました。"
	content_notice.tooltip_text = path.get_file()
	_refresh_content_options()
	tool_guide_button.disabled = false
	if is_instance_valid(tool_guide):
		tool_guide.queue_free()
		tool_guide = null
		tool_guide_tabs.clear()


func _session_pack() -> Dictionary:
	var key: String = pack_select.get_item_metadata(pack_select.selected)
	for pack in library.packs:
		if pack.key == key:
			return { "id": pack.key, "title": pack.title, "path": pack.source_id + "/" + pack.path }
	return { "id": "freeplay", "title": "自由演習", "path": content_root }


func _close_chapter() -> void:
	chapter_overlay.hide()
	menu_button.grab_focus()
	if playing and not shift.finished():
		_update_case_controls(shift.current())
