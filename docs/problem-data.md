# 教材データ

正本は問題JSON。形式は [Problem v2](../data/schemas/problem.schema.json)、[Pack v2](../data/schemas/pack.schema.json)、[Chapter v1](../data/schemas/chapter.schema.json)。公開教材は `data/problems/`、出題・配布対象外は [authoring/archive/](../authoring/archive/README.md)。

## 追加・変更の手順

1. `data/problems/` に単独で検証できる問題JSONを置く。Packへの登録は自由演習には不要。
2. `just validate` でインポート・教材検証。一覧だけが古い場合は次へ。
3. `python3 scripts/build_problem_catalog.py` で一覧を再生成し、`just validate` と `just test`。

最小限の資料付き問題:

```json
{
  "schema_version": 2,
  "id": "EXAMPLE-FILE",
  "category": "file",
  "platform": "common",
  "title": "受入れ可能な文書",
  "request": "この文書を受け入れてよいか判断してください。",
  "initial": {
    "information": [{"id": "filename", "label": "ファイル名", "value": "report.pdf", "data_type": "file"}]
  },
  "resources": [{
    "id": "format", "kind": "references", "name": "受入れ規則",
    "result": {"content": "この受付ではPDFを受け入れます。"}
  }],
  "required_evidence": ["format"],
  "ground_truth": "allow",
  "explanation": "PDFという受入れ条件と一致します。"
}
```

`category` は自由なIDで、必要なら `category_label` を置く。`difficulty` の省略は未評価。調査形式や実例の有無から推測しない。`learning_objectives / sources / inspired_by` は作問・出典追跡用で、判定条件には使わない。

## 資料と情報の接続

資料は `resources` に置き、`kind` は `tools / references / external_references`。`section` は画面のグループ名で、Packに登録不要。調査形式と外部照会の必須性は [investigation_inputs.gd](../src/domain/investigation_inputs.gd) が導出する。

- 初期情報は `initial.information`、再利用する結果は `resource.result.information`。
- `input_bindings` は `{ "source": "資料IDまたはinitial_information", "id": "情報ID" }`。入力型は `accepted_information_types`。同型でも別の情報・未取得の出力は渡せない。
- `result.content` は文字列または構造化JSON。`{{fact:情報ID}}` で同じ結果の情報値、`{{input}}` で選択入力を表示する。出力値は `information` を正本にし、二重記入を避ける。挿入値は再評価しない。
- 外部照会は `submission.type / warning` を持ち、送信値は選択入力そのもの。`correct_usage` を指定する場合は `reason` も必要。
- `required_evidence` は資料ID、`initial_information`、または `evidence_alternatives` のID。代替は `any_of` で指定する。不適切な調査や到達できない入力に依存する必須経路は拒否する。

OS別出力・代替証拠の例は [対象OSと調査OS](runtime-flow.md#対象osと調査os)。

## Pack・章・ZIP

Packは任意の出題順・章の導入だけを管理する。ZIPでは次の構成を直下に置く。

```text
problems/first.json
packs/story/pack.json
packs/story/chapters/01.json
```

`pack.json` は `{ "schema_version": 2, "id": "story", "title": "物語", "chapters": ["chapters/01.json"] }`。
章は `{ "schema_version": 1, "id": "first", "title": "第一章", "intro": "朝の審査を始めます。", "problems": ["EXAMPLE-FILE"] }`。章パスはPackディレクトリからの相対パス、問題IDは同じ読込元を参照する。別章で同じ問題を使える。

タイトルの「問題ZIP / JSONを追加」でZIPまたは単独のProblem JSONを読み込む。全体の検証・保存成功後に登録し、無効な読込元があっても他の教材は維持する。保存先は `user://content/`、内容のSHA-256が識別子。同じ内容の再追加は重複せず、内容変更は別の読込元になる。削除UIは未実装で、不要な教材はアプリ終了後に保存先から削除する。

ZIPはJSONとディレクトリのみ、store/deflateに対応する。暗号化・分割・ZIP64・特殊ファイルは対象外。容量上限は [ContentSource](../src/content/content_source.gd) の `MAX_*`。教材領域へ展開せずに読む。検証は [test_imports.gd](../tests/test_imports.gd)。

```sh
godot --headless --path . --script scripts/validate_content.gd -- /path/to/content.zip
python3 scripts/build_problem_catalog.py --source /path/to/content.zip --json-output build/custom.json --markdown-output build/custom.md
```

## 検証・索引

[ProblemLoader](../src/content/problem_loader.gd) が構造・意味検証の共通入口。[問題一覧](problem-catalog.md) と `build/catalog/problems.json` は生成物で、ゲームは依存しない。`--check` はMarkdownを常に、JSONは存在する場合だけ照合する。責務の索引は [実行時の処理](runtime-flow.md#画面と責務)、用語は [学習支援](learning-support.md)。
