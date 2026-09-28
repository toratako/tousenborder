extends RefCounted
## 既存画面の部品生成・配置を担当する。部品と操作状態の所有者はdeskのままにする。
const Chrome = preload("res://src/ui/shared/game_theme.gd")
const TITLE_FONT = preload("res://assets/fonts/YuseiMagic-Regular.ttf")
const GAME_TITLE := "とーせんぼ～だ～"
const PAPER := Color("e4f5ff")
const INK := Color("e4f5ff")
const MUTED := Color("b0c8da")
const GREEN := Color("57edc2")
const RED := Color("ff718b")


static func build_workspace(desk) -> void:
	desk.workspace = Control.new()
	desk.workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.add_child(desk.workspace)
	desk.menu_button = Chrome.button(desk.workspace, Rect2(20, 12, 208, 46), GAME_TITLE, PAPER)
	desk.menu_button.add_theme_font_override("font", TITLE_FONT)
	desk.menu_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	desk.menu_button.add_theme_color_override("font_focus_color", GREEN)
	desk.menu_button.add_theme_font_size_override("font_size", 23)
	desk.menu_button.tooltip_text = "メニューを開く [ESC]"
	desk.menu_button.pressed.connect(desk._toggle_menu)
	desk.how_to_button = icon_button(desk, Rect2(960, 12, 144, 46), "book", "遊び方", "遊び方を開く")
	desk.how_to_button.pressed.connect(desk._open_how_to)
	desk.rules_button = icon_button(desk, Rect2(1120, 12, 144, 46), "book", "規則集", "セキュリティ運用規則を開く")
	desk.rules_button.pressed.connect(desk._open_rules)
	desk.glossary_button = icon_button(desk, Rect2(456, 12, 144, 46), "book", "用語集", "用語集を開く")
	desk.glossary_button.pressed.connect(desk._open_glossary)
	for button in [desk.menu_button, desk.how_to_button, desk.rules_button, desk.glossary_button]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(
				state,
				header_pill_style(
					Color("19394d") if state in ["hover", "pressed"] else Color("101e32")
				),
			)
	var rules_focus := header_pill_style(Color.TRANSPARENT)
	rules_focus.border_color = PAPER
	desk.rules_button.add_theme_stylebox_override("focus", rules_focus)
	desk.how_to_button.add_theme_stylebox_override("focus", rules_focus)
	desk.glossary_button.add_theme_stylebox_override("focus", rules_focus)
	for rect in [Rect2(624, 12, 128, 46), Rect2(768, 12, 128, 46)]:
		var pill := Chrome.panel(desk.workspace, rect, Color.TRANSPARENT)
		pill.add_theme_stylebox_override("panel", header_pill_style(Color("101e32")))
	desk.elapsed_time = Chrome.label(
		desk.workspace,
		Rect2(640, 12, 96, 46),
		"00:00",
		Color("57e4f2"),
		26,
	)
	desk.status = Chrome.label(desk.workspace, Rect2(784, 12, 96, 46), "準備中", PAPER, 15)
	for label in [desk.elapsed_time, desk.status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desk.card_layer = Control.new()
	desk.card_layer.position = Vector2(0, 74)
	desk.card_layer.size = Vector2(984, 726)
	desk.card_layer.clip_contents = true
	desk.card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.workspace.add_child(desk.card_layer)


static func header_pill_style(fill: Color) -> StyleBoxFlat:
	var style := Chrome.box(fill, Color("34556f"), 16)
	style.set_corner_radius_all(23)
	return style


static func build_pause_menu(desk) -> void:
	desk.pause_menu = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.78))
	desk.pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(
		desk.pause_menu,
		Rect2(330, 155, 620, 490),
		Color("101e32"),
		Color("34556f"),
	)
	var menu_title := Chrome.label(sheet, Rect2(36, 28, 548, 45), GAME_TITLE, INK, 30)
	menu_title.add_theme_font_override("font", TITLE_FONT)
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
	var book := Chrome.panel(
		desk.rules_overlay,
		Rect2(200, 55, 880, 690),
		Color("101e32"),
		Color("34556f"),
	)
	Chrome.icon(book, Rect2(30, 24, 40, 40), "res://assets/icons/ui/book.svg")
	Chrome.label(book, Rect2(86, 22, 764, 45), "セキュリティ運用規則", INK, 30)
	Chrome.panel(book, Rect2(30, 86, 820, 2), Color("34556f"))
	desk.rules_body = Chrome.rich(book, Rect2(30, 110, 820, 480), INK, 20)
	desk.rules_body.focus_mode = Control.FOCUS_ALL
	desk.rules_body.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	for rule in desk.rules:
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


