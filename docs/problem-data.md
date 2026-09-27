# 教材データと作問

正本は `data/packs/*.json` と `data/problems/*.json`。キー・必須条件・値域は [Pack Schema](../data/schemas/pack.schema.json) / [Problem Schema](../data/schemas/problem.schema.json)、動く問題は [生成一覧](problem-catalog.md) から辿れます。未知キー・旧形式・別名は拒否し、変換しません。

## PackとProblemの注意点

- 別Packは `scenes/main.tscn` の `InspectionDesk` → **Content Pack** に指定。`problems` の登録順が出題順です。
- カテゴリ・資料グループはPackで追加可能。判定種別・難易度・OSの追加にはSchemaと実装の変更が必要です。
- 初級の `level` は `beginner_reference`（Referenceのみ）、`beginner`（Tool）、`beginner_external`（External Referenceあり）。追加グループも含む資料種別で分類を検証し、`beginner` のレビュー手順ではToolをちょうど1つ使うことを確認します。代替Toolの選択肢は複数登録できます。
- 標準の `tools / references / external_references` は問題のトップレベル、追加グループだけを `resources` に置きます。標準グループのkindは変更できません。
- `initial_information_types` は初期情報のキーと型名の対応。未指定は `text` で、値から型を推測しません。型名は追加できます。
- 超初級はReferenceを調査欄で閲覧できます。Tool・External Referenceは追加グループを含め使用不可。`required_evidence` には初期情報と必要なReference（代替証拠も可）を指定します。Referenceは閲覧後に証拠へ加わります。調査充足は進行条件ではありません（[判定・履歴](runtime-flow.md#調査から判定まで)）。

## 資料と情報の接続

Referenceは入力不要の `content` を表示します。Tool・External Referenceは `accepted_information_types` と `input_bindings` で入力を指定し、型・取得元・情報IDを照合します。複数のbindingはいずれか1つを使う代替入力です。

辞書・配列の値は項目名と箇条書きで表示します。JSONやCommandの抜粋をそのまま見せる場合は文字列で記述してください。表示だけを整形し、Toolへ渡す元の値・型は保持します。

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
| File → SHA-256 → 外部Hash検索 | [FILE-LINUX-KNOWN-HASH](../data/problems/FILE-LINUX-KNOWN-HASH.json) |
| PID → 実行ScriptのPath → Hash（Process本体と区別） | [PROC-WIN-ADMIN-POWERSHELL](../data/problems/PROC-WIN-ADMIN-POWERSHELL.json) |
| 受付済みHost → DNS、登録Domain → 外部RDAP照会 | [WEB-UNKNOWN-CAMPAIGN](../data/problems/WEB-UNKNOWN-CAMPAIGN.json) |
| Email内でHeader・添付・URLを調査する追加グループ | [EMAIL-GENUINE-URGENT](../data/problems/EMAIL-GENUINE-URGENT.json) |

入力は値・案件・適切な調査で取得済みかも照合します。同じFile型でもProcess本体と実行Script、同じHashでもVendor公開値と手元の取得値は別です。Hostと登録Domainも区別します。RDAPはExternal Referenceとし、入力値・送信値・出力の照会対象を一致させます。登録DomainがHostと異なる場合は別の型付き情報を用意し、送信前に外部照会方針を確認する手順を記載します。

ProcessのBacking Executableを直接調査する場合は、初期情報のPIDを入力にし、対象Pathと結果をoutputに明記できます。ScriptのHashとは別資料にします。Windows用DNS Toolを使う問題はplatformをwindowsにし、commonの調査OSはLinuxのままとします。

External Referenceの入力型への適合は送信許可を意味しません。[送信確認](runtime-flow.md#調査から判定まで) と [外部照会の判断](learning-design.md#外部照会の判断) を参照してください。

## 追加・変更の手順

近い問題を複製して新しいIDを付け、Packの `problems` に登録します。[学習設計](learning-design.md) に沿って独立した照合資料から結論を導ける構成にし、問題の調査OS（共通問題はLinux）で入力・必要証拠に到達できるようにします。

```sh
python3 scripts/build_problem_catalog.py
just test
```

依存の準備は [README](../README.md#開発教材編集)。生成先は `docs/problem-catalog.md` と `build/catalog/problems.json`（Git管理外）。生成処理の `--check` はMarkdownを常に、JSONは存在する場合だけ比較します。別Packの検証は `godot --headless --path . --script scripts/validate_content.gd -- res://data/packs/別名.json`（成功0・失敗1）。

レビュー用の説明は [data/catalog/learning.json](../data/catalog/learning.json)。Packと同じFile名で `data/catalog/` に置き、[Review Schema](../data/schemas/catalog-review.schema.json) に従って全登録IDの `overview / flow / decisive_evidence` を記述します。`flow` は資料IDと確認内容の順序付き配列で、初期情報は常に取得済みとし、必要な入力を先に取得する代表経路を記載します。代替証拠は利用可能な経路を一つ選びます。機密Uploadなど不適切な調査は実行手順にせず、方針を読む手順に見送りを記述してください。問題JSONの変更時には説明も再確認し、未解決の不足がある場合だけ `review_notes` に記載し、問題側で解消したら削除します。これらはゲームUIへ読み込みません。

初期情報・全調査候補・正解・理由・学習目標は問題JSONから直接転記します。Main Evidenceはrequired_evidence、Main Toolはその入力元も含む経路から導出し、代替候補を併記します。レビューJSONがあるPackでは登録IDの過不足、手順の入力順序・OS適合・適切な利用・必須証拠の充足も検証します。レビューJSONがない別Packは想定手順・決定的証拠を「未レビュー」と表示し、自動推測しません。

検証の分担:

- 構造は共有Schema。PythonはDraft 2020-12、Godotの `content_schema.gd` は同梱Schemaの構文のみ対応し、未知キーワードはエラー、深度上限128です。Schema拡張時は両方を検証します。
- 意味・到達性は `scripts/build_problem_catalog.py` と `scripts/core/problem_data.gd` / `investigation_inputs.gd`。循環入力、非対応OSの必須証拠、不適切な調査・外部送信に依存する経路を拒否します。correct_usageがtrueの外部照会は必須・代替証拠と後続入力に利用できます。内部調査だけの代替経路は必須ではありません。
- 資料の意味、出力の事実整合、判定時点は自動検証できません。作問時に確認し、出題用Packの全問の実行経路・送信確認・解説表示は `tests/test_playable_content.gd` で確認します。
- UI・入力契約の回帰テストは `tests/fixtures/content.json` と `tests/fixtures.gd` の固定データを使用します。通常のPackには登録せず、既存教材の件数・IDを維持するために問題を残す必要はありません。外部証拠の必須化・後続入力・見送りは `tests/test_external_evidence.gd` とPython側でも検証します。
