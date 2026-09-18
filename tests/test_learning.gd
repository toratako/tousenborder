extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
## 固定データを実際のUIとcoreで通し、送信前確認・見送り・採点の分離を検証する。
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("失敗: " + message)

func _initialize() -> void:
	_run.call_deferred()

func available_input(shift: InspectionShift, tool: Dictionary) -> Dictionary:
	if tool.get("accepted_information_types", []).is_empty():
		return {}
	var facts: Array = shift.current().information.duplicate(true)
	for observation in shift.observations:
		facts.append_array(observation.get("information", []))
	for fact in facts:
		var token: Dictionary = fact.duplicate(true)
		token.case_id = shift.current().id
		if Information.accepts(tool, token):
			return token
	return {}

func ui_input(desk, tool: Dictionary) -> Dictionary:
	for card in desk.cards:
		for token in card.tokens:
			if Information.accepts(tool, token.payload()):
				return token.payload()
	return {}

func one_case(catalog: ContentCatalog, id: String) -> Array[Dictionary]:
	return catalog.cases.filter(func(c): return c.id == id)

func test_input_contracts(catalog: ContentCatalog) -> void:
	var shift := InspectionShift.new()
	shift.start(one_case(catalog, "FIX-HASH"))
	var item := shift.current()
	var hash_tool: Dictionary = item.tools.filter(func(t): return t.id == "sha256sum")[0]
	var external: Dictionary = item.external_references[0]
	check(not shift.inspect(hash_tool).ok, "FileなしでHash結果は出ない")
	var wrong: Dictionary = item.information.filter(func(i): return i.id == "Size")[0].duplicate(true)
	wrong.case_id = item.id
	check(not shift.inspect(hash_tool, wrong).ok, "SizeからFileのHashは取得できない")
	var unearned := {"id": "sha256", "source": "sha256sum", "data_type": "sha256", "value": external.submission_value, "tool_input": true, "case_id": item.id}
	check(not shift.inspect(external, unearned).ok, "未取得の正しいHashも利用できない")
	var file := available_input(shift, hash_tool)
	check(shift.inspect(hash_tool, file).ok, "FileからSHA-256取得")
	var hash := available_input(shift, external)
	check(not hash.is_empty() and hash.value == external.submission_value, "取得結果が次の入力になる")
	var forged := hash.duplicate(true)
	forged.value = "0".repeat(64)
	check(not shift.inspect(external, forged).ok, "同じID・型でも値の改変は拒否")
	check(shift.inspect(external, hash).ok, "実際に取得したHashで照会できる")
	var stale := hash.duplicate(true)
	shift.start(one_case(catalog, "FIX-PROCESS"))
	item = shift.current()
	var process_tool: Dictionary = item.tools.filter(func(t): return t.id == "process_explorer")[0]
	var get_hash: Dictionary = item.tools.filter(func(t): return t.id == "get_filehash")[0]
	check(available_input(shift, get_hash).is_empty(), "Process調査前はScriptのPathを使えない")
	check(shift.inspect(process_tool, available_input(shift, process_tool)).ok, "PIDから実行Fileを調査")
	var other_file: Dictionary = shift.observations.back().information.filter(func(i): return i.id == "image_file")[0].duplicate(true)
	other_file.case_id = item.id
	check(other_file.data_type == "file" and not shift.inspect(get_hash, other_file).ok, "同じFile型でも別の対象から固定結果を出さない")
	check(shift.inspect(get_hash, available_input(shift, get_hash)).ok, "選択した実行ScriptのHashを取得")
	check(not shift.inspect(get_hash, stale).ok, "前の案件の情報を持ち込めない")

