extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("失敗: " + description)

func _initialize() -> void:
	var catalog := ContentCatalog.new()
	check(catalog.load_pack(), "基礎教材の検証: " + str(catalog.errors))
	check(catalog.cases.size() == 6, "模擬案件は6件")
	var shift := InspectionShift.new()
	shift.start(catalog.cases)
	check(not shift.advance(), "未判定の案件は飛ばせない")
	check(not shift.decide("unknown"), "不正な判定値を拒否")
	check(not shift.inspect(catalog.tools[1]).ok, "非対応のツールを拒否")
	check(shift.inspect(catalog.tools[0]).ok, "対応する調査結果を取得")
	check(shift.decide("approve"), "誤判定も採点のために記録")
	check(shift.score() == 0, "誤判定では正解数が増えない")
	check(not shift.decide("deny"), "二重判定を防止")
	check(not shift.inspect(catalog.tools[0]).ok, "終了した案件は調査できない")
	check(shift.records[0].observations.size() == 2, "記録に調査履歴を含む")
	shift.advance()
	check(shift.observations.is_empty(), "次の案件で調査結果を消去")
	while not shift.finished():
		for tool in catalog.tools:
			if shift.current().type in tool.target_types:
				check(shift.inspect(tool).ok, "模擬調査結果を取得: " + tool.id)
		shift.decide(shift.current().expected)
		shift.advance()
	check(shift.score() == 5 and shift.records.size() == 6, "勤務の採点と終了")
	check(not shift.advance() and not shift.decide("deny"), "勤務終了後の操作を防止")
	shift.start(catalog.cases)
	check(shift.records.is_empty() and shift.index == 0, "再開始で勤務を初期化")
	var runner := ToolRunner.new()
	var tool: Dictionary = catalog.tools[0].duplicate(true)
	tool.provider = "missing"
	check(not runner.run(tool, catalog.cases[0]).ok, "未登録の処理を検出")
	runner.register_provider("custom", func(_tool, _target): return {"ok": true, "output": "独自の調査結果"})
	tool.provider = "custom"
	check(runner.run(tool, catalog.cases[0]).output == "独自の調査結果", "独自処理への拡張")
	runner.register_provider("broken", func(_tool, _target): return null)
	tool.provider = "broken"
	check(not runner.run(tool, catalog.cases[0]).ok, "不正な処理結果を検出")
	tool.provider = "fixture"
	var target: Dictionary = catalog.cases[0].duplicate(true)
	target.evidence.clear()
	check(not runner.run(tool, target).ok, "証拠の欠落を安全と扱わない")
	check(catalog.time_limit_seconds == 300, "教材から制限時間を読み込む")
	shift.start(catalog.cases, 10)
	shift.tick(2.5)
	check(shift.remaining_seconds == 7.5, "残り時間を減算")
	shift.decide("deny")
	shift.tick(100)
	check(shift.remaining_seconds == 7.5 and not shift.timed_out, "監査票の確認中は停止")
	shift.advance()
	shift.tick(8)
	check(shift.timed_out and shift.finished() and shift.remaining_seconds == 0, "超過分を0に丸めて勤務終了")
	check(shift.records.size() == 1 and shift.score() == 1, "未審査を誤判定として記録しない")
	check(not shift.decide("approve") and not shift.advance(), "時間切れ後の判定と進行を防止")
	check(not shift.inspect(catalog.tools[0]).ok, "時間切れ後の調査を防止")
	shift.start(catalog.cases, 10)
	check(not shift.timed_out and shift.remaining_seconds == 10, "再開始でタイマーを復元")
	shift.tick(10)
	check(shift.timed_out, "残り時間と同じ経過時間でも終了")
	shift.start(catalog.cases, 0)
	shift.tick(100000)
	check(not shift.finished(), "0秒設定は時間制限なし")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	for invalid in [-1, 1.5, "300", null, 86401]:
		pack.time_limit_seconds = invalid
		var file := FileAccess.open("user://invalid_timer.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(pack))
		file.close()
		check(not catalog.load_pack("user://invalid_timer.json"), "不正な時間設定を拒否: " + str(invalid))
	pack.erase("time_limit_seconds")
	var legacy_file := FileAccess.open("user://invalid_timer.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(pack))
	legacy_file.close()
	check(catalog.load_pack("user://invalid_timer.json") and catalog.time_limit_seconds == 0, "既存教材は時間指定なしでも読み込める")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://invalid_timer.json"))
	check(not catalog.load_pack("res://data/missing.json"), "教材欠落時に診断を表示")
	print("コアテスト: 失敗 %d件" % failures)
	quit(1 if failures else 0)
