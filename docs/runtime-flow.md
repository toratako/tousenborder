# 実行時の教材処理

書式・検証は [教材データ](problem-data.md)、判断の設計は [学習設計](learning-design.md)、保存・分析は [用語と履歴](learning-support.md)。

## 調査から判定まで

初期情報 → Tool → Referenceと比較 → 必要なら結果を次のToolへ → ALLOW/BLOCK（[入力の接続](problem-data.md#資料と情報の接続)）。未調査でも判定でき、スコアは正解との一致件数。自由記述は採点せず、判定時の調査不足表示・減点は未実装です。

不適切な外部照会も結果と理由を記録しますが、必須証拠・後続入力には使えません。見送りも証拠にならず、減点なし。照会の適否は判定スコアと独立し、未利用サービスに正誤は付けません。証拠不足は `missing_evidence`、調査は `observations` に残します。

## 対象OSと調査OS

`platform` は対象分類。OS固有問題はそのOS、共通問題は出題フィルタにかかわらずLinuxで調査します。Toolの `environments` は省略時両OS対応、`platform_note` は説明専用。出題先OSと製品の対応OSは別です。

`result.by_environment` のキーは明示した `environments` と一致させ、共有の `result.information` と対象・値を揃えます。Pathや対象が違うなら別問題・別Toolにします。両対応の宣言だけでは別OSの問題や出力は増えません。

代替証拠は同じ事実を示す出力に限ります。作問例はアーカイブの [Web問題の `dns`](../authoring/archive/problems/WEB-UNKNOWN-CAMPAIGN.json)、[同じ過去Flowを示すWireshark/tcpdump](../authoring/archive/problems/NET-LINUX-SECURITY-TELEMETRY.json)。

## 画面と責務

| 変更箇所 | 参照先 |
| --- | --- |
| ディレクトリ・ZIP・単独JSONの読込、容量・パス制限 | [content_source.gd](../src/content/content_source.gd) |
| 読込元単位の検証・登録・絞込 | [problem_library.gd](../src/content/problem_library.gd) |
| Pack・章参照、追加教材の保存 | [pack_loader.gd](../src/content/pack_loader.gd)、[content_import_store.gd](../src/persistence/content_import_store.gd) |
| Schemaと意味検証、実行時データへの変換 | [content_schema.gd](../src/validation/content_schema.gd)、[problem_loader.gd](../src/content/problem_loader.gd) |
| 表示テンプレート・入力の接続、到達性・必要証拠 | [information.gd](../src/domain/information.gd)、[investigation_inputs.gd](../src/domain/investigation_inputs.gd) |
| 勤務・時計・判定・記録、模擬結果 | [inspection_shift.gd](../src/domain/inspection_shift.gd)、[tool_runner.gd](../src/domain/tool_runner.gd) |
| 部品・操作状態の所有、部品生成・配置 | [game.gd](../src/app/game.gd)、[desk_layout.gd](../src/ui/inspection/desk_layout.gd) |
| テーマ、カード、情報・スタンプのD&D | [game_theme.gd](../src/ui/shared/game_theme.gd)、[draggable_card.gd](../src/ui/inspection/draggable_card.gd)、[information_token.gd](../src/ui/inspection/information_token.gd)、[tool_input.gd](../src/ui/inspection/tool_input.gd)、[stamp_tool.gd](../src/ui/inspection/stamp_tool.gd) |

画面ごとのクラス階層や別の状態管理は設けません。カードに正解・採点データを渡さず、UIで表示項目の意味を推測しません。前面化は同じ親の最後の子へ移し、描画順と入力順を揃えます。Referenceの再表示は再利用、Tool結果の再表示は再調査です。

対象は左に固定し、押印はD&Dのみ。位置復帰・三本線メニュー・入力トレー・資料一覧・比較配置・記録ボタン・ログ専用画面・下部説明欄・対象イラストは設けません。メニューはESC。寸法・伸縮は `desk_layout.gd` と [test_content_sizing.gd](../tests/test_content_sizing.gd)、停止・復帰・古い操作の拒否は [test_ui.gd](../tests/test_ui.gd) / [test_interaction.gd](../tests/test_interaction.gd) を参照。

遊び方の画像は `assets/how_to/`、順序は `game.gd` の `HOW_TO_SLIDES`。UI変更時の再生成は描画環境で `godot --path . --script tests/capture_how_to.gd` → `python3 scripts/build_how_to_slides.py`（ImageMagick必須）→ Godotのインポート。切り抜き座標は生成スクリプトで管理します。

## 教材の境界

全資料・外部照会はローカルJSONの模擬です。実コマンド・外部API・ブラウザー起動・File Upload・任意File解析・自由入力の照会は行いません。NPC対話・自動比較・日ごとの進行・勤務途中の再開は未実装です。
