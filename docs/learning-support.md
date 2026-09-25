# 学習支援の移植

7fd014cを土台に、用語集・監査手順表示・勤務履歴・審査スタイルを移植。既存112問、教材レビュー、超初級のReference利用仕様を維持した。問題ごとの用語・手順の執筆は今回の対象外。

## 編集先

| 対象 | ファイル |
| --- | --- |
| 共通用語 | data/glossary/security.json |
| 辞書の指定 | Packのglossary_path（未指定でも動作） |
| 用語の登場箇所 | 問題JSONのglossary[].occurrences |
| 監査手順 | 問題JSONのreview_steps（explanationと同階層） |
| 用語の検証・抽出 | scripts/core/glossary.gd、scripts/build_problem_catalog.py |
| 判定・保存する記録 | scripts/core/shift.gd |
| 審査スタイル | scripts/core/review_style.gd |
| 履歴保存・形式 | scripts/core/history_store.gd、data/schemas/history.schema.json |
| 画面操作・配置 | scripts/ui/desk.gd、desk_layout.gd |

## 教材追加時

標準Packにはglossary_pathをまだ指定していない。用語を付与する際はres://data/glossary/security.jsonを指定し、問題のglossaryへterm_idとoccurrencesを追加する。sectionはinitial／overview／result／submission。source_idはinitial_informationまたは問題内の資料ID。いずれかの箇所を閲覧すると用語を表示する。UIは用語名と開閉する説明のみで、登場箇所タグは表示しない。

review_stepsは空白でない文字列の配列。番号はUI側で付ける。未設定なら手順見出しも表示しない。show_reasonに従う。最新版のdata/catalogの教材レビュー形式と、この実行時の手順項目は別で、自動変換はしない。

## 保存・検証

保存上限は最新100勤務（HistoryStore.MAX_ENTRIES）。新しい保存が成功した後、completed_at順で超過分を削除する。同時刻はsession_idで順序を固定する。破損・未知版・一時ファイルは削除対象に含めない。古い履歴の削除に失敗しても新規保存は成功扱いとし、次の保存時に再試行する。このため権限エラー時などは一時的に上限を超える場合がある。

勤務終了時にuser://historyへスナップショットを保存。途中再開は対象外。解説・手順・初期情報・調査記録・診断を保存し、現在の教材から再計算しない。辞書の過去版は保存しない。保存形式変更時はschema_versionと移行を検討する。

tests/fixtures/learning-supportは出題しない専用教材。test_learning_support.py／.gdで追加項目の検証、表示タイミング、保存・再読込・失敗時の再試行を確認する。test_playable_content.gdは最新版全問を未記入のまま通し、履歴保存まで検証する。test_tool_labels.gdは調査欄の名称の高さと重なりを確認する。

移植時の検証: Python 48テスト・カタログ照合成功。Godot 4.5.1で19/20テスト成功（112問の保存・再読込を含む）。test_content_sizing.gd:29は以前から確認されているサイズ検証の失敗が残る。最新版指定の4.7.2では未検証。

## 記入用ひな形

全112問のexplanation直前にglossaryとreview_stepsの空配列を追加済み。空のままなら何も表示しない。以下は形式例であり、問題の内容に合わせて配列の中身を記入する。

```json
"glossary": [
  {
    "term_id": "file",
    "occurrences": [
      { "source_id": "initial_information", "section": "initial" }
    ]
  }
],
"review_steps": [
  "初期情報から確認対象を特定する。",
  "調査結果を規則や承認情報と照合する。",
  "照合結果を根拠にALLOW／BLOCKを判断する。"
]
```

term_idは共通辞書のキーを指定する。実行後に表示する語は、その問題のツールIDとsection: resultを指定する。用語を記入する際は、Packにもglossary_path: res://data/glossary/security.jsonを設定する。例の一般的な手順は、その問題の具体的な資料名・照合先・判断根拠に置き換える。
