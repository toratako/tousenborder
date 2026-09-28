# 用語と履歴

| 対象 | 編集先 |
| --- | --- |
| ゲーム共通の用語 | `data/glossary/security.json` |
| 問題固有の定義 | 問題の任意 `glossary`（ID → label / description） |
| 用語の登場箇所 | `initial.terms`、資料の `terms`、`result.terms`、`submission.terms` |
| 閲覧済み用語の抽出 | `scripts/core/glossary.gd` |
| 記録・保存 | `scripts/core/shift.gd`、`history_store.gd` |
| 履歴形式 | `data/schemas/history.schema.json` |
| 再挑戦の解決 | `scripts/core/wrong_answer_retry.gd` |

用語の対応は、その表示箇所にID配列を置く。従来の全用語→全登場箇所という逆引きの重複を持たない。初期情報・資料案内は問題表示時、結果は実行時、送信注意文は確認画面で解禁する。見送りで結果用語を解禁しない。共通辞書はゲームの任意の補助で、ProblemLoaderの依存ではない。問題固有の定義が同名の共通定義に優先し、定義のないIDは表示しない。公開教材のIDの誤りはテストで検出する。

Port（通信／端末）やResolver（DNS／パッケージ）は文脈別IDを使う。文字列の機械検索で関連付けず、title・explanationから未閲覧の情報を先出ししない。説明に正解や未閲覧の事実を書かない。検索対象は閲覧済み用語の名前・説明だけで、大小文字は無視する。

履歴は勤務終了時に `user://history/` へ保存する。途中再開は対象外。新規はversion 3、既存version 2も読める。判定・解説・初期情報・調査記録を保存し、教材がなくても当時の結果を表示する。記録ごとに `source_id / definition_hash / category_label / method` を追加した。保存上の `level` は互換性のため維持し、新規の値は問題の `difficulty`。

再挑戦は読込元IDと問題IDで現行の検証済み問題を選ぶ。別Packに所属していても同じ問題を使え、同名の別教材で代用しない。重複は一度、未読込・削除済みは除外。定義が変わっていれば案内する。旧version 2のlearning Packはbuiltinに対応する。再挑戦も別の勤務として保存し、`retry_of` に元勤務IDを残す。

保存上限は最新100勤務。保存成功後に超過分を削除し、削除失敗時は次回再試行する。破損・未知版・一時ファイルは削除対象外。同IDの異なる内容で上書きしない。`*.index.json` は履歴本体のSHA-256で照合する派生索引で、不足・破損時は本体から再生成する。

検証先は `test_learning_support.gd`（閲覧・保存・失敗時の再試行）、`test_learning_support.py`（紛らわしい用語）、`test_imports.gd`（ZIP・章・読込元識別）、`test_wrong_answer_retry.gd`（再挑戦）、`test_playable_content.gd`（公開全問の資料から履歴まで）。結果分析は [result-analysis.md](result-analysis.md)。
