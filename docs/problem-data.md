# 教材データと作問

編集対象は `data/packs/*.json` と `data/problems/*.json`。標準教材は `data/packs/learning.json` の24問です。[Pack Schema](../data/schemas/pack.schema.json) と [Problem Schema](../data/schemas/problem.schema.json) をPython生成処理とGodot読込処理で共有します。未知のキー・旧形式・別名は拒否します。`cases / type / fields / evidence / expected` の変換や、未知Metadataの保持は行いません。

[Problem Catalog](problem-catalog.md) は生成一覧、`build/catalog/problems.json` は生成JSONです。問題JSONを編集して再生成します。作問方針・判定時点・拡張計画は [学習設計](learning-design.md)、操作と実行条件は [実行時の教材処理](runtime-flow.md) を参照してください。

## Packのキー

「任意」以外は必須です。別Packの起動は `scenes/main.tscn` の `InspectionDesk` の **Content Pack** にパスを指定します。

| キー | 内容 |
| --- | --- |
| `schema_version`, `id`, `title` | 版1、Pack識別子、表示名。必須 |
| `problems` | `res://data/problems/ID.json` の重複しない配列。1件以上。順序が出題の基準 |
| `rules` | `{id, label, value}` の配列 |
| `categories` | `{id, label}` の配列。問題のカテゴリを登録 |
| `resource_groups` | 任意の `{id, label, kind}` 配列。kindは `tools`, `references`, `external_references`。標準グループのkindはidと同じ |
| `feedback` | 任意。`show_expected`, `show_reason` は真偽値（既定true）、`correct_heading`, `incorrect_heading` は監査票の見出し |

入力条件と必要証拠の確認は常に有効で、無効化フラグはありません。カテゴリ・資料グループは追加できますが、判定種別・難易度・OSの追加にはSchemaと実装の変更が必要です。標準の3資料グループはトップレベル、追加グループだけを問題の `resources` に置きます。

## Problemのキー

| キー | 内容 |
| --- | --- |
| `schema_version`, `id`, `title`, `request` | 版1、一意の問題ID、見出し、判断依頼 |
| `category` | Packに登録したカテゴリID |
| `platform` | `windows`, `linux`, `common` |
| `level` | `very_beginner`, `beginner`, `intermediate`, `advanced` |
| `initial_information` | 表示名をキーとする情報。文字列・数値・真偽値・null・配列・オブジェクト |
| `initial_information_types` | 入力可能な初期情報のキーと型名の対応。表示だけの情報は省略可 |
| `tools`, `references`, `external_references` | 調査資料の配列。空配列も可 |
| `resources` | 任意。Packに登録した追加グループIDから資料配列への対応 |
| `ground_truth`, `explanation` | 正解 `allow` / `block` と根拠の説明 |
| `topic`, `summary`, `learning_objectives` | 学習主題、要約、学習目標の配列 |
| `required_evidence` | 調査の充足を評価する資料IDまたは代替証拠ID。進行は制限しない。初期情報だけなら `initial_information` |
| `evidence_alternatives` | 任意。証拠IDから `{label, any_of: [資料ID…]}` への対応 |
| `decision_context`, `scenario_type` | 判断時点とシナリオ分類 |
| `sources`, `fixture_note` | HTTPS出典URLの配列（空可）と模擬教材の注記 |
| `inspired_by`, `ecosystem` | 任意。実例の着想元、Packageのエコシステム |

任意と明記した項目以外は必須です。`scenario_type: real_world_inspired` には `inspired_by` と1件以上の出典が必要です。ID・型名・情報の文字列は空白だけにできません。`initial_information` と `evidence_alternatives` のキーも空文字・空白だけを拒否します。入力型マップのキーは初期情報に実在し、未指定の型は `text` です。型名は追加できますが、値の構文から型を推測する機能はありません。

超初級は全資料配列を空にし、`required_evidence: ["initial_information"]` とします。判定スコアは `ground_truth` との一致件数で、規則文章や自由記述から推論しません。

## 資料と情報の接続

すべての資料に `id` と `name` を指定し、IDはグループをまたいで問題内で一意にします。Referenceの `content` はJSON値で、クリックすると保存済みの照合資料を表示します。入力条件や旧形式の照合結果 `output` は付けません。

ToolとExternal Referenceには `output`、空でない `accepted_information_types` と `input_bindings`、`input_hint` が必要です。入力は型・取得元・情報IDのすべてに一致させます。複数の `input_bindings` は代替入力（いずれか1つ）です。以下は資料定義の抜粋で、問題の `initial_information` に数値のPID、`initial_information_types` に `"PID": "pid"` を用意します。

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
| URL → Host → OS別DNS、登録Domain → RDAP | [WEB-BEGINNER-001](../data/problems/WEB-BEGINNER-001.json) |
| Email内でHeader・添付・URLを調査する追加グループ | [EMAIL-INTERMEDIATE-001](../data/problems/EMAIL-INTERMEDIATE-001.json) |

External Referenceはさらに `submission_type / submission_value / confidentiality_warning / correct_usage / reason` が必須です。`submission_type` は任意の文字列で、型の適合は送信許可を意味しません。利用適否は [送信確認と評価](runtime-flow.md#調査から判定まで)、Hash検索・Upload・URLの扱いは [学習設計](learning-design.md#外部照会の判断) を参照してください。

## 追加・変更の手順

1. `data/problems/` の近い問題を複製し、新しいID、依頼、初期情報、照合資料、正解と解説を整えます。
2. 入力参照と必要証拠を結び、対応する調査OSのそれぞれで判断まで到達できるようにします。
3. Packの `problems` にパスを追加し、新カテゴリ・追加資料グループがあれば登録します。
4. 検証して一覧を再生成します。

```sh
python -m pip install -r requirements-dev.txt
python scripts/build_problem_catalog.py
python scripts/build_problem_catalog.py --check
godot --headless --path . --script scripts/validate_content.gd -- res://data/packs/learning.json
```

Schemaは形と値域、意味検証はID重複・参照先・登録カテゴリ・資料グループ種別・OS別出力・入力と証拠への到達性を確認します。循環入力、他OSでしか取れない証拠、不適切な外部送信を必須とする問題は拒否します。`--check` は書き換えずに検証し、Markdownは常に、生成JSONは存在する場合だけ一致を確認します。Godot Validatorは成功時0・失敗時1で終了します。
