extends Control
## Owns investigation controls and card lifetime; navigation is emitted to the application.
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const TITLE_FONT = preload("res://assets/fonts/YuseiMagic-Regular.ttf")
const GAME_TITLE := "とーせんぼ～だ～"
const PAPER = Chrome.TEXT
const GREEN = Chrome.GREEN
signal menu_requested
signal how_to_requested
signal rules_requested
signal glossary_requested
signal cleared
signal case_presented(item: Dictionary)
signal result_viewed(tool_id: String)
signal external_requested(tool: Dictionary, input: Dictionary, generation: int)
signal refresh_started
signal audit_requested(record: Dictionary, after_stamp: bool)
signal completed
var interaction_paused: Callable
var selection_paused: Callable
var categories: Array[Dictionary] = []
var shift: InspectionShift
var actions: Array[Dictionary] = []
var status: Label
var elapsed_time: Label
var card_layer: Control
var cards: Array[DraggableCard] = []
var target_card: DraggableCard
var selected_information: Dictionary = { }
var displayed_case := ""
var displayed_observations := 0
var stamp_pending := false
var desk_generation := 0
var displayed_index := -1
var action_stamps: Array[StampTool] = []
var tool_panel: Panel
var how_to_button: Button
var rules_button: Button
var glossary_button: Button
var tool_message: Label
var tool_scroll: ScrollContainer
var tool_rack: VBoxContainer
var active_tools: Array[Dictionary] = []
var reference_cards: Dictionary = { }
var tools_fit_pending := false
var stamp_rack: HBoxContainer
var active_card: DraggableCard
var tool_buttons: Array[Button] = []
var menu_button: Button
var playing := false


func setup(
	model: InspectionShift,
	verdicts: Array[Dictionary],
	paused: Callable,
	selection_blocked: Callable,
) -> void:
	shift = model
	actions = verdicts
	interaction_paused = paused
	selection_paused = selection_blocked
	_build()
	_build_tools()
	_queue_tools_fit()
	_build_actions()
	shift.changed.connect(_refresh)


func stop_dragging() -> void:
	for card in cards:
		card.dragging = false


