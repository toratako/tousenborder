extends Control
## 画面遷移と操作を調整する。教材・判定はcore、部品の配置はdesk_layoutが担当。

const Layout = preload("res://scripts/ui/desk_layout.gd")
const Chrome = preload("res://scripts/ui/cyber_theme.gd")

@export_file("*.json") var content_pack := "res://data/packs/learning.json"

const PAPER = Layout.PAPER
const INK = Layout.INK
const MUTED = Layout.MUTED
const GREEN = Layout.GREEN
const RED = Layout.RED
var catalog := ContentCatalog.new()
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
var selected_information: Dictionary = {}
var displayed_case := ""
var displayed_observations := 0
var stamp_pending := false
var desk_generation := 0
var action_stamps: Array[StampTool] = []
var tool_panel: Panel
var rules_button: Button
var tool_message: Label
var tool_scroll: ScrollContainer
var tool_rack: VBoxContainer
var active_tools: Array[Dictionary] = []
var reference_cards: Dictionary = {}
var tools_fit_pending := false
var stamp_rack: HBoxContainer
var active_card: DraggableCard
var next: Button
var summary: Panel
var summary_overlay: Panel
var summary_title: Label
var summary_stats: Label
var summary_review: RichTextLabel
var summary_restart: Button
var summary_home: Button
var start_screen: Panel
var start_button: Button
var difficulty_select: OptionButton
var category_select: OptionButton
var platform_select: OptionButton
var common_environment_select: OptionButton
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
var pending_external: Dictionary = {}

func _selected_cases() -> Array[Dictionary]:
	return catalog.select_cases(difficulty_select.get_item_metadata(difficulty_select.selected), category_select.get_item_metadata(category_select.selected), platform_select.get_item_metadata(platform_select.selected), common_environment_select.get_item_metadata(common_environment_select.selected))

func _refresh_selection(_index: int = 0) -> void:
	var count := _selected_cases().size()
	start_button.tooltip_text = "" if count > 0 else "該当する問題がありません。条件を変更してください。"
	start_button.disabled = count == 0
	common_environment_select.disabled = platform_select.get_item_metadata(platform_select.selected) in ["windows", "linux"]
	if common_environment_select.disabled:
		common_environment_select.select(0 if platform_select.get_item_metadata(platform_select.selected) == "windows" else 1)