static func build_how_to(desk) -> void:
	desk.how_to_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.9))
	desk.how_to_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.how_to_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(
		desk.how_to_overlay,
		Rect2(40, 24, 1200, 752),
		Color("101e32"),
		Color("34556f"),
	)
	Chrome.label(sheet, Rect2(28, 16, 500, 40), "遊び方", INK, 26)
	desk.how_to_close = Chrome.button(sheet, Rect2(980, 16, 192, 40), "閉じる  [ESC]", PAPER)
	desk.how_to_close.pressed.connect(desk._close_how_to)
	desk.how_to_image = TextureRect.new()
	desk.how_to_image.position = Vector2(24, 72)
	desk.how_to_image.size = Vector2(1152, 600)
	desk.how_to_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk.how_to_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	desk.how_to_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(desk.how_to_image)
	desk.how_to_previous = Chrome.button(sheet, Rect2(376, 690, 144, 42), "←  前へ", PAPER)
	desk.how_to_next = Chrome.button(sheet, Rect2(680, 690, 144, 42), "次へ  →", PAPER)
	desk.how_to_previous.pressed.connect(desk._change_how_to.bind(-1))
	desk.how_to_next.pressed.connect(desk._change_how_to.bind(1))
	desk.how_to_counter = Chrome.label(sheet, Rect2(536, 690, 128, 42), "", MUTED, 18)
	desk.how_to_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desk.how_to_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desk.how_to_overlay.hide()


static func build_start_screen(desk) -> void:
	desk.start_screen = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color("070e1b"))
	desk.start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.start_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.panel(desk.start_screen, Rect2(56, 60, 1168, 680), Color("101e32"), Color("29495f"))
	for origin in [Vector2(56, 60), Vector2(1152, 60), Vector2(56, 738), Vector2(1152, 738)]:
		Chrome.panel(desk.start_screen, Rect2(origin, Vector2(72, 2)), GREEN)
	Chrome.label(desk.start_screen, Rect2(94, 92, 1092, 25), "セキュリティ審査ゲーム", MUTED, 16)
	Chrome.panel(desk.start_screen, Rect2(94, 135, 1092, 2), Color("29495f"))
	var title_top := Chrome.label(desk.start_screen, Rect2(98, 162, 470, 92), "とーせん", PAPER, 66)
	var title_bottom := Chrome.label(desk.start_screen, Rect2(188, 235, 456, 92), "ぼ～だ～", GREEN, 66)
	for title_label in [title_top, title_bottom]:
		title_label.add_theme_font_override("font", TITLE_FONT)
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.add_theme_color_override("font_shadow_color", Color("020713"))
		title_label.add_theme_constant_override("shadow_offset_x", 3)
		title_label.add_theme_constant_override("shadow_offset_y", 5)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_top.rotation = deg_to_rad(-3.0)
	title_bottom.rotation = deg_to_rad(2.0)
	Chrome.label(desk.start_screen, Rect2(98, 338, 530, 38), "そのアクセスを、許可しますか。", MUTED, 22)
	Chrome.label(desk.start_screen, Rect2(98, 373, 514, 24), "出題", PAPER, 15)
	desk.pack_select = selection_option(
		desk,
		Vector2(98, 400),
		[{ "id": "", "label": "自由演習" }],
		514,
	)
	Chrome.label(desk.start_screen, Rect2(98, 447, 250, 24), "問題カテゴリ", PAPER, 15)
	Chrome.label(desk.start_screen, Rect2(362, 447, 250, 24), "調査環境", PAPER, 15)
	desk.category_select = selection_option(
		desk,
		Vector2(98, 475),
		[{ "id": "", "label": "すべて" }],
		250,
	)
	desk.platform_select = selection_option(
		desk,
		Vector2(362, 475),
		[{ "id": "", "label": "すべて" }],
		250,
	)
	Chrome.label(desk.start_screen, Rect2(98, 528, 250, 24), "難易度", PAPER, 15)
	Chrome.label(desk.start_screen, Rect2(362, 528, 250, 24), "調査形式", PAPER, 15)
	desk.difficulty_select = selection_option(
		desk,
		Vector2(98, 556),
		[{ "id": "", "label": "すべて" }],
		250,
	)
	desk.method_select = selection_option(
		desk,
		Vector2(362, 556),
		[{ "id": "", "label": "すべて" }],
		250,
	)
	desk.platform_select.tooltip_text = "OSを選ぶと、そのOSと環境共通の問題を出題します。"
	var briefing := Chrome.panel(
		desk.start_screen,
		Rect2(711, 189, 439, 280),
		Color("101e32"),
		Color("34556f"),
	)
	Chrome.label(briefing, Rect2(26, 20, 387, 23), "勤務前の手引き", Color("b0c8da"), 13)
	Chrome.label(briefing, Rect2(26, 64, 387, 40), "調査 → 判定 → 監査", INK, 24)
	Chrome.label(
		briefing,
		Rect2(26, 115, 387, 155),
		"01  情報を選択・ドラッグしてToolへ渡す\n\n02  調査結果をReferenceと照合\n       必要なら結果を次のToolへ渡す\n\n03  ALLOW / BLOCKを対象へ押印",
		INK,
		16,
	)
	desk.start_button = Chrome.button(desk.start_screen, Rect2(98, 622, 514, 52), "勤務を開始  >", PAPER)
	desk.start_button.add_theme_font_size_override("font_size", 22)
	desk.start_button.pressed.connect(desk._start_shift)
	desk.tool_guide_button = Chrome.button(
		desk.start_screen,
		Rect2(711, 578, 439, 40),
		"ツール一覧  >",
		PAPER,
	)
	desk.tool_guide_button.pressed.connect(desk._show_tool_guide)
	desk.license_button = Chrome.button(
		desk.start_screen,
		Rect2(711, 630, 439, 40),
		"ライセンス・著作権表記",
		MUTED,
	)
	desk.license_button.pressed.connect(desk._show_licenses)
	desk.history_button = Chrome.button(
		desk.start_screen,
		Rect2(711, 526, 439, 40),
		"勤務履歴  >",
		PAPER,
	)
	desk.history_button.pressed.connect(desk._show_history)


