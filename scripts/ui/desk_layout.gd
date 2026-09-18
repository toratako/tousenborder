extends RefCounted
## 既存画面の部品生成・配置を担当する。部品と操作状態の所有者はdeskのままにする。
const Chrome = preload("res://scripts/ui/cyber_theme.gd")
const PAPER := Color("e4f5ff")
const INK := Color("e4f5ff")
const MUTED := Color("b0c8da")
const GREEN := Color("57edc2")
const RED := Color("ff718b")

static func build_workspace(desk) -> void:
	desk.workspace = Control.new()
	desk.workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.add_child(desk.workspace)
	Chrome.label(desk.workspace, Rect2(24, 21, 160, 32), "電子入境管理", PAPER, 23)
	desk.tools_toggle = icon_button(desk, Rect2(1128, 12, 136, 46), "file", "ツール", "解析ツールを開く / 閉じる")
	desk.tools_toggle.toggle_mode = true
	desk.tools_toggle.pressed.connect(desk._toggle_tools)
	desk.rules_button = icon_button(desk, Rect2(968, 12, 144, 46), "book", "規則集", "セキュリティ運用規則を開く")
	desk.rules_button.pressed.connect(desk._open_rules)
	desk.countdown = Chrome.label(desk.workspace, Rect2(580, 13, 132, 46), "--:--", PAPER, 30)
	desk.countdown_state = Chrome.label(desk.workspace, Rect2(718, 29, 72, 22), "", MUTED, 12)
	desk.status = Chrome.label(desk.workspace, Rect2(776, 25, 185, 28), "準備中", PAPER, 15)
	desk.card_layer = Control.new()
	desk.card_layer.position = Vector2(0, 74)
	desk.card_layer.size = Vector2(1280, 726)
	desk.card_layer.clip_contents = true
	desk.card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.workspace.add_child(desk.card_layer)

static func build_pause_menu(desk) -> void:
	desk.pause_menu = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.78))
	desk.pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(desk.pause_menu, Rect2(330, 155, 620, 490), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(36, 28, 548, 45), "電子入境管理", INK, 30)
	desk.menu_resume = Chrome.button(sheet, Rect2(36, 151, 548, 52), "ゲームに戻る  [ESC]", PAPER)
	desk.menu_resume.pressed.connect(desk._close_menu)
	desk.menu_restart = Chrome.button(sheet, Rect2(36, 225, 548, 52), "勤務を最初からやり直す", PAPER)
	desk.menu_restart.pressed.connect(desk._start_shift)
	desk.menu_home = Chrome.button(sheet, Rect2(36, 299, 548, 52), "タイトル画面に戻る", MUTED)
	desk.menu_home.pressed.connect(desk._show_start_screen)
	# 背面を表示したまま、キーボードのフォーカスをメニュー内に留める。
	var menu_actions: Array[Button] = [desk.menu_resume, desk.menu_restart, desk.menu_home]
	for i in range(menu_actions.size()):
		var button := menu_actions[i]
		var previous_path := button.get_path_to(menu_actions[(i + 2) % 3])
		var next_path := button.get_path_to(menu_actions[(i + 1) % 3])
		button.focus_previous = previous_path
		button.focus_next = next_path
		button.focus_neighbor_top = previous_path
		button.focus_neighbor_bottom = next_path
		button.focus_neighbor_left = previous_path
		button.focus_neighbor_right = next_path
	desk.pause_menu.hide()