func test_environment_routes(catalog: ContentCatalog) -> void:
	for os in ["windows", "linux"]:
		for item in catalog.select_cases("", "", os):
			var investigation_os: String = "linux" if item.platform == "common" else os
			var shift := InspectionShift.new()
			var cases: Array[Dictionary] = [item]
			shift.start(cases)
			check(shift.current().investigation_environment == investigation_os, "調査OS: " + item.id)
			if item.level != "very_beginner":
				check(shift.decide(item.ground_truth), "未調査でも判定可能: " + item.id)
				check(shift.records.back().missing_evidence == item.required_evidence, "未確認証拠を記録: " + item.id)
				check(shift.advance() and shift.finished(), "未調査でも次へ進める: " + item.id)
				shift.start(cases)
			var pending := catalog.tools_for(item).filter(func(t): return ToolRunner.supports_target(t, item) and t.get("correct_usage", true))
			if item.id == "FIX-DNS":
				# Windowsの出題フィルタでも、共通問題のnslookupはLinux出力になる。
				pending = pending.filter(func(t): return t.id not in ["dig", "resolve_dnsname"])
				var unsupported: Dictionary = item.tools.filter(func(t): return t.id == "resolve_dnsname")[0]
				check(not shift.inspect(unsupported).ok, "他OSのDNS Toolを拒否")
			var progress := true
			while not pending.is_empty() and progress:
				progress = false
				for tool in pending.duplicate():
					var input := available_input(shift, tool)
					if not tool.accepted_information_types.is_empty() and input.is_empty(): continue
					var result := shift.inspect(tool, input)
					check(result.ok, "OS別調査: " + os + "/" + item.id + "/" + tool.id)
					if tool.id == "nslookup":
						check(result.output.contains("C:\\> nslookup") if investigation_os == "windows" else result.output.contains("$ nslookup") and not result.output.contains("C:\\>"), "nslookup出力OS")
					pending.erase(tool)
					progress = true
			check(pending.is_empty() and shift.missing_evidence().is_empty(), "OS別に必要証拠へ到達: " + item.id)
			check(shift.decide(item.ground_truth), "許可された調査で判定可能: " + item.id)
			check(shift.records.back().missing_evidence.is_empty(), "調査済みの証拠は不足に数えない: " + item.id)
	var item := one_case(catalog, "FIX-PRIVATE-FILE")[0]
	var shift := InspectionShift.new()
	var cases: Array[Dictionary] = [item]
	shift.start(cases)
	var external: Dictionary = item.external_references[0].duplicate(true)
	external.environments = ["linux"]
	check(not shift.decline_external(external, available_input(shift, external)), "非対応OSでは見送りも拒否")

