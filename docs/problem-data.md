# 教材データ

正本は問題JSON。形式は [Problem v2](../data/schemas/problem.schema.json)、[Pack v2](../data/schemas/pack.schema.json)、[Chapter v1](../data/schemas/chapter.schema.json)。旧形式・未知キーは拒否する。公開70問は `data/problems/`、出題対象外39問は `authoring/archive/problems/` に隔離し、後者は配布にも含めない。

## 追加・変更の手順

1. `data/problems/` に単独で検証できる問題JSONを置く。Packへの登録は自由演習には不要。
2. `just validate`。構造・資料参照・入力の到達性をゲームと同じローダで検証する。
3. `python3 scripts/build_problem_catalog.py` で一覧を再生成して `just test`。生成前の `--check` は一覧の差分があれば失敗する。

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

`category` は自由なIDで、必要なら `category_label` を問題に置く。選択肢はロードした問題から生成する。`difficulty` は任意の `beginner / intermediate / advanced`。省略は未評価で、調査形式や実例の有無から推測しない。移行済みの公開問題は未評価。`learning_objectives / sources / inspired_by` は作問・出典追跡用で、判定条件には使わない。

## 資料と情報の接続

資料は `resources` に統一し、`kind` は `tools / references / external_references`。任意の `section` は画面のグループ名で、Packに登録不要。ゲームの調査形式と外部照会の必須性は、対応OS・資料種別・入力経路・必要証拠から導出する。

- 初期情報は `initial.information`、結果の再利用可能な情報は `resource.result.information`。型と値を一つのオブジェクトに持つ。
- `input_bindings` は `{ "source": "資料IDまたはinitial_information", "id": "情報ID" }`。入力型は `accepted_information_types`。同型でも別の情報・未取得の出力は渡せない。
- `result.content` は文字列または構造化JSON。`{{fact:情報ID}}` で同じ結果の情報値、`{{input}}` で選択入力を表示でき、挿入した値は再評価しない。二重記入を避けるため出力値は `information` を正本にする。
- 外部照会は `submission.type / warning` を持つ。送信値は選択入力そのもので、別の `submission_value` は記入しない。
- `required_evidence` は資料ID。`evidence_alternatives` で複数資料のいずれかを認める。不適切な調査や到達できない入力に依存する必須経路は拒否する。
- `correct_usage` を指定する場合は `reason` も必要。結果はすべて模擬JSONで、実コマンド・外部通信は実行しない。

OS別出力は `result.by_environment`。明示した `environments` とキーを一致させ、共通の `result.information` と事実を一致させる。共通問題の調査OSはLinux（詳細は [実行時の処理](runtime-flow.md#対象osと調査os)）。

## Pack・章・ZIP

Packは任意の出題順・章の導入を管理する。問題の分類辞書、規則集、用語辞書は持たない。

```text
problems/
  first.json
  second.json
packs/
  story/
    pack.json
    chapters/
      01.json
      02.json
```

`pack.json` は `{ "schema_version": 2, "id": "story", "title": "物語", "chapters": ["chapters/01.json", "chapters/02.json"] }`。
章は `{ "schema_version": 1, "id": "first", "title": "第一章", "intro": "朝の審査を始めます。", "problems": ["EXAMPLE-FILE"] }`。章パスはPackディレクトリからの相対パス、問題IDは同じ読込元の問題を参照する。別章で同じ問題を使える。章の導入は任意で、表示中は時計と調査・判定を止める。

この構成をZIPの直下に置き、タイトルの「問題ZIP / JSONを追加」から読み込む。単独のProblem JSONも追加可能。全体の検証と保存に成功してから登録し、失敗時は既存教材を維持する。追加した教材は `user://content/` に内容のSHA-256名で保存し、次回起動時も読み込む。同じ内容の再追加は重複しない。異なる内容は別の読込元として共存する。削除UIは未実装で、不要な教材はアプリ終了後に保存先から削除する。

ZIPはJSONとディレクトリのみ。通常のstore/deflateに対応し、暗号化・分割・ZIP64・特殊ファイルは対象外。上限は512エントリ、JSONごと1 MiB、展開後合計8 MiB、ZIP本体16 MiB（`ContentSource`）。ファイルを教材領域へ展開せず、相対パスとJSONとして読む。

```sh
godot --headless --path . --script scripts/validate_content.gd -- /path/to/content.zip
python3 scripts/build_problem_catalog.py --source /path/to/content.zip --json-output build/custom.json --markdown-output build/custom.md
```

## 検証・索引

`ProblemLoader` が構造・意味検証の一つの入口。`ContentSource` は格納形式、`PackLoader` は章参照、`ProblemLibrary` は登録・絞込、`ContentImportStore` は保存を担当する。CLIも同じコードを呼ぶ。

手書き `data/catalog/` は廃止。[問題一覧](problem-catalog.md) と `build/catalog/problems.json` は問題JSONから生成する索引。`--check` はMarkdownを常に、JSONは存在する場合だけ照合する。ゲームは生成一覧に依存しない。用語と履歴の形式・互換性は [学習支援](learning-support.md)。