static func build_rules(desk) -> void:
	desk.rules_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.78))
	desk.rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.rules_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var book := Chrome.panel(desk.rules_overlay, Rect2(200, 55, 880, 690), Color("101e32"), Color("34556f"))
	Chrome.icon(book, Rect2(30, 24, 40, 40), "res://assets/icons/ui/book.svg")
	Chrome.label(book, Rect2(86, 22, 764, 45), "セキュリティ運用規則", INK, 30)
	Chrome.panel(book, Rect2(30, 86, 820, 2), Color("34556f"))
	desk.rules_body = Chrome.rich(book, Rect2(30, 110, 820, 480), INK, 20)
	desk.rules_body.focus_mode = Control.FOCUS_ALL
	desk.rules_body.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	for rule in desk.catalog.rules:
		desk.rules_body.push_font_size(22)
		desk.rules_body.push_color(GREEN)
		desk.rules_body.add_text(rule.label + "\n")
		desk.rules_body.pop()
		desk.rules_body.pop()
		desk.rules_body.add_text(Information.display(rule.value) + "\n\n")
	desk.rules_close = Chrome.button(book, Rect2(30, 620, 820, 42), "閉じる  [ESC]", PAPER)
	desk.rules_close.pressed.connect(desk._close_rules)
	for control in [desk.rules_body, desk.rules_close]:
		var other: Control = desk.rules_close if control == desk.rules_body else desk.rules_body
		var path: NodePath = control.get_path_to(other)
		control.focus_next = path
		control.focus_previous = path
		control.focus_neighbor_left = path
		control.focus_neighbor_right = path
		control.focus_neighbor_top = path
		control.focus_neighbor_bottom = path
	desk.rules_overlay.hide()

static func build_start_screen(desk) -> void:
	desk.start_screen = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color("070e1b"))
	desk.start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.start_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.panel(desk.start_screen, Rect2(56, 60, 1168, 680), Color("101e32"), Color("29495f"))
	for origin in [Vector2(56, 60), Vector2(1152, 60), Vector2(56, 738), Vector2(1152, 738)]:
		Chrome.panel(desk.start_screen, Rect2(origin, Vector2(72, 2)), GREEN)
	Chrome.label(desk.start_screen, Rect2(94, 92, 1092, 25), "電子入境管理", MUTED, 16)
	Chrome.panel(desk.start_screen, Rect2(94, 135, 1092, 2), Color("29495f"))
	Chrome.label(desk.start_screen, Rect2(94, 189, 550, 70), "電子入境管理", PAPER, 44)
	Chrome.label(desk.start_screen, Rect2(98, 283, 530, 50), "そのアクセスを、許可しますか。", GREEN, 24)
	Chrome.label(desk.start_screen, Rect2(98, 445, 165, 28), "難易度", PAPER, 16)
	Chrome.label(desk.start_screen, Rect2(274, 445, 165, 28), "問題カテゴリ", PAPER, 16)
	Chrome.label(desk.start_screen, Rect2(450, 445, 165, 28), "調査環境", PAPER, 16)
	var difficulties: Array = [{"id": "", "label": "すべて"}]
	for id in ["very_beginner", "beginner", "intermediate", "advanced"]:
		if desk.catalog.difficulties.has(id):
			difficulties.append({"id": id, "label": desk.catalog.difficulties[id].label})
	for id in desk.catalog.difficulties:
		if id not in ["very_beginner", "beginner", "intermediate", "advanced"]:
			difficulties.append({"id": id, "label": desk.catalog.difficulties[id].label})
	desk.difficulty_select = selection_option(desk, Vector2(98, 480), difficulties, 162)
	var categories: Array = [{"id": "", "label": "すべて"}]
	categories.append_array(desk.catalog.categories)
	desk.category_select = selection_option(desk, Vector2(274, 480), categories, 162)
	var platforms: Array = [{"id": "", "label": "すべて"}]
	for id in desk.catalog.platforms:
		platforms.append({"id": id, "label": desk.catalog.platforms[id].label})
	desk.platform_select = selection_option(desk, Vector2(450, 480), platforms, 162)
	desk.platform_select.tooltip_text = "OSを選ぶと、そのOSと環境共通の問題を出題します。"
	var briefing := Chrome.panel(desk.start_screen, Rect2(711, 189, 439, 328), Color("101e32"), Color("34556f"))
	Chrome.label(briefing, Rect2(26, 20, 387, 23), "勤務前の手引き", Color("b0c8da"), 13)
	Chrome.label(briefing, Rect2(26, 64, 387, 40), "調査 → 判定 → 監査", INK, 24)
	Chrome.label(briefing, Rect2(26, 120, 387, 180), "01  情報を選択・ドラッグしてToolへ渡す\n\n02  調査結果をReferenceと照合\n       必要なら結果を次のToolへ渡す\n\n03  ALLOW / BLOCKを対象へ押印", INK, 16)
	Chrome.label(desk.start_screen, Rect2(450, 526, 240, 22), "共通問題の調査OS", MUTED, 13)
	desk.common_environment_select = selection_option(desk, Vector2(450, 551), [{"id": "windows", "label": "Windows"}, {"id": "linux", "label": "Linux"}], 162)
	desk.common_environment_select.tooltip_text = "すべての環境・共通のみを選んだ場合の調査OSです。OS固有の問題はそのOSで調査します。"
	desk.start_button = Chrome.button(desk.start_screen, Rect2(98, 602, 514, 60), "勤務を開始  >", PAPER)
	desk.start_button.add_theme_font_size_override("font_size", 22)
	desk.start_button.pressed.connect(desk._start_shift)
	desk.tool_guide_button = Chrome.button(desk.start_screen, Rect2(711, 588, 439, 44), "ツール一覧  >", PAPER)
	desk.tool_guide_button.pressed.connect(desk._show_tool_guide)
	desk.license_button = Chrome.button(desk.start_screen, Rect2(711, 648, 439, 44), "ライセンス・著作権表記", MUTED)
	desk.license_button.pressed.connect(desk._show_licenses)