static func build_tools(desk) -> void:
	desk.tool_panel = Chrome.panel(desk.workspace, Rect2(996, 72, 284, 712), Color("0c1829"))
	var surface := desk.tool_panel.get_theme_stylebox("panel") as StyleBoxFlat
	surface.border_color = Color("436982")
	surface.border_width_left = 1
	desk.tool_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	Chrome.label(desk.tool_panel, Rect2(16, 12, 180, 28), "調査", PAPER, 18)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 50)
	scroll.size = Vector2(256, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desk.tool_panel.add_child(scroll)
	var rack := VBoxContainer.new()
	rack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_theme_constant_override("separation", 4)
	scroll.add_child(rack)
	desk.tool_message = Chrome.label(desk.tool_panel, Rect2(14, 560, 256, 52), "", PAPER, 12)
	desk.tool_message.max_lines_visible = 4
	desk.tool_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desk.tool_scroll = scroll
	desk.tool_rack = rack
	desk.tool_message.minimum_size_changed.connect(desk._queue_tools_fit)
	desk.tool_rack.minimum_size_changed.connect(desk._queue_tools_fit)
	desk.tool_panel.visibility_changed.connect(desk._queue_tools_fit)
	desk.workspace.resized.connect(desk._queue_tools_fit)


static func build_actions(desk) -> void:
	desk.stamp_rack = HBoxContainer.new()
	desk.stamp_rack.position = Vector2(20 + (480 - desk.actions.size() * 142) / 2.0, 710)
	desk.stamp_rack.size = Vector2(desk.actions.size() * 142, 90)
	desk.stamp_rack.add_theme_constant_override("separation", 0)
	desk.workspace.add_child(desk.stamp_rack)
	for action in desk.actions:
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
	var sheet := Chrome.panel(
		desk.audit_overlay,
		Rect2(300, 119, 680, 540),
		Color("101e32"),
		Color("34556f"),
	)
	Chrome.label(sheet, Rect2(28, 28, 624, 43), "審査結果  監査票", INK, 30)
	Chrome.panel(sheet, Rect2(28, 84, 624, 2), Color("34556f"))
	desk.audit_heading = Chrome.label(sheet, Rect2(28, 101, 624, 34), "", INK, 22)
	desk.audit_body = Chrome.rich(sheet, Rect2(28, 152, 624, 300), INK, 17)
	desk.next = Chrome.button(sheet, Rect2(28, 475, 624, 42), "確認して次の案件へ  >", PAPER)
	desk.next.pressed.connect(
		func():
			desk.shift.advance(),
	)
	desk.audit_overlay.visible = false


static func selection_option(
	desk,
	origin: Vector2,
	entries: Array,
	width: float = 245,
) -> OptionButton:
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


static func icon_button(
	desk,
	rect: Rect2,
	icon_name: String,
	caption: String,
	tooltip: String,
) -> Button:
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
	var sheet := Chrome.panel(
		desk.tool_guide,
		Rect2(80, 55, 1120, 690),
		Color("101e32"),
		Color("34556f"),
	)
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
	var sheet := Chrome.panel(
		desk.license_overlay,
		Rect2(180, 55, 920, 690),
		Color("101e32"),
		Color("34556f"),
	)
	Chrome.label(sheet, Rect2(30, 22, 860, 45), "ライセンス・著作権表記", INK, 30)
	for i in range(desk.license_sections.size()):
		var tab := Chrome.button(
			sheet,
			Rect2(30 + i * 217, 120, 209, 40),
			desk.license_sections[i].title,
			PAPER,
		)
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
	desk.summary = Chrome.panel(
		desk.summary_overlay,
		Rect2(140, 40, 1000, 720),
		Color("101e32"),
		Color("34556f"),
	)
	desk.summary_title = Chrome.label(desk.summary, Rect2(30, 18, 940, 45), "勤務結果", INK, 30)
	var stats: Dictionary = desk.summary_snapshot.stats
	desk.summary_stats = Chrome.label(
		desk.summary,
		Rect2(30, 65, 940, 30),
		"正解 %d件  /  誤判定 %d件" % [stats.correct, stats.answered - stats.correct],
		MUTED,
		18,
	)
	desk.summary_stats.text += "  /  不適切な調査 %d件" % stats.unsafe
	desk.summary_stats.add_theme_font_size_override("font_size", 16)
	desk.summary_stats.hide()
	desk.summary_tabs.clear()
	for i in 2:
		var tab := Chrome.button(
			desk.summary,
			Rect2(30 + i * 475, 72, 465, 40),
			["分析", "問題ごとの振り返り"][i],
			PAPER,
		)
		tab.toggle_mode = true
		tab.pressed.connect(desk._select_summary_tab.bind(i))
		desk.summary_tabs.append(tab)
	desk.summary_analysis = ScrollContainer.new()
	desk.summary_analysis.position = Vector2(30, 128)
	desk.summary_analysis.size = Vector2(940, 477)
	desk.summary_analysis.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desk.summary_analysis.follow_focus = true
	desk.summary_analysis.focus_mode = Control.FOCUS_ALL
	desk.summary.add_child(desk.summary_analysis)
	desk.summary_review = Chrome.rich(desk.summary, Rect2(30, 128, 940, 477), INK, 18)
	desk.summary_review.focus_mode = Control.FOCUS_ALL
	desk.summary_save_notice = Chrome.label(desk.summary, Rect2(30, 620, 670, 27), "", RED, 15)
	desk.summary_retry = Chrome.button(desk.summary, Rect2(730, 616, 240, 32), "保存を再試行", PAPER)
	desk.summary_retry.pressed.connect(desk._save_summary)
	desk.summary_retry.hide()


static func build_summary_actions(desk) -> void:
	desk.summary_home = Chrome.button(desk.summary, Rect2(30, 660, 230, 45), "スタート画面へ", MUTED)
	var plan: Dictionary = desk.WrongAnswerRetry.plan(desk.summary_snapshot, desk.library)
	desk.summary_retry_wrong = Chrome.button(
		desk.summary,
		Rect2(276, 660, 370, 45),
		"誤った問題に再挑戦（%d問）" % plan.cases.size(),
		PAPER,
	)
	desk.summary_retry_wrong.add_theme_font_size_override("font_size", 19)
	desk.summary_retry_wrong.disabled = plan.cases.is_empty()
	desk.summary_retry_wrong.tooltip_text = plan.reason
	desk.summary_retry_wrong.pressed.connect(desk._retry_wrong_answers)
	if desk.summary_from_history:
		desk.summary_home.text = "勤務履歴へ戻る"
		desk.summary_home.pressed.connect(desk._back_to_history)
		return
	desk.summary_home.pressed.connect(desk._show_start_screen)
	desk.summary_restart = Chrome.button(desk.summary, Rect2(662, 660, 308, 45), "同じ問題に再挑戦", PAPER)
	desk.summary_restart.pressed.connect(desk._retry_same_cases)


static func build_external_preview(desk) -> void:
	desk.external_preview = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.9))
	desk.external_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.external_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(
		desk.external_preview,
		Rect2(280, 120, 720, 560),
		Color("101e32"),
		Color("34556f"),
	)
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
	var groups := ProblemLibrary.groups_for(available)
	if available.is_empty():
		var empty := Label.new()
		empty.text = "この案件は基本情報のみで判定できます。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desk.tool_rack.add_child(empty)
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
			desk.tool_rack.add_child(gap)
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
		desk.tool_rack.add_child(heading)
		for tool in entries:
			var button := Chrome.button(desk.tool_rack, Rect2(0, 0, 240, 64), tool.label, PAPER)
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
					desk._inspect(tool, desk.selected_information),
			)
			button.information_dropped.connect(desk._inspect)
			button.setup_presentation()
			desk.tool_buttons.append(button)


