extends Panel

const Chrome = preload("res://src/ui/shared/game_theme.gd")
const ScreenLayout = preload("res://src/ui/shared/screen_layout.gd")
const PAPER = Chrome.TEXT

signal closed
signal entry_requested(id: String)
var entries_list: VBoxContainer
var close_button: Button
var notice: Label


func setup() -> void:
	var parts := ScreenLayout.list_content(self, "勤務履歴")
	entries_list = parts.list
	close_button = parts.close
	notice = parts.notice
	close_button.text = "タイトル画面へ戻る"
	close_button.pressed.connect(closed.emit)


func show_entries(entries: Array[Dictionary], warnings: PackedStringArray) -> void:
	for child in entries_list.get_children():
		entries_list.remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = [close_button]
	notice.text = "一部の履歴を読み込めませんでした。" if not warnings.is_empty() else ""
	notice.tooltip_text = "\n".join(warnings)
	if entries.is_empty():
		ScreenLayout.list_label(entries_list, "保存された勤務履歴はありません。")
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
		var button := Chrome.button(entries_list, Rect2(0, 0, 860, 90), caption, PAPER)
		button.custom_minimum_size.y = 90
		button.clip_text = true
		button.tooltip_text = caption
		button.pressed.connect(entry_requested.emit.bind(entry.session_id))
		buttons.append(button)
	ScreenLayout.focus_cycle(buttons)
	self.show()
	close_button.grab_focus()