func refresh_hover_targets() -> void:
	var payload: Dictionary = { }
	if (
		playing and not shift.finished() and not shift.judged
		and not interaction_paused.call() and not get_viewport().gui_is_dragging()
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


func refresh_elapsed_time() -> void:
	var seconds := floori(shift.elapsed_seconds)
	elapsed_time.text = "%02d:%02d" % [seconds / 60, seconds % 60]


func _set_case_tools(item: Dictionary) -> void:
	var available := ProblemLibrary.tools_for(item).filter(
		func(tool):
			return ProblemContext.supports_target(tool, item),
	)
	active_tools = available
	tool_buttons.clear()
	for child in tool_rack.get_children():
		tool_rack.remove_child(child)
		child.queue_free()
	_build_case_tools(available)
	tool_scroll.scroll_vertical = 0
	_queue_tools_fit()


func _queue_tools_fit() -> void:
	if tools_fit_pending:
		return
	tools_fit_pending = true
	_fit_tools.call_deferred()


func _fit_tools() -> void:
	tools_fit_pending = false
	_layout_tools()


func get_stamp(action_id: String) -> StampTool:
	for stamp in action_stamps:
		if stamp.action.id == action_id:
			return stamp
	return null


func clear_case() -> void:
	cleared.emit()
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


func _select_information(token: Dictionary) -> void:
	if selection_paused.call():
		return
	selected_information = token.duplicate(true)
	for card in cards:
		for row in card.tokens:
			row.set_selected(not token.is_empty() and row.payload() == token)
	for button in tool_buttons:
		button.update_input(token)


func _inspect(tool: Dictionary, input: Dictionary = { }) -> void:
	if not playing or shift.finished() or shift.judged or interaction_paused.call():
		return
	if not ProblemContext.supports_target(tool, shift.current()):
		tool_message.text = "この調査環境では利用できません。"
		return
	if (
		tool.kind == "references" and tool.get("case_id") == displayed_case
		and reference_cards.has(tool.id)
	):
		var card: DraggableCard = reference_cards[tool.id]
		card.show()
		card.bring_to_front()
		refresh_controls(shift.current())
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
		external_requested.emit(tool, actual_input, desk_generation)
		return
	var result := shift.inspect(tool, actual_input)
	if not result.ok:
		tool_message.text = result.output


func _refresh() -> void:
	refresh_elapsed_time()
	refresh_started.emit()
	status.text = "問題: %d/%d" % [mini(shift.index + 1, shift.cases.size()), shift.cases.size()]
	if shift.finished():
		completed.emit()
		return
	var item := shift.current()
	if displayed_case != ProblemContext.identity(item) or displayed_index != shift.index:
		_display_case(item)
	_display_observations(item)
	refresh_controls(item)
	if shift.judged:
		if not stamp_pending:
			audit_requested.emit(shift.records.back(), false)


func _display_case(item: Dictionary) -> void:
	clear_case()
	displayed_case = ProblemContext.identity(item)
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
						ProblemContext.supports_target(tool, item)
						and Information.accepts(tool, fact)
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
	case_presented.emit(item)


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
			result_viewed.emit(entry.tool_id)
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
				"case_id": ProblemContext.identity(item),
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


func refresh_controls(item: Dictionary) -> void:
	for i in range(tool_buttons.size()):
		var button = tool_buttons[i]
		var tool: Dictionary = button.tool
		button.target_environment = ProblemContext.investigation_environment(item)
		button.case_id = ProblemContext.identity(item)
		button.visible = ProblemContext.supports_target(tool, item)
		button.disabled = shift.judged or interaction_paused.call()
		button.reviewed = reference_cards.has(tool.id)
		button.update_input(selected_information)
	for stamp in action_stamps:
		stamp.visible = not shift.judged
		stamp.disabled = shift.judged or interaction_paused.call()
		stamp.modulate.a = 0.4 if stamp.disabled else 1.0
		stamp.tooltip_text = ""
		stamp.case_id = ProblemContext.identity(item)
		stamp.generation = desk_generation
	tool_message.text = "必要に応じて調査し、判定してください。" if not active_tools.is_empty() else ""


func _can_stamp(data: Dictionary) -> bool:
	return (
		playing and not shift.finished() and not shift.judged
		and not interaction_paused.call() and data.get("kind") == "stamp"
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
	audit_requested.emit(shift.records.back(), true)


func _type_label(id: String) -> String:
	for category in categories:
		if category.id == id:
			return category.label
	return id


func _verdict_label(id: String) -> String:
	for action in actions:
		if action.id == id:
			return action.label
	return id


func _build() -> void:
	self.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_button = Chrome.button(self, Rect2(20, 12, 208, 46), GAME_TITLE, PAPER)
	menu_button.add_theme_font_override("font", TITLE_FONT)
	menu_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	menu_button.add_theme_color_override("font_focus_color", GREEN)
	menu_button.add_theme_font_size_override("font_size", 23)
	menu_button.tooltip_text = "メニューを開く [ESC]"
	menu_button.pressed.connect(menu_requested.emit)
	how_to_button = icon_button(Rect2(960, 12, 144, 46), "book", "遊び方", "遊び方を開く")
	how_to_button.pressed.connect(how_to_requested.emit)
	rules_button = icon_button(Rect2(1120, 12, 144, 46), "book", "規則集", "セキュリティ運用規則を開く")
	rules_button.pressed.connect(rules_requested.emit)
	glossary_button = icon_button(Rect2(456, 12, 144, 46), "book", "用語集", "用語集を開く")
	glossary_button.pressed.connect(glossary_requested.emit)
	for button in [menu_button, how_to_button, rules_button, glossary_button]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(
				state,
				header_pill_style(
					Color("19394d") if state in ["hover", "pressed"] else Color("101e32")
				),
			)
	var rules_focus := header_pill_style(Color.TRANSPARENT)
	rules_focus.border_color = PAPER
	rules_button.add_theme_stylebox_override("focus", rules_focus)
	how_to_button.add_theme_stylebox_override("focus", rules_focus)
	glossary_button.add_theme_stylebox_override("focus", rules_focus)
	for rect in [Rect2(624, 12, 128, 46), Rect2(768, 12, 128, 46)]:
		var pill := Chrome.panel(self, rect, Color.TRANSPARENT)
		pill.add_theme_stylebox_override("panel", header_pill_style(Color("101e32")))
	elapsed_time = Chrome.label(self, Rect2(640, 12, 96, 46), "00:00", Color("57e4f2"), 26)
	status = Chrome.label(self, Rect2(784, 12, 96, 46), "準備中", PAPER, 15)
	for label in [elapsed_time, status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_layer = Control.new()
	card_layer.position = Vector2(0, 74)
	card_layer.size = Vector2(984, 726)
	card_layer.clip_contents = true
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.add_child(card_layer)


func header_pill_style(fill: Color) -> StyleBoxFlat:
	var style := Chrome.box(fill, Color("34556f"), 16)
	style.set_corner_radius_all(23)
	return style


func _build_tools() -> void:
	tool_panel = Chrome.panel(self, Rect2(996, 72, 284, 712), Color("0c1829"))
	var surface := tool_panel.get_theme_stylebox("panel") as StyleBoxFlat
	surface.border_color = Color("436982")
	surface.border_width_left = 1
	tool_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.label(tool_panel, Rect2(16, 12, 180, 28), "調査", PAPER, 18)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 50)
	scroll.size = Vector2(256, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tool_panel.add_child(scroll)
	var rack := VBoxContainer.new()
	rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_theme_constant_override("separation", 4)
	scroll.add_child(rack)
	tool_message = Chrome.label(tool_panel, Rect2(14, 560, 256, 52), "", PAPER, 12)
	tool_message.max_lines_visible = 4
	tool_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tool_scroll = scroll
	tool_rack = rack
	tool_message.minimum_size_changed.connect(_queue_tools_fit)
	tool_rack.minimum_size_changed.connect(_queue_tools_fit)
	tool_panel.visibility_changed.connect(_queue_tools_fit)
	self.resized.connect(_queue_tools_fit)


func _build_actions() -> void:
	stamp_rack = HBoxContainer.new()
	stamp_rack.position = Vector2(20 + (480 - actions.size() * 142) / 2.0, 710)
	stamp_rack.size = Vector2(actions.size() * 142, 90)
	stamp_rack.add_theme_constant_override("separation", 0)
	self.add_child(stamp_rack)
	for action in actions:
		var stamp := StampTool.new()
		stamp.custom_minimum_size = Vector2(142, 90)
		stamp_rack.add_child(stamp)
		stamp.configure(action)
		action_stamps.append(stamp)


func icon_button(rect: Rect2, icon_name: String, caption: String, tooltip: String) -> Button:
	var button := Chrome.button(self, rect, caption, PAPER)
	button.icon = load("res://assets/icons/ui/" + icon_name + ".svg")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = tooltip
	return button


func _build_case_tools(available: Array[Dictionary]) -> void:
	var groups := ProblemLibrary.groups_for(available)
	if available.is_empty():
		var empty := Label.new()
		empty.text = "この案件は基本情報のみで判定できます。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_rack.add_child(empty)
	for group in groups:
		var entries := available.filter(
			func(tool):
				return tool.get("group", "tools") == group,
		)
		if entries.is_empty():
			continue
		if groups[group].kind == "external_references":
			var gap := MarginContainer.new()
			gap.add_theme_constant_override("margin_top", 14)
			gap.add_theme_constant_override("margin_bottom", 2)
			tool_rack.add_child(gap)
			var divider := HSeparator.new()
			var line := StyleBoxLine.new()
			line.color = Color("34556f")
			line.thickness = 1
			divider.add_theme_stylebox_override("separator", line)
			gap.add_child(divider)
		var heading := Label.new()
		heading.text = groups[group].label
		heading.add_theme_font_size_override("font_size", 13)
		heading.custom_minimum_size.y = 32
		heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		tool_rack.add_child(heading)
		for tool in entries:
			var button := Chrome.button(tool_rack, Rect2(0, 0, 240, 64), tool.label, PAPER)
			button.set_script(preload("res://src/ui/inspection/tool_input.gd"))
			button.tool = tool
			button.custom_minimum_size = Vector2(0, 64)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = tool.description
			if groups[group].kind == "external_references":
				button.tooltip_text += "\n送信する情報: " + tool.submission.type + "\n" + tool \
						.submission \
						.warning
			button.pressed.connect(
				func():
					_inspect(tool, selected_information),
			)
			button.information_dropped.connect(_inspect)
			button.setup_presentation()
			tool_buttons.append(button)


func _layout_tools() -> void:
	var message_height: float = (
		tool_message.get_minimum_size().y
		if not self \
				.tool_message \
				.text \
				.is_empty()
		else 0.0
	)
	var footer := 12.0 + (message_height + 10.0 if message_height > 0 else 0.0)
	tool_panel.size = self.size - tool_panel.position - Vector2(0, 16)
	tool_scroll.size.x = tool_panel.size.x - 28.0
	tool_message.size.x = tool_scroll.size.x
	tool_scroll.size.y = maxf(0.0, tool_panel.size.y - 50.0 - footer)
	tool_message.tooltip_text = tool_message.text
	tool_message.position.y = 50.0 + tool_scroll.size.y + 10.0
	tool_message.size.y = message_height