static func fit_tools(desk) -> void:
	var message_height: float = desk.tool_message.get_minimum_size().y if not desk \
			.tool_message \
			.text \
			.is_empty() else 0.0
	var footer := 12.0 + (message_height + 10.0 if message_height > 0 else 0.0)
	desk.tool_panel.size = desk.workspace.size - desk.tool_panel.position - Vector2(0, 16)
	desk.tool_scroll.size.x = desk.tool_panel.size.x - 28.0
	desk.tool_message.size.x = desk.tool_scroll.size.x
	desk.tool_scroll.size.y = maxf(0.0, desk.tool_panel.size.y - 50.0 - footer)
	desk.tool_message.tooltip_text = desk.tool_message.text
	desk.tool_message.position.y = 50.0 + desk.tool_scroll.size.y + 10.0
	desk.tool_message.size.y = message_height


static func draw_background(desk) -> void:
	desk.draw_rect(Rect2(0, 0, 1280, 800), Color("070e1b"))
	for y in range(16, 800, 32):
		desk.draw_line(Vector2(0, y), Vector2(1280, y), Color("112336"), 1)
	for x in range(0, 1280, 32):
		desk.draw_line(Vector2(x, 0), Vector2(x, 800), Color("112336"), 1)


static func list_overlay(desk, title: String) -> Dictionary:
	var overlay := Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.85))
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(overlay, Rect2(180, 55, 920, 690), Color("101e32"), Color("34556f"))
	Chrome.label(sheet, Rect2(30, 22, 860, 45), title, INK, 30)
	var notice := Chrome.label(sheet, Rect2(30, 78, 860, 30), "", RED, 15)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 115)
	scroll.size = Vector2(860, 485)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var close := Chrome.button(sheet, Rect2(30, 620, 860, 42), "閉じる", PAPER)
	overlay.hide()
	return { "overlay": overlay, "scroll": scroll, "list": list, "close": close, "notice": notice }