func _run() -> void:
	var catalog := Fixtures.catalog()
	check(catalog.load_pack("res://data/packs/learning.json"), "代表教材読込: " + str(catalog.errors))
	if not catalog.errors.is_empty():
		quit(1)
		return
	check(catalog.cases.size() == Fixtures.pack().problems.size(), "固定テストデータの登録件数")
	check(catalog.categories.size() == 7, "7種別")
	for platform in ["windows", "linux"]:
		var selected := catalog.select_cases("", "", platform)
		check(selected.any(func(c): return c.platform == "common"), "共通問題も含める")
		check(selected.all(func(c): return c.platform in [platform, "common"]), "OSの絞り込み")
	check(catalog.select_cases("", "", "common").all(func(c): return c.platform == "common"), "共通のみ選択")
	var guide := catalog.guide_tools()
	for tool in guide:
		check(not tool.get("platform_note", "").is_empty(), "利用環境の説明漏れ: " + tool.id)
	check(guide.any(func(t): return t.id == "get_filehash"), "問題内Toolのガイド")
	test_input_contracts(catalog)
	test_environment_routes(catalog)
	# 全問の全資料を実行し、見送りを含めて正解・解説を保存する。
	var shift := InspectionShift.new()
	shift.start(catalog.cases)
	for item in catalog.cases:
		if item.level == "very_beginner":
			check(catalog.tools_for(item).is_empty() and item.required_evidence == ["initial_information"], "超初級は初期情報のみ")
		if item.category == "account":
			check(item.decision_context == "before_session", "認証問題は成立前")
		if item.category == "process":
			check(item.decision_context == "running_process", "Processだけ実行中")
		var pending := catalog.tools_for(item).filter(func(t): return ToolRunner.supports_target(t, shift.current()))
		var progress := true
		while not pending.is_empty() and progress:
			progress = false
			for resource in pending.duplicate():
				var input := available_input(shift, resource)
				if not resource.accepted_information_types.is_empty() and input.is_empty():
					continue
				if resource.resource_kind != "references":
					check(not shift.runner.run(resource, item).ok, "全Toolで入力なしを拒否")
				if resource.get("correct_usage", true):
					check(shift.inspect(resource, input).ok, "模擬調査: " + item.id + "/" + resource.id)
				else:
					check(shift.decline_external(resource, input), "不適切な送信の見送り")
					check(shift.observations.back().get("skipped", false), "見送りの履歴")
				pending.erase(resource)
				progress = true
		check(pending.is_empty(), "全資料に到達可能: " + item.id)
		check(shift.decide(item.ground_truth), "正解を記録")
		check(shift.records.back().explanation == item.explanation, "解説を保持")
		shift.advance()
	check(shift.finished() and shift.score() == catalog.cases.size() and shift.unsafe_investigations() == 0, "固定テストデータ完了・判定と調査を分離")
	# 主シーンからUIを操作し、誤った外部送信と見送りの両方を検証する。
	var desk = Fixtures.desk()
	for tool_id in ["resolve_dnsname", "nslookup", "dig", "wireshark"]:
		var tool: Dictionary = guide.filter(func(t): return t.id == tool_id)[0]
		check(tool.has("platform_note"), "Tool固有の利用環境: " + tool_id)
		check(tool.platform_note.contains("Windows") if tool_id == "resolve_dnsname" else tool.platform_note.contains("Linux"), "実際の利用環境: " + tool_id)
	var dns: Dictionary = guide.filter(func(t): return t.id == "resolve_dnsname")[0]
	var capture: Dictionary = guide.filter(func(t): return t.id == "wireshark")[0]
	check(dns.environments == ["windows"] and capture.environments == ["windows", "linux"], "Toolの実行OSを保持")
	root.add_child(desk)
	await process_frame
	check(desk._tool_description(dns).contains("Toolの主な利用環境: Windows") and not desk._tool_description(dns).contains("教材の出題環境:"), "ガイドはToolの利用OSを表示")
	check(desk._tool_description(capture).contains("Windows / Linux"), "Wiresharkの両対応を表示")
	desk.tool_guide_button.pressed.emit()
	check(desk.tool_guide_tabs.size() == guide.size() and not desk.tool_guide_body.text.contains("登録されているツールはありません"), "新教材のガイドを表示")
	desk.tool_guide_close.pressed.emit()
	# Windowsで絞って開始しても、共通問題はLinuxのTool・入力制限を使う。
	for selection in [desk.platform_select, desk.category_select, desk.difficulty_select]:
		var value: String = "windows" if selection == desk.platform_select else ("web" if selection == desk.category_select else "beginner")
		for i in range(selection.item_count):
			if selection.get_item_metadata(i) == value: selection.select(i)
	desk._refresh_selection()
	desk.start_button.pressed.emit()
	var linux_web: Dictionary = desk.shift.current()
	check(linux_web.id == "FIX-DNS", "画面の選択条件から共通Web問題を開始")
	check(desk.shift.current().platform == "common" and desk.shift.current().investigation_environment == "linux", "問題OSと調査OSを保持")
	var windows_tool: Dictionary = linux_web.tools.filter(func(t): return t.id == "resolve_dnsname")[0]
	var linux_button: ToolInput = desk.tool_buttons.filter(func(b): return b.tool.id == "dig")[0]
	check(not desk.tool_buttons.any(func(b): return b.tool.id == "resolve_dnsname") and linux_button.visible, "共通Web問題でもOS別にToolを表示")
	var parse: Dictionary = linux_web.tools.filter(func(t): return t.id == "url_parse")[0]
	desk._inspect(parse, available_input(desk.shift, parse))
	var host := available_input(desk.shift, linux_button.tool)
	var before_os: int = desk.shift.observations.size()
	desk._inspect(windows_tool, host)
	check(desk.shift.observations.size() == before_os, "直接UI呼び出しもOSを検証")
	check(desk._can_stamp(desk.get_stamp(linux_web.ground_truth).payload()), "必要証拠が揃う前でも押印可能")
	desk._show_start_screen()
	desk.platform_select.select(0)
	desk.category_select.select(0)
	desk.difficulty_select.select(0)
	desk.start_button.pressed.emit()
	for item in catalog.cases:
		check(desk.shift.current().id == item.id, "画面の出題順")
		check(desk.target_card.title_label.text == "検査対象", "対象のタイトルを統一")
		var pending_buttons: Array = desk.tool_buttons.filter(func(b): return b.visible)
		var progress := true
		while not pending_buttons.is_empty() and progress:
			progress = false
			for button in pending_buttons.duplicate():
				var tool: Dictionary = button.tool
				var input := ui_input(desk, tool)
				if not tool.accepted_information_types.is_empty() and input.is_empty():
					continue
				var before: int = desk.shift.observations.size()
				desk._select_information({})
				if not tool.accepted_information_types.is_empty():
					check(button.hint.visible and button.hint.text.contains(tool.input_hint), "必要な入力をボタンに表示")
					button.pressed.emit()
					check(desk.shift.observations.size() == before and not desk.external_preview.visible, "全Toolでクリックのみでは結果を出さない")
					var wrong: Dictionary = desk.target_card.tokens[0].payload()
					button._drop_data(Vector2.ZERO, {"kind": "information", "information": wrong})
					check(desk.shift.observations.size() == before, "不適切なドラッグは実行されない")
					check(button._can_drop_data(Vector2.ZERO, {"kind": "information", "information": input}), "取得済みの対応情報はドラッグ可能")
					if before % 2 == 0:
						button._drop_data(Vector2.ZERO, {"kind": "information", "information": input})
					else:
						desk._select_information(input)
						button.pressed.emit()
				else:
					button.pressed.emit()
				if tool.resource_kind == "external_references":
					check(desk.external_preview.visible and desk.shift.observations.size() == before, "確認前には調査しない")
					check(desk.external_preview_body.text.contains(tool.submission_value), "送信する具体的な情報を表示")
					check(desk.external_preview_body.text.contains(Information.display(input.value)), "選択した入力を送信前に確認")
					check(not desk.external_preview_body.text.contains(tool.output), "実行前に調査結果を漏らさない")
					check(not desk._can_stamp(desk.get_stamp(item.ground_truth).payload()), "確認中の判定を防ぐ")
					var elapsed: float = desk.shift.elapsed_seconds
					desk._process(1)
					check(desk.shift.elapsed_seconds == elapsed, "確認文を読む間は時計停止")
					if tool.id == "urlscan_private":
						desk.external_skip.pressed.emit()
						check(desk.shift.observations.back().get("skipped", false), "UIの見送りを保存")
					else:
						desk.external_send.pressed.emit()
					check(not desk.external_preview.visible, "確認画面を閉じる")
				check(desk.shift.observations.size() == before + 1, "各資料につき調査1件")
				check(desk.cards.back().card_data.title.begins_with(tool.label), "調査結果をカード表示")
				pending_buttons.erase(button)
				progress = true
		check(pending_buttons.is_empty(), "UIの情報から全調査を実行可能: " + item.id)
		# スタンプのドラッグ結果と同じ判定経路。アニメーション待ちだけ省略する。
		check(desk._can_stamp(desk.get_stamp(item.ground_truth).payload()), "対象にスタンプを使用可能")
		desk.shift.decide(item.ground_truth)
		check(desk.audit_body.text.contains(item.explanation), "UIに全問の解説")
		if item.id == "FIX-PRIVATE-FILE":
			check(desk.shift.records.back().correct and desk.audit_body.text.contains("不適切な利用"), "正解でも不適切なFile Uploadを明示")
		if item.id == "FIX-PRIVATE-URL":
			check(desk.audit_body.text.contains("外部送信を見送り"), "Token付きURLを送らなかった記録")
		desk.next.pressed.emit()
		await process_frame
	check(desk.shift.score() == catalog.cases.size() and desk.shift.unsafe_investigations() == 1, "全件正解・不適切調査1件")
	check(desk.summary_stats.text.contains("不適切な調査 1件"), "調査手段の集計")
	check(desk.summary_review.get_parsed_text().contains("不適切な利用") and desk.summary_review.get_parsed_text().contains("外部送信を見送り"), "一覧でも調査の適否を確認")
	# 確認途中のリスタートが古い案件の資料を実行しないこと。
	desk._start_shift()
	var token_case: Dictionary = catalog.cases.filter(func(c): return c.id == "FIX-PRIVATE-URL")[0]
	var token_cases: Array[Dictionary] = [token_case]
	desk.shift.start(token_cases)
	var unsafe_tool: Dictionary = catalog.tools_for(token_case).filter(func(t): return t.id == "urlscan_private")[0]
	desk._inspect(unsafe_tool, available_input(desk.shift, unsafe_tool))
	desk._process(2)
	check(desk.shift.elapsed_seconds == 0, "送信確認中は経過時間の計測を停止")
	desk._start_shift()
	desk._finish_external(true)
	check(desk.pending_external.is_empty() and desk.shift.observations.is_empty(), "リスタートで保留中の外部照会を破棄")
	desk.queue_free()
	await process_frame
	print("代表教材・安全な調査のテスト: 失敗 %d件" % failures)
	quit(1 if failures else 0)
