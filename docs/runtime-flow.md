# 実行時の教材処理

教材の書式・検証は [作問](problem-data.md)、判断の設計は [学習設計](learning-design.md)。読込に失敗した教材では勤務を開始しません。

## 調査から判定まで

初期情報 → Tool → Referenceと比較 → 必要なら結果を次のToolへ → ALLOW/BLOCK。情報の選択後にToolを押すかドラッグし、Referenceは直接開きます（[入力の接続例](problem-data.md#資料と情報の接続)）。

未調査でも判定・進行できます。スコアは `ground_truth` との一致件数で、自由記述を採点しません。`required_evidence` の未確認分は `missing_evidence`、調査は `observations` に記録します。調査不足の評価表示・減点は未実装です。`initial_information` は開始時、Referenceは閲覧時に証拠となり、`evidence_alternatives.any_of` は利用可能な一つで満たします。

外部照会は入力・送信内容・注意文の確認後に模擬送信／見送り（ESC可）。確認中は判定と時計を止めます。適切な送信で得た結果は必須証拠・後続入力に使えます。不適切な送信も結果を表示して理由・件数を残しますが、証拠・後続入力には使えません。見送りも証拠にならず、減点なし。必要な照会を見送っても回答は可能で、不足する証拠はmissing_evidenceに残します。判定スコアとは独立し、未利用サービスに正誤は付けません。

時計は案件をまたいだ経過時間。メニュー・規則集・遊び方・送信確認・監査票・勤務終了で止まり、再開始でリセットします。回帰確認は `tests/test_core.gd` / `test_ui.gd`。

## 対象OSと調査OS

`platform` は対象分類、`investigation_environment` は実行時の調査OS。Windows/Linuxの出題フィルタは該当OS＋共通問題を選びます。OS固有問題はそのOS、共通問題は常にLinuxで調査します。

Toolの `environments` は省略時両OS対応。表示・ドラッグ・直接実行・送信確認・見送りで同じ条件を使います。`platform_note` は説明専用で、出題先OSを製品の対応OSとみなしません（[実装別の確認資料](tool-platform-audit.md)）。

`output_by_environment` のキーは明示した `environments` と一致させ、共有の `output_information` と対象・値を揃えます。Pathや対象が違うなら別問題・別Toolにします。両対応の宣言だけでは別OSの問題や出力は増えません。

代替証拠の例は [Web初級の `dns_lookup`](../data/problems/WEB-BEGINNER-001.json)。同じ証拠とする出力は事実を一致させます（[Linux NetworkのWireshark/tcpdump](../data/problems/NET-LINUX-INTERMEDIATE-001.json)も同じ過去Flowを表示）。

## 画面と責務

| 変更箇所 | 参照先 |
| --- | --- |
| 教材読込・登録・絞り込み | `scripts/core/catalog.gd` |
| Schemaの構造検証、検証済み問題の実行時データ | `scripts/core/content_schema.gd`、`problem_data.gd` |
| 情報の表示・入力型、調査経路・必要証拠 | `scripts/core/information.gd`、`investigation_inputs.gd` |
| 勤務進行・時計・判定・履歴、模擬結果の実行 | `scripts/core/shift.gd`、`tool_runner.gd` |
| 画面遷移・操作状態、部品生成・配置 | `scripts/ui/desk.gd`、`desk_layout.gd` |
| 共通テーマ、カード、情報・スタンプのD&D | `scripts/ui/cyber_theme.gd`、`draggable_card.gd`、`information_token.gd`、`tool_input.gd`、`stamp_tool.gd` |

部品生成は `desk_layout.gd`、部品・操作状態の所有は `desk.gd`。画面ごとのクラス階層や別の状態管理は設けません。カードに正解・採点データを渡さず、UIで表示項目の意味を推測しません。

対象は左に固定。規則集・結果は見出しで移動し、本文は選択・ドラッグ・スクロールに使います。前面化は同じ親の最後の子へ移し、描画順と入力順を一致させます。規則集は閉じても位置・スクロールを保持し、開いたReferenceは再利用します。Tool結果の再表示は再調査です。スタンプは対象の本文・見出し・判定印へのD&Dのみで、Action ID・案件ID・勤務世代を検証し、案件移動・再開始で資料と選択を消します。

遊び方はヘッダーのpillから開く6枚の画像ギャラリー。左右ボタン／矢印キーで移動し、ESCで閉じます。閲覧中は調査・判定を止め、ページと元の操作状態を保持します。画像は `assets/how_to/`、並び順は `desk.gd` の `HOW_TO_SLIDES`。再生成は描画環境で `godot --path . --script tests/capture_how_to.gd` → `python3 scripts/build_how_to_slides.py`（ImageMagick必須）→ Godotのインポート。切り抜き座標は生成スクリプトで管理し、UI変更時は画像も確認します。

位置復帰・三本線メニュー・入力トレー・資料一覧・比較配置・記録ボタン・ログ専用画面・下部説明欄・対象イラストは設けません。メニューはESC。ツール欄と結果は内容で伸縮・スクロールし、カード幅と対象・規則集のサイズは維持します。色・配置の正本は `cyber_theme.gd` / `desk_layout.gd`。

## 教材の境界

全資料・外部照会はローカルJSONの模擬です。実コマンド、外部API、ブラウザー起動、File Uploadは実行しません。任意File解析・自由入力の照会はなく、NPC対話・自動比較・日ごとの進行・永続保存は未実装です。値・出典の制約は [Tool Outputと実例](learning-design.md#tool-outputと実例)。