static func build_glossary(desk) -> void:
	var parts := list_overlay(desk, "用語集")
	desk.glossary_overlay = parts.overlay
	desk.glossary_scroll = parts.scroll
	desk.glossary_list = parts.list
	desk.glossary_close = parts.close
	desk.glossary_close.pressed.connect(desk._close_glossary)
	var sheet: Control = parts.scroll.get_parent()
	parts.notice.hide()
	desk.glossary_search = LineEdit.new()
	desk.glossary_search.position = Vector2(30, 80)
	desk.glossary_search.size = Vector2(680, 44)
	desk.glossary_search.placeholder_text = "用語を検索"
	desk.glossary_search.clear_button_enabled = true
	desk.glossary_search.add_theme_font_size_override("font_size", 18)
	desk.glossary_search.add_theme_color_override("font_color", INK)
	desk.glossary_search.add_theme_color_override("font_placeholder_color", MUTED)
	desk.glossary_search.add_theme_color_override("caret_color", Chrome.CYAN)
	desk.glossary_search.add_theme_stylebox_override(
		"normal",
		Chrome.box(Chrome.BACKGROUND, Chrome.BORDER, 16),
	)
	desk.glossary_search.add_theme_stylebox_override(
		"focus",
		Chrome.box(Color.TRANSPARENT, Chrome.CYAN, 16),
	)
	sheet.add_child(desk.glossary_search)
	desk.glossary_search.text_changed.connect(desk._filter_glossary)
	desk.glossary_count = Chrome.label(sheet, Rect2(730, 90, 160, 30), "", MUTED, 16)
	desk.glossary_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desk.glossary_scroll.position.y = 142
	desk.glossary_scroll.size.y = 458
	desk.glossary_list.add_theme_constant_override("separation", 12)
	desk.glossary_empty = Chrome.label(sheet, Rect2(30, 175, 840, 45), "該当する用語はありません。", MUTED, 18)
	desk.glossary_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desk.glossary_empty.hide()