static func build_tools(desk) -> void:
	desk.tool_drawer = Chrome.panel(desk.workspace, Rect2(1016, 74, 248, 536), Color("101e32"), Color("34556f"))
	desk.tool_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.label(desk.tool_drawer, Rect2(16, 12, 180, 28), "解析キット", PAPER, 18)
	var close := Chrome.button(desk.tool_drawer, Rect2(204, 8, 32, 32), "×", MUTED)
	close.pressed.connect(desk._hide_tools)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 50)
	scroll.size = Vector2(224, 408)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desk.tool_drawer.add_child(scroll)
	var rack := VBoxContainer.new()
	rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_theme_constant_override("separation", 8)
	scroll.add_child(rack)
	desk.tool_message = Chrome.label(desk.tool_drawer, Rect2(14, 468, 220, 60), "", PAPER, 12)
	desk.tool_scroll = scroll
	desk.tool_rack = rack
	desk.tool_message.minimum_size_changed.connect(desk._queue_tools_fit)
	desk.tool_rack.minimum_size_changed.connect(desk._queue_tools_fit)
	desk.tool_drawer.visibility_changed.connect(desk._queue_tools_fit)
	desk.workspace.resized.connect(desk._queue_tools_fit)

static func build_actions(desk) -> void:
	desk.stamp_rack = HBoxContainer.new()
	desk.stamp_rack.position = Vector2(1280 - desk.catalog.actions.size() * 142, 710)
	desk.stamp_rack.size = Vector2(desk.catalog.actions.size() * 142, 90)
	desk.stamp_rack.add_theme_constant_override("separation", 0)
	desk.workspace.add_child(desk.stamp_rack)
	for action in desk.catalog.actions:
		var stamp := StampTool.new()
		stamp.custom_minimum_size = Vector2(142, 90)
		desk.stamp_rack.add_child(stamp)
		stamp.configure(action)
		desk.action_stamps.append(stamp)

static func build_audit(desk) -> void:
	# 画面全体で入力を受け止め、監査中の背面操作を防ぐ。
	desk.audit_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.78))
	desk.audit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.audit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.panel(desk.audit_overlay, Rect2(312, 131, 680, 540), Color("050a12"))
	var sheet := Chrome.panel(desk.audit_overlay, Rect2(300, 119, 680, 540), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(28, 21, 624, 24), "電子入境管理局  /  内部監査課", INK, 14)
	Chrome.label(sheet, Rect2(28, 53, 624, 43), "審査結果  監査票", INK, 30)
	Chrome.panel(sheet, Rect2(28, 109, 624, 2), Color("34556f"))
	desk.audit_heading = Chrome.label(sheet, Rect2(28, 126, 624, 34), "", INK, 22)
	desk.audit_body = Chrome.rich(sheet, Rect2(28, 177, 624, 275), INK, 17)
	desk.next = Chrome.button(sheet, Rect2(28, 475, 624, 42), "確認して次の案件へ  >", PAPER)
	desk.next.pressed.connect(func(): desk.shift.advance())
	desk.audit_overlay.visible = false

