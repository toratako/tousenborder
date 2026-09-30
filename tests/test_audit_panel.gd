extends SceneTree
const Audit = preload("res://src/ui/inspection/audit_panel.gd")
const Chrome = preload("res://src/ui/shared/game_theme.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var panel := Audit.new()
	panel.theme = Chrome.create(load("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	root.add_child(panel)
	panel.setup()
	var record := {"id": "LONG-ID-".repeat(20), "title": "長い問題名".repeat(30),
		"correct": true, "verdict": "allow", "ground_truth": "allow",
		"explanation": "根拠を照合してください。\n".repeat(60),
		"observations": [{"tool": "外部照会", "ok": true, "correct_usage": false, "reason": "機密情報の送信"},
			{"tool": "URL照会", "ok": true, "skipped": true, "reason": "送信を見送り"}]}
	var actions: Array[Dictionary] = [{"id": "allow", "label": "ALLOW"}, {"id": "block", "label": "BLOCK"}]
	panel.present(record, {}, actions, false)
	await process_frame
	check(panel.heading.text.contains("正解") and panel.investigation_notice.visible, "正解でも不適切調査を上部に表示")
	check(panel.body.get_parsed_text().contains("機密情報の送信") and panel.body.get_parsed_text().contains("外部送信を見送り"), "調査の理由と見送りを保持")
	check(panel.problem_title.get_rect().end.y < panel.result_banner.position.y, "長い問題名でも下の判定と重ならない")
	check(panel.body.get_rect().end.y < panel.next_button.position.y, "長文と次へボタンを分離")
	check(panel.body.get_v_scroll_bar().max_value > panel.body.size.y, "長い理由をスクロールして読める")
	check(panel.problem_title.tooltip_text == record.title, "長いタイトルの全文を確認可能")
	panel.body.get_v_scroll_bar().value = 200
	panel.present(record, {"show_expected": false, "show_reason": false}, actions, true)
	check(not panel.verdict_summary.text.contains("正しく"), "正解非表示で前問の判定を残さない")
	check(not panel.body.visible and panel.body.get_parsed_text().is_empty() and not panel.investigation_notice.visible, "理由非表示で前問の内容を残さない")
	check(panel.next_button.focus_next == panel.next_button.get_path_to(panel.next_button), "非表示の本文へフォーカスを移さない")
	record.correct = false
	record.ground_truth = "block"
	record.explanation = "[b]本文[/b]"
	record.observations = []
	panel.present(record, {}, actions, false)
	await process_frame
	check(panel.heading.text.contains("誤判定") and panel.verdict_summary.text.contains("遮断する必要"), "次の問題の判定を反映")
	check(panel.heading.get_visible_line_count() == 1, "誤判定の見出しを表示")
	check(panel.body.get_parsed_text().contains("[b]本文[/b]"), "教材を装飾として解釈しない")
	check(panel.body.get_v_scroll_bar().value == 0 and not panel.body.get_parsed_text().contains("機密情報"), "前問のスクロールと調査内容をリセット")
	panel.queue_free()
	await process_frame
	print("Audit panel tests: %d failures" % failures)
	quit(1 if failures else 0)
