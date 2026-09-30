extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT
const INK = Chrome.TEXT
const MUTED = Chrome.MUTED
const GREEN = Chrome.GREEN

signal start_requested
signal guide_requested
signal licenses_requested
signal history_requested
signal import_requested(path: String)
const TITLE_FONT = preload("res://assets/fonts/YuseiMagic-Regular.ttf")
var library: ProblemLibrary
var pack_select: OptionButton
var method_select: OptionButton
var content_dialog: FileDialog
var import_button: Button
var content_notice: Label
var start_button: Button
var difficulty_select: OptionButton
var category_select: OptionButton
var platform_select: OptionButton
var license_button: Button
var tool_guide_button: Button
var history_button: Button


func setup(source: ProblemLibrary) -> void:
	library = source
	_build()
	_build_import()
	refresh_options()


func _build() -> void:
	ScreenLayout.prepare(self, Color("070e1b"))
	Chrome.panel(self, Rect2(56, 60, 1168, 680), Color("101e32"), Color("29495f"))
	for origin in [Vector2(56, 60), Vector2(1152, 60), Vector2(56, 738), Vector2(1152, 738)]:
		Chrome.panel(self, Rect2(origin, Vector2(72, 2)), GREEN)
	Chrome.label(self, Rect2(94, 92, 1092, 25), "セキュリティ審査ゲーム", MUTED, 16)
	Chrome.panel(self, Rect2(94, 135, 1092, 2), Color("29495f"))
	var title_top := Chrome.label(self, Rect2(98, 162, 470, 92), "とーせん", PAPER, 66)
	var title_bottom := Chrome.label(self, Rect2(188, 235, 456, 92), "ぼ～だ～", GREEN, 66)
	for title_label in [title_top, title_bottom]:
		title_label.add_theme_font_override("font", TITLE_FONT)
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.add_theme_color_override("font_shadow_color", Color("020713"))
		title_label.add_theme_constant_override("shadow_offset_x", 3)
		title_label.add_theme_constant_override("shadow_offset_y", 5)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_top.rotation = deg_to_rad(-3.0)
	title_bottom.rotation = deg_to_rad(2.0)
	Chrome.label(self, Rect2(98, 338, 530, 38), "そのアクセスを、許可しますか。", MUTED, 22)
	Chrome.label(self, Rect2(98, 373, 514, 24), "出題", PAPER, 15)
	pack_select = selection_option(Vector2(98, 400), [{ "id": "", "label": "自由演習" }], 514)
	Chrome.label(self, Rect2(98, 447, 250, 24), "問題カテゴリ", PAPER, 15)
	Chrome.label(self, Rect2(362, 447, 250, 24), "調査環境", PAPER, 15)
	category_select = selection_option(Vector2(98, 475), [{ "id": "", "label": "すべて" }], 250)
	platform_select = selection_option(Vector2(362, 475), [{ "id": "", "label": "すべて" }], 250)
	Chrome.label(self, Rect2(98, 528, 250, 24), "難易度", PAPER, 15)
	Chrome.label(self, Rect2(362, 528, 250, 24), "調査形式", PAPER, 15)
	difficulty_select = selection_option(Vector2(98, 556), [{ "id": "", "label": "すべて" }], 250)
	method_select = selection_option(Vector2(362, 556), [{ "id": "", "label": "すべて" }], 250)
	platform_select.tooltip_text = "OSを選ぶと、そのOSと環境共通の問題を出題します。"
	var briefing := Chrome.panel(self, Rect2(711, 189, 439, 280), Color("101e32"), Color("34556f"))
	Chrome.label(briefing, Rect2(26, 20, 387, 23), "審査前の手引き", Color("b0c8da"), 13)
	Chrome.label(briefing, Rect2(26, 64, 387, 40), "調査 → 判定 → 監査", INK, 24)
	Chrome.label(
		briefing,
		Rect2(26, 115, 387, 155),
		"01  情報を選択・ドラッグしてToolへ渡す\n\n02  調査結果をReferenceと照合\n       必要なら結果を次のToolへ渡す\n\n03  ALLOW / BLOCKを対象へ押印",
		INK,
		16,
	)
	start_button = Chrome.button(self, Rect2(98, 622, 514, 52), "審査を開始  >", PAPER)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(start_requested.emit)
	tool_guide_button = Chrome.button(self, Rect2(711, 578, 439, 40), "ツール一覧  >", PAPER)
	tool_guide_button.pressed.connect(guide_requested.emit)
	license_button = Chrome.button(self, Rect2(711, 630, 439, 40), "ライセンス・著作権表記", MUTED)
	license_button.pressed.connect(licenses_requested.emit)
	history_button = Chrome.button(self, Rect2(711, 526, 439, 40), "審査履歴  >", PAPER)
	history_button.pressed.connect(history_requested.emit)


func selection_option(origin: Vector2, entries: Array, width: float = 245) -> OptionButton:
	var option := OptionButton.new()
	option.position = origin
	option.size = Vector2(width, 42)
	option.fit_to_longest_item = false
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.add_theme_font_size_override("font_size", 18)
	self.add_child(option)
	for entry in entries:
		option.add_item(entry.label)
		option.set_item_metadata(option.item_count - 1, entry.id)
	option.item_selected.connect(refresh_selection)
	return option


func _build_import() -> void:
	import_button = Chrome.button(self, Rect2(711, 474, 439, 40), "問題ZIP / JSONを追加", PAPER)
	content_notice = Chrome.label(self, Rect2(98, 687, 1052, 28), "", MUTED, 14)
	content_dialog = FileDialog.new()
	content_dialog.title = "教材を追加"
	content_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	content_dialog.access = FileDialog.ACCESS_FILESYSTEM
	content_dialog.filters = PackedStringArray(["*.zip ; 問題ZIP", "*.json ; 問題JSON"])
	add_child(content_dialog)
	content_dialog.file_selected.connect(import_requested.emit)
	import_button.pressed.connect(
		func():
			content_dialog.popup_centered_ratio(0.75),
	)


func selected_cases() -> Array[Dictionary]:
	var pack: String = pack_select.get_item_metadata(pack_select.selected)
	if not pack.is_empty():
		return library.pack_cases(pack)
	return library.select_cases(
		difficulty_select.get_item_metadata(difficulty_select.selected),
		category_select.get_item_metadata(category_select.selected),
		platform_select.get_item_metadata(platform_select.selected),
		method_select.get_item_metadata(method_select.selected),
	)


func refresh_selection(_index: int = 0) -> void:
	var count := selected_cases().size()
	start_button.tooltip_text = "" if count > 0 else "該当する問題がありません。条件を変更してください。"
	start_button.disabled = count == 0
	for option in [difficulty_select, category_select, platform_select, method_select]:
		option.disabled = not str(pack_select.get_item_metadata(pack_select.selected)).is_empty()


func refresh_options() -> void:
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
	refresh_selection()


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
