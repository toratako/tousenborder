extends SceneTree
const Fixtures = preload("res://tests/fixtures.gd")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)


func source_with_pack(pack: Dictionary) -> ContentSource:
	var item := Fixtures.raw("FIX-VISIBLE-FILE")
	item.difficulty = "beginner"
	var source := Fixtures.source([item], "sample")
	source.files["packs/example/pack.json"] = JSON.stringify(pack).to_utf8_buffer()
	return source


func _initialize() -> void:
	var library := ProblemLibrary.new()
	check(library.load_builtin(), str(library.errors))
	for published_pack in library.packs:
		var candidates := library.pack_cases(published_pack.key)
		check(candidates.map(func(item): return item.id) == published_pack.problems, "Packの登録内容と一致")
		var drawn := library.draw_pack_cases(published_pack.key)
		var expected_count: int = published_pack.get("sampling", { "count": candidates.size() }).count
		check(drawn.size() == expected_count, "Packで指定された出題数")
		check(drawn.all(func(item): return item.id in published_pack.problems), "候補外の問題を出題しない")
		if published_pack.has("sampling"):
			var unique := { }
			for item in drawn:
				unique[item.id] = true
			check(unique.size() == drawn.size(), "抽選した問題のIDは重複しない")
	library = ProblemLibrary.new()
	check(library.add_source(Fixtures.sampling_source()), str(library.errors))
	var key := "sampling/pack/random"
	var before := library.pack_cases(key)
	var orders := { }
	var combinations := { }
	var difficulty_distributions := { }
	var mixed_difficulties := false
	for attempt in 30:
		seed(attempt)
		var selected := library.draw_pack_cases(key)
		check(selected.size() == 20, "必ず20問")
		var counts := { }
		var ids := { }
		var order: Array[String] = []
		var previous := ""
		var transitions := 0
		for item in selected:
			check(not ids.has(item.id), "同じ問題は重複しない")
			ids[item.id] = true
			order.append(item.id)
			counts[item.difficulty] = counts.get(item.difficulty, 0) + 1
			if not previous.is_empty() and previous != item.difficulty:
				transitions += 1
			previous = item.difficulty
		mixed_difficulties = mixed_difficulties or transitions > 2
		difficulty_distributions[JSON.stringify(counts)] = true
		orders[JSON.stringify(order)] = true
		order.sort()
		combinations[JSON.stringify(order)] = true
		selected[0].title = "modified"
	check(orders.size() > 1 and combinations.size() > 1, "順番と問題の組み合わせを再抽選")
	check(difficulty_distributions.size() > 1, "難易度別の出題数を固定せずに抽選")
	check(mixed_difficulties, "難易度順に固めず、各レベルを混ぜて出題")
	check(library.pack_cases(key) == before, "抽選と取得結果の編集が教材に影響しない")
	seed(123)
	var expected := library.draw_pack_cases(key)
	seed(123)
	check(library.draw_pack_cases(key, false).size() == 20, "プレビューも20問")
	check(library.draw_pack_cases(key) == expected, "プレビューでは乱数を消費しない")
	check(library.draw_pack_cases("missing").is_empty(), "存在しないPackは空")
	var pack := {
		"schema_version": 3, "id": "example", "title": "Example",
		"problems": ["FIX-VISIBLE-FILE", "FIX-VISIBLE-FILE"],
	}
	check(library.add_source(source_with_pack(pack)), "抽選設定のないPackを受理")
	check(library.draw_pack_cases("sample/pack/example").size() == 2, "従来の指定順・重複を維持")
	pack.sampling = { "count": 1 }
	check(library.add_source(source_with_pack(pack)), "任意のPackにも抽選を設定できる")
	check(library.draw_pack_cases("sample/pack/example").size() == 1, "抽選時は重複IDを一つの候補にする")
	var valid := library.cases.duplicate(true)
	for sampling in [
		{ "count": 2 }, { "count": 0 }, { "count": -1 }, { "count": 1.5 },
		{ "count": "1" }, { "unknown": 1 }, { },
	]:
		pack.sampling = sampling
		check(not library.add_source(source_with_pack(pack)), "候補不足・無効な指定を拒否: " + str(sampling))
		check(library.cases == valid, "無効なPackで既存教材を壊さない")
	print("Pack sampling tests: %d failures" % failures)
	quit(1 if failures else 0)
