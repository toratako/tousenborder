# 用語と履歴

| 対象             | 編集先                                                              |
| ---------------- | ------------------------------------------------------------------- |
| ゲーム共通の用語 | `data/glossary/security.json`                                       |
| 問題固有の定義   | 問題の任意 `glossary`（ID → label / description）                   |
| 用語の登場箇所   | `initial.terms`，資料の `terms`，`result.terms`，`submission.terms` |
| 履歴形式         | [history.schema.json](../data/schemas/history.schema.json)          |

用語の対応は，その表示箇所にID配列を置く．初期情報・資料案内は問題表示時，結果は実行時，送信注意文は確認画面で解禁する．

Port（通信／端末）やResolver（DNS／パッケージ）は文脈別IDを使う．文字列検索で関連付けず，定義やtitle・explanationから正解・未閲覧の事実を先出ししない．閲覧制御は [glossary.gd](../src/content/glossary.gd)，紛らわしい用語の検証は [test_learning_support.py](../tests/test_learning_support.py)．

履歴は勤務終了時に `user://history/` へ保存し，教材がなくても当時の結果を表示する．新規はversion 3，既存version 2も読める．保存上の `level` は互換性のため維持し，新規の値は問題の `difficulty`．結果の再集計は [勤務結果の分析](result-analysis.md)．

再挑戦は読込元IDと問題IDで現行の検証済み問題を選び，同名の別教材で代用しない．旧履歴version 2に記録されたlearning Packはbuiltinに対応する．`retry_of` に元勤務IDを残す．定義変更・重複・未読込の扱いは [wrong_answer_retry.gd](../src/app/wrong_answer_retry.gd) と [test_wrong_answer_retry.gd](../tests/test_wrong_answer_retry.gd)．

保存・整理・再試行は [history_store.gd](../src/persistence/history_store.gd)，検証は [test_learning_support.gd](../tests/test_learning_support.gd)．上限超過分の削除は保存成功後だけで，破損・未知版・一時ファイルは残す．同IDの異なる内容で上書きしない．`*.index.json` は本体のSHA-256で照合する派生索引で，不足・破損時は本体から再生成する．