func _ready() -> void:
	theme = Chrome.create(preload("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	_build()
	if not catalog.load_pack(content_pack):
		status.text = "問題データの読み込みエラー"
		var error_label := Chrome.rich(workspace, Rect2(290, 150, 900, 530), PAPER, 20)
		error_label.text = "\n".join(catalog.errors)
		return
	_build_tools()
	_build_actions()
	_build_audit()
	_build_start_screen()
	_build_pause_menu()
	Layout.build_rules(self)
	Layout.build_external_preview(self)
	shift.changed.connect(_refresh)
	_show_start_screen()

func _process(delta: float) -> void:
	_update_hover_drop_targets()
	if not playing or pause_menu.visible or rules_overlay.visible or external_preview.visible:
		return
	shift.tick(delta)
	_refresh_elapsed_time()

func _update_hover_drop_targets() -> void:
	var payload: Dictionary = {}
	if playing and not shift.finished() and not shift.judged and not pause_menu.visible and not rules_overlay.visible and not external_preview.visible and not get_viewport().gui_is_dragging():
		var source := get_viewport().gui_get_hovered_control()
		if source is StampTool and not source.disabled and not source.preview_only and source.is_visible_in_tree():
			payload = source.payload()
		elif source is InformationToken and source.is_visible_in_tree() and source.information.draggable and source.information.tool_input:
			payload = {"kind": "information", "information": source.payload()}
	if is_instance_valid(target_card):
		target_card.hover_drop_available = target_card._can_drop_data(Vector2.ZERO, payload)
	for button in tool_buttons:
		button.hover_drop_ready = button.is_visible_in_tree() and button._can_drop_data(Vector2.ZERO, payload)

func _input(event: InputEvent) -> void:
	if is_instance_valid(rules_overlay) and rules_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_close_rules()
		return
	if is_instance_valid(external_preview) and external_preview.visible and event.is_action_pressed("ui_cancel"):
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
	if not playing or rules_overlay.visible:
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
	var input_text := "\n必要な入力: " + Information.input_hint(tool) if not tool.get("accepted_information_types", []).is_empty() else ""
	var platform_text: String = "\nToolの主な利用環境: " + tool.platform_note if tool.has("platform_note") else ""
	return "対応対象: " + "、".join(tool.categories.map(_type_label)) + platform_text + input_text + "\n\n" + tool.description

func _show_tool_guide() -> void:
	if playing or not start_screen.visible or (is_instance_valid(license_overlay) and license_overlay.visible):
		return
	if not is_instance_valid(tool_guide):
		guide_tools = catalog.guide_tools()
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
		license_sections = preload("res://scripts/core/license_notices.gd").sections()
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
	tool_guide_button.disabled = false
	license_button.disabled = false
	license_button.grab_focus()

func _close_summary() -> void:
	if is_instance_valid(summary_overlay):
		summary_overlay.hide()
		summary_overlay.queue_free()
		summary_overlay = null

func _show_start_screen() -> void:
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
	if is_instance_valid(tool_guide) and tool_guide.visible:
		return
	if is_instance_valid(license_overlay) and license_overlay.visible:
		return
	var selected := _selected_cases()
	if selected.is_empty():
		return
	_close_rules(false)
	_close_menu()
	_close_summary()
	start_screen.hide()
	workspace.show()
	playing = true
	_clear_desk()
	shift.start(selected)
	menu_button.grab_focus()

func _draw() -> void:
	Layout.draw_background(self)

func _build() -> void:
	Layout.build_workspace(self)

func _build_tools() -> void:
	Layout.build_tools(self)
	_queue_tools_fit()

func _set_case_tools(item: Dictionary) -> void:
	var available := catalog.tools_for(item).filter(func(tool): return ToolRunner.supports_target(tool, item))
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

func _open_rules() -> void:
	if not playing or shift.finished() or shift.judged or pause_menu.visible or external_preview.visible or rules_overlay.visible:
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
	selected_information = token.duplicate(true)
	for card in cards:
		for row in card.tokens:
			row.set_selected(not token.is_empty() and row.payload() == token)
	for button in tool_buttons:
		button.update_input(token)

func _inspect(tool: Dictionary, input: Dictionary = {}) -> void:
	if not playing or shift.finished() or shift.judged or pause_menu.visible or rules_overlay.visible or not pending_external.is_empty():
		return
	if not ToolRunner.supports_target(tool, shift.current()):
		tool_message.text = "この調査環境では利用できません。"
		return
	if tool.resource_kind == "references" and tool.get("case_id") == displayed_case and reference_cards.has(tool.id):
		var card: DraggableCard = reference_cards[tool.id]
		card.show()
		card.bring_to_front()
		_update_case_controls(shift.current())
		return
	var actual_input := input
	if not input.is_empty() and not Information.accepts(tool, input) and tool.accepted_information_types.is_empty():
		actual_input = {}
	if not tool.accepted_information_types.is_empty() and (input.is_empty() or not Information.accepts(tool, input)):
		tool_message.text = "「" + tool.label + "」の入力：" + Information.input_hint(tool) + "。情報を選択するか、ボタンへドラッグ。"
		return
	if tool.resource_kind == "external_references":
		pending_external = {"tool": tool, "input": actual_input.duplicate(true), "generation": desk_generation}
		external_preview_body.text = tool.label + "\n\n送信する情報：" + tool.get("submission_type", "未指定") + "\n送信内容：" + tool.get("submission_value", "未指定") + "\n\n" + tool.get("confidentiality_warning", "送信内容と組織の調査方針を確認してください。")
		if not actual_input.is_empty():
			external_preview_body.text += "\n\n選んだ入力：" + actual_input.label + "\n" + Information.display(actual_input.value)
		external_preview_body.scroll_to_line(0)
		external_preview.show()
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
	if displayed_case != item.id:
		_display_case(item)
	_display_observations(item)
	_update_case_controls(item)
	next.visible = shift.judged and not stamp_pending
	if shift.judged:
		if not stamp_pending:
			_show_audit(shift.records.back())

func _display_case(item: Dictionary) -> void:
	_clear_desk()
	displayed_case = item.id
	_set_case_tools(item)
	var information: Array = [{"id": "_request", "label": "申請内容", "value": item.request,
		"category": "request", "tool_input": false, "draggable": false}]
	for fact in item.information:
		var displayed: Dictionary = fact.duplicate(true)
		displayed.draggable = fact.draggable and active_tools.any(func(tool):
			return ToolRunner.supports_target(tool, item) and Information.accepts(tool, fact))
		information.append(displayed)
	target_card = add_information_card({"id": item.id, "case_id": item.id, "title": "検査対象",
		"category": "target", "source": _type_label(item.category) + " / " + item.id,
		"icon": "res://assets/icons/document.svg",
		"information": information}, Vector2(20, 20))
	_select_information({})

func _display_observations(item: Dictionary) -> void:
	while displayed_observations < shift.observations.size():
		var entry := shift.observations[displayed_observations]
		var info: Array = entry.get("information", [])
		if info.is_empty():
			info = [{"id": "status", "label": "調査の選択" if entry.get("skipped", false) else "取得不可", "value": entry.output, "tool_input": false}]
		var card := add_information_card({"id": "result_%d" % displayed_observations, "case_id": item.id,
			"title": entry.tool + ("" if entry.ok else " · 取得不可"), "category": "analysis",
			"source": entry.tool, "information": info}, Vector2(524 + (displayed_observations % 3) * 18, 116 + (displayed_observations % 3) * 24))
		if entry.ok and active_tools.any(func(tool): return tool.id == entry.tool_id and tool.resource_kind == "references"):
			reference_cards[entry.tool_id] = card
		displayed_observations += 1

func _update_case_controls(item: Dictionary) -> void:
	for i in range(tool_buttons.size()):
		var button = tool_buttons[i]
		var tool: Dictionary = button.tool
		button.target_environment = ToolRunner.investigation_environment(item)
		button.case_id = item.id
		button.visible = ToolRunner.supports_target(tool, item)
		button.disabled = shift.judged
		button.reviewed = reference_cards.has(tool.id)
		button.update_input(selected_information)
	for stamp in action_stamps:
		stamp.visible = not shift.judged
		stamp.disabled = shift.judged
		stamp.modulate.a = 0.4 if stamp.disabled else 1.0
		stamp.tooltip_text = ""
		stamp.case_id = item.id
		stamp.generation = desk_generation
	tool_message.text = "必要に応じて調査し、判定してください。" if not active_tools.is_empty() else "基本情報を確認して判定してください。"

func _can_stamp(data: Dictionary) -> bool:
	return playing and not shift.finished() and not shift.judged and not pause_menu.visible and not rules_overlay.visible and pending_external.is_empty() and data.get("kind") == "stamp" and data.get("case_id") == displayed_case and data.get("generation") == desk_generation and is_instance_valid(get_stamp(data.get("action_id", "")))

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
	audit_heading.text = catalog.feedback.get("correct_heading", "監査結果：規則に適合") if record.correct else catalog.feedback.get("incorrect_heading", "SECURITY VIOLATION · 誤判定")
	audit_heading.add_theme_color_override("font_color", Color("57edc2") if record.correct else Color("ff718b"))
	audit_body.text = "案件番号：%s / %s\nあなたの判定：%s\n調査記録：%d件" % [record.id, record.title, _verdict_label(record.verdict), record.observations.size()]
	if catalog.feedback.get("show_expected", true):
		audit_body.text += "\n正しい判定：" + _verdict_label(record.ground_truth)
	if catalog.feedback.get("show_reason", true):
		audit_body.text += "\n\n監査所見\n" + record.explanation
		var investigation := InspectionShift.investigation_feedback(record)
		if not investigation.is_empty():
			audit_body.text += "\n\n調査手段の振り返り\n" + investigation
	next.show()
	audit_body.scroll_to_line(0)
	next.text = "確認して勤務を終了  >" if shift.index == shift.cases.size() - 1 else "確認して次の案件へ  >"
	audit_overlay.show()
	next.grab_focus()

func _show_summary() -> void:
	_close_rules(false)
	if is_instance_valid(summary_overlay):
		return
	_clear_external()
	for button in tool_buttons:
		button.disabled = true
	Layout.build_summary(self)
	for record in shift.records:
		_summary_item(record.title, record.id, "正解" if record.correct else "誤判定",
			"あなたの判定：" + _verdict_label(record.verdict)
			+ (" / 正しい判定：" + _verdict_label(record.ground_truth) if catalog.feedback.get("show_expected", true) else "")
			+ ("\n" + record.explanation + "\n" + InspectionShift.investigation_feedback(record) if catalog.feedback.get("show_reason", true) else ""),
			Color("57edc2") if record.correct else Color("ff718b"))
	Layout.build_summary_actions(self)
	next.visible = false
	for stamp in action_stamps:
		stamp.hide()
		stamp.disabled = true
	tool_message.text = "勤務終了。案件を振り返るか、新しい勤務を開始してください。"
	summary_restart.grab_focus()

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
	for category in catalog.categories:
		if category.id == id:
			return category.label
	return id

func _verdict_label(id: String) -> String:
	for action in catalog.actions:
		if action.id == id:
			return action.label
	return id