static func build_history(desk) -> void:
	var parts := list_overlay(desk, "勤務履歴")
	desk.history_overlay = parts.overlay
	desk.history_list = parts.list
	desk.history_close = parts.close
	desk.history_notice = parts.notice
	desk.history_close.text = "タイトル画面へ戻る"
	desk.history_close.pressed.connect(desk._close_history)


static func list_label(parent: Control, text: String) -> Label:
	var label := Chrome.label(parent, Rect2(0, 0, 820, 30), text, INK, 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func glossary_entry(parent: Control, term: Dictionary, expanded: bool) -> Dictionary:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	column.set_meta("search_text", (str(term.label) + " " + str(term.description)).to_lower())
	parent.add_child(column)
	var button := Chrome.button(column, Rect2(0, 0, 820, 52), "", PAPER)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "focus"]:
		var fill := Color("19394d") if state in ["hover", "pressed"] else Color("14263b")
		var style := Chrome.box(
			Color.TRANSPARENT if state == "focus" else fill,
			Chrome.CYAN if state == "focus" else Chrome.BORDER,
			18,
		)
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		button.add_theme_stylebox_override(state, style)
	button.toggle_mode = true
	button.set_pressed_no_signal(expanded)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var body := list_label(column, term.description)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_constant_override("line_spacing", 7)
	var body_style := Chrome.box(Color("0c192b"), Chrome.BORDER, 24)
	body_style.content_margin_top = 16
	body_style.content_margin_bottom = 20
	body.add_theme_stylebox_override("normal", body_style)
	body.visible = expanded
	button.text = ("▾   " if expanded else "▸   ") + str(term.label)
	button.toggled.connect(
		func(open: bool):
			button.text = ("▾   " if open else "▸   ") + str(term.label),
	)
	return { "button": button, "body": body }


static func focus_cycle(buttons: Array) -> void:
	for i in buttons.size():
		var button: Control = buttons[i]
		button.focus_previous = button.get_path_to(
			buttons[(i - 1 + buttons.size()) % buttons.size()]
		)
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_bottom = button.focus_next


static func build_content_import(desk) -> void:
	desk.import_button = Chrome.button(
		desk.start_screen,
		Rect2(711, 474, 439, 40),
		"問題ZIP / JSONを追加",
		PAPER,
	)
	desk.content_notice = Chrome.label(desk.start_screen, Rect2(98, 687, 1052, 28), "", MUTED, 14)
	desk.content_dialog = FileDialog.new()
	desk.content_dialog.title = "教材を追加"
	desk.content_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	desk.content_dialog.access = FileDialog.ACCESS_FILESYSTEM
	desk.content_dialog.filters = PackedStringArray(["*.zip ; 問題ZIP", "*.json ; 問題JSON"])
	desk.add_child(desk.content_dialog)
	desk.content_dialog.file_selected.connect(desk._import_content)
	desk.import_button.pressed.connect(
		func():
			desk.content_dialog.popup_centered_ratio(0.75),
	)


static func build_chapter(desk) -> void:
	desk.chapter_overlay = Chrome.panel(desk, Rect2(0, 0, 1280, 800), Color(0.02, 0.04, 0.09, 0.85))
	desk.chapter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.chapter_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := Chrome.panel(
		desk.chapter_overlay,
		Rect2(260, 120, 760, 560),
		Color("101e32"),
		Color("34556f"),
	)
	desk.chapter_body = Chrome.rich(sheet, Rect2(30, 28, 700, 430), INK, 20)
	desk.chapter_continue = Chrome.button(sheet, Rect2(30, 480, 700, 48), "審査を始める", PAPER)
	desk.chapter_continue.pressed.connect(desk._close_chapter)
	desk.chapter_body.focus_mode = Control.FOCUS_ALL
	focus_cycle([desk.chapter_body, desk.chapter_continue])
	desk.chapter_overlay.hide()