static func selection_option(desk, origin: Vector2, entries: Array, width: float = 245) -> OptionButton:
	var option := OptionButton.new()
	option.position = origin
	option.size = Vector2(width, 42)
	option.fit_to_longest_item = false
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.add_theme_font_size_override("font_size", 18)
	desk.start_screen.add_child(option)
	for entry in entries:
		option.add_item(entry.label)
		option.set_item_metadata(option.item_count - 1, entry.id)
	option.item_selected.connect(desk._refresh_selection)
	return option

static func icon_button(desk, rect: Rect2, icon_name: String, caption: String, tooltip: String) -> Button:
	var button := Chrome.button(desk.workspace, rect, caption, PAPER)
	button.icon = load("res://assets/icons/ui/" + icon_name + ".svg")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = tooltip
	return button

static func build_tool_guide(desk) -> void:
	desk.tool_guide = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color("070e1b"))
	desk.tool_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.tool_guide.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(desk.tool_guide, Rect2(80, 55, 1120, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 1060, 45), "調査ツール詳細", INK, 30)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 125)
	scroll.size = Vector2(310, 465)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	var group := ButtonGroup.new()
	for i in range(desk.guide_tools.size()):
		var tab := Chrome.button(list, Rect2(0, 0, 310, 48), desk.guide_tools[i].label, PAPER)
		tab.custom_minimum_size.y = 48
		tab.clip_text = true
		tab.tooltip_text = desk.guide_tools[i].label
		tab.toggle_mode = true
		tab.button_group = group
		var selected := tab.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
		selected.bg_color = Color("164255")
		selected.border_color = INK
		tab.add_theme_stylebox_override("pressed", selected)
		tab.pressed.connect(desk._select_tool_guide.bind(i))
		desk.tool_guide_tabs.append(tab)
	Chrome.panel(sheet, Rect2(358, 125, 2, 465), Color("34556f"))
	desk.tool_guide_body = Chrome.rich(sheet, Rect2(382, 125, 708, 465), INK, 21)
	desk.tool_guide_close = Chrome.button(sheet, Rect2(30, 620, 1060, 42), "タイトル画面に戻る", PAPER)
	desk.tool_guide_close.pressed.connect(desk._close_tool_guide)

static func build_licenses(desk) -> void:
	desk.license_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.85))
	desk.license_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.license_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(desk.license_overlay, Rect2(180, 55, 920, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 860, 45), "ライセンス・著作権表記", INK, 30)
	for i in range(desk.license_sections.size()):
		var tab := Chrome.button(sheet, Rect2(30 + i * 217, 120, 209, 40), desk.license_sections[i].title, PAPER)
		tab.toggle_mode = true
		tab.pressed.connect(desk._select_license.bind(i))
		desk.license_tabs.append(tab)
	desk.license_body = Chrome.rich(sheet, Rect2(30, 183, 860, 409), INK, 15)
	desk.license_close = Chrome.button(sheet, Rect2(30, 620, 860, 42), "タイトル画面に戻る", PAPER)
	desk.license_close.pressed.connect(desk._close_licenses)

static func build_summary(desk) -> void:
	desk.summary_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.82))
	desk.summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.panel(desk.summary_overlay, Rect2(252, 97, 800, 630), Color("050a12"))
	desk.summary = Chrome.panel(desk.summary_overlay, Rect2(240, 85, 800, 630), Color("101e32"), Color("34556f"))
	desk.summary_title = Chrome.label(desk.summary, Rect2(30, 22, 740, 45), "時間切れ / 勤務結果" if desk.shift.timed_out else "勤務結果", INK, 30)
	desk.summary_stats = Chrome.label(desk.summary, Rect2(30, 77, 740, 30), "正解 %d件  /  誤判定 %d件  /  未審査 %d件" % [desk.shift.score(), desk.shift.records.size() - desk.shift.score(), desk.shift.cases.size() - desk.shift.records.size()], INK, 18)
	desk.summary_stats.text += "  /  不適切な調査 %d件" % desk.shift.unsafe_investigations()
	desk.summary_stats.add_theme_font_size_override("font_size", 16)
	Chrome.panel(desk.summary, Rect2(30, 119, 740, 2), Color("34556f"))
	desk.summary_review = Chrome.rich(desk.summary, Rect2(30, 137, 740, 396), INK, 15)

