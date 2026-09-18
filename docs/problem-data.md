# 教材データと作問

正本は `data/packs/*.json` と `data/problems/*.json`。キー・必須条件・値域は [Pack Schema](../data/schemas/pack.schema.json) / [Problem Schema](../data/schemas/problem.schema.json)、動く問題は [生成一覧](problem-catalog.md) から辿れます。未知キー・旧形式・別名は拒否し、変換しません。

## PackとProblemの注意点

- 別Packは `scenes/main.tscn` の `InspectionDesk` → **Content Pack** に指定。`problems` の登録順が出題順です。
- カテゴリ・資料グループはPackで追加可能。判定種別・難易度・OSの追加にはSchemaと実装の変更が必要です。
- 標準の `tools / references / external_references` は問題のトップレベル、追加グループだけを `resources` に置きます。標準グループのkindは変更できません。
- `initial_information_types` は初期情報のキーと型名の対応。未指定は `text` で、値から型を推測しません。型名は追加できます。
- 超初級は資料なし、`required_evidence: ["initial_information"]`。`required_evidence` は調査充足の定義で、進行条件ではありません（[判定・履歴](runtime-flow.md#調査から判定まで)）。

## 資料と情報の接続

Referenceは入力不要の `content` を表示します。Tool・External Referenceは `accepted_information_types` と `input_bindings` で入力を指定し、型・取得元・情報IDを照合します。複数のbindingはいずれか1つを使う代替入力です。

以下は資料定義の抜粋です。初期情報に数値のPID、型マップに `"PID": "pid"` を用意します。

```json
{
  "id": "process_lookup",
  "name": "Process情報",
  "output": "Image: /opt/example/agent",
  "accepted_information_types": ["pid"],
  "input_bindings": [{"source": "initial_information", "id": "PID"}],
  "input_hint": "調査するPID",
  "environments": ["linux"],
  "output_information": [
    {"id": "image", "label": "実行File", "value": "/opt/example/agent", "data_type": "file"}
  ]
}
```

`output_information` の `id / label / value / data_type` は必須、`tool_input / draggable` は真偽値（既定true）です。値は `output` と一致させます。`draggable: false` はドラッグだけを禁止し、入力も禁止するなら `tool_input: false` を指定します。取得元は資料から設定するため `source` は書けません。Referenceも同じ方式で入力用の情報を返せます。

次のFile調査には `accepted_information_types: ["file"]` と `input_bindings: [{"source": "process_lookup", "id": "image"}]` を指定します。出力情報IDの `output / content / submission_type / submission_value / warning` は予約済みです。

| 作りたい調査経路 | 動く例 |
| --- | --- |
| File → SHA-256 → 外部Hash検索、Vendor公開値との照合 | [FILE-LINUX-BEGINNER-002](../data/problems/FILE-LINUX-BEGINNER-002.json) |
| PID → 実行ScriptのPath → Hash（Process本体と区別） | [PROC-WIN-ADVANCED-001](../data/problems/PROC-WIN-ADVANCED-001.json) |
| URL → Host → DNS、登録Domain → RDAP | [WEB-BEGINNER-001](../data/problems/WEB-BEGINNER-001.json) |
| Email内でHeader・添付・URLを調査する追加グループ | [EMAIL-INTERMEDIATE-001](../data/problems/EMAIL-INTERMEDIATE-001.json) |

入力は値・案件・取得済みかも照合します。同じFile型でもProcess本体と実行Script、同じHashでもVendor公開値と手元の取得値は別です。Hostと登録Domainも同一とは限らず、RDAPの入力元は登録Domainの台帳等から指定します。

External Referenceの入力型への適合は送信許可を意味しません。[送信確認](runtime-flow.md#調査から判定まで) と [外部照会の判断](learning-design.md#外部照会の判断) を参照してください。

## 追加・変更の手順

近い問題を複製して新しいIDを付け、Packの `problems` に登録します。[学習設計](learning-design.md) に沿って独立した照合資料から結論を導ける構成にし、問題の調査OS（共通問題はLinux）で入力・必要証拠に到達できるようにします。

```sh
python3 scripts/build_problem_catalog.py
just test
```

依存の準備は [README](../README.md#開発教材編集)。生成先は `docs/problem-catalog.md` と `build/catalog/problems.json`（Git管理外）。生成処理の `--check` はMarkdownを常に、JSONは存在する場合だけ比較します。別Packの検証は `godot --headless --path . --script scripts/validate_content.gd -- res://data/packs/別名.json`（成功0・失敗1）。

検証の分担:

- 構造は共有Schema。PythonはDraft 2020-12、Godotの `content_schema.gd` は同梱Schemaの構文のみ対応し、未知キーワードはエラー、深度上限128です。Schema拡張時は両方を検証します。
- 意味・到達性は `scripts/build_problem_catalog.py` と `scripts/core/problem_data.gd` / `investigation_inputs.gd`。循環入力、非対応OSの必須証拠、不適切な調査・外部送信に依存する経路を拒否します。外部照会を代替証拠に含めても、内部で取得する手段が必要です。
- 資料の意味、出力の事実整合、判定時点は自動検証できません。作問時に確認し、実行経路は `tests/test_learning.gd` で確認します。