static func build_summary_actions(desk) -> void:
	desk.summary_home = Chrome.button(desk.summary, Rect2(30, 557, 280, 45), "スタート画面へ", MUTED)
	desk.summary_home.pressed.connect(desk._show_start_screen)
	desk.summary_restart = Chrome.button(desk.summary, Rect2(326, 557, 444, 45), "新しい勤務を開始", PAPER)
	desk.summary_restart.pressed.connect(desk._start_shift)

static func build_external_preview(desk) -> void:
	desk.external_preview = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.9))
	desk.external_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.external_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(desk.external_preview, Rect2(280, 120, 720, 560), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(28, 24, 664, 44), "External Reference · 送信前の確認", INK, 25)
	desk.external_preview_body = Chrome.rich(sheet, Rect2(28, 90, 664, 350), INK, 18)
	desk.external_skip = Chrome.button(sheet, Rect2(28, 480, 320, 48), "送信を見送る  [ESC]", PAPER)
	desk.external_send = Chrome.button(sheet, Rect2(364, 480, 328, 48), "送信して調査", PAPER)
	desk.external_skip.pressed.connect(desk._finish_external.bind(false))
	desk.external_send.pressed.connect(desk._finish_external.bind(true))
	for button in [desk.external_skip, desk.external_send]:
		var other: Button = desk.external_send if button == desk.external_skip else desk.external_skip
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(other)
		button.focus_neighbor_bottom = button.get_path_to(other)
	desk.external_preview.hide()

static func build_case_tools(desk, available: Array[Dictionary]) -> void:
	for group in desk.catalog.resource_groups:
		var entries := available.filter(func(tool): return tool.get("group", "tools") == group)
		if entries.is_empty():
			continue
		var heading := Label.new()
		heading.text = desk.catalog.resource_groups[group].label
		heading.add_theme_font_size_override("font_size", 14)
		desk.tool_rack.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		desk.tool_rack.add_child(grid)
		for tool in entries:
			var button := Chrome.button(grid, Rect2(0, 0, 100, 92), tool.label, PAPER)
			button.set_script(preload("res://scripts/ui/tool_input.gd"))
			button.tool = tool
			button.custom_minimum_size = Vector2(100, 112)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = tool.description
			if desk.catalog.resource_groups[group].kind == "external_references":
				button.tooltip_text += "\n送信する情報: " + tool.get("submission_type", "未指定") + "\n" + tool.get("confidentiality_warning", "")
			button.pressed.connect(func(): desk._inspect(tool, desk.selected_information))
			button.information_dropped.connect(desk._inspect)
			button.setup_presentation()
			desk.tool_buttons.append(button)

static func fit_tools(desk) -> void:
	var message_height: float = desk.tool_message.get_minimum_size().y if not desk.tool_message.text.is_empty() else 0.0
	var footer := 12.0 + (message_height + 10.0 if message_height > 0 else 0.0)
	var maximum: float = desk.workspace.size.y - desk.tool_drawer.position.y - 12.0
	var content_height: float = desk.tool_rack.get_combined_minimum_size().y
	desk.tool_drawer.size.y = minf(50.0 + content_height + footer, maximum)
	desk.tool_scroll.size.y = maxf(0.0, desk.tool_drawer.size.y - 50.0 - footer)
	desk.tool_message.position.y = 50.0 + desk.tool_scroll.size.y + 10.0
	desk.tool_message.size.y = message_height

static func draw_background(desk) -> void:
	desk.draw_rect(Rect2(0, 0, 1280, 800), Color("070e1b"))
	for y in range(80, 800, 32):
		desk.draw_line(Vector2(0, y), Vector2(1280, y), Color("112336"), 1)
	for x in range(0, 1280, 32):
		desk.draw_line(Vector2(x, 80), Vector2(x, 800), Color("112336"), 1)
	desk.draw_rect(Rect2(0, 0, 1280, 72), Color("0c1829"))
	desk.draw_line(Vector2(0, 72), Vector2(1280, 72), Color("29495f"), 1)
