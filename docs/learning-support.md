# 学習支援の移植

7fd014cを土台に、用語集・勤務履歴を移植。移植時の112問に用語を付与済み。現在の出題対象と難易度は [学習設計](learning-design.md) を参照。

勤務結果の分析画面・審査スタイルの指標と保存互換は [result-analysis.md](result-analysis.md) を参照。

## 編集先

| 対象 | ファイル |
| --- | --- |
| 共通用語 | data/glossary/security.json |
| 辞書の指定 | Packのglossary_path（未指定でも動作） |
| 用語の登場箇所 | 問題JSONのglossary[].occurrences |
| 用語の検証・抽出 | scripts/core/glossary.gd、scripts/build_problem_catalog.py |
| 判定・保存する記録 | scripts/core/shift.gd |
| 履歴保存・形式 | scripts/core/history_store.gd、data/schemas/history.schema.json |
| 画面操作・配置 | scripts/ui/desk.gd、desk_layout.gd |

## 教材追加時

標準Packのglossary_pathはres://data/glossary/security.json。共通辞書は215語で、標準問題では206語を参照する。追加・修正は辞書のlabel／descriptionと問題のglossaryを編集する。未参照の既存語も残している。

sectionはinitial／overview／result／submission。source_idはinitial_informationまたは問題内の資料ID。いずれかの箇所を閲覧すると用語を表示する。overviewは資料名・案内を指し、資料本文はresult。UIは用語名と開閉する説明のみで、登場箇所タグは表示しない。

用語の対応はJSONで明示する。実行時の単語検索ではない。title・explanationから用語を先出ししない。Port（通信／lastlogの端末）、Resolver（DNS／パッケージ）、Source（接続元／取得元／コード）は文脈でIDを使い分ける。説明は短い平易な文とし、その問題の正解や未閲覧の事実を書かない。

用語集UIは開閉マーク付きの見出しと背景・余白付き説明。検索は閲覧済み用語の名前・説明だけを絞る（大小文字を無視）。検索語・開閉状態は同じ問題では保持し、問題変更でリセットする。件数表示とTab移動も絞込後の一覧に合わせる。配置はdesk_layout.gd、検索と状態はdesk.gd。


## 保存・検証

勤務結果と履歴の問題別表示はclone時の判定・解説・調査手段の振り返りに合わせる。追加していた「初期情報・調査記録を開く」リンクと展開処理は撤去済み。


保存上限は最新100勤務（HistoryStore.MAX_ENTRIES）。新しい保存が成功した後、completed_at順で超過分を削除する。同時刻はsession_idで順序を固定する。破損・未知版・一時ファイルは削除対象に含めない。古い履歴の削除に失敗しても新規保存は成功扱いとし、次の保存時に再試行する。このため権限エラー時などは一時的に上限を超える場合がある。

勤務終了時にuser://historyへスナップショットを保存。途中再開は対象外。解説・初期情報・調査記録を保存し、現在の教材から再計算しない。辞書の過去版は保存しない。保存形式変更時はschema_versionと移行を検討する。

履歴一覧と件数整理は、各履歴の`<session_id>.index.json`から表示情報を読む。索引は履歴本体のSHA-256と照合し、不足・破損・不一致なら本体を検証して再生成する。既存履歴は初回読込時に索引を作るため、件数が多いと一度だけ時間がかかる。索引は派生データで、履歴本体だけが正本。

tests/fixtures/learning-supportは出題しない専用教材。test_learning_support.py／.gdで追加項目の検証、表示タイミング、保存・再読込・失敗時の再試行を確認する。Python側では標準教材の紛らわしい用語・結果用語の先出しも検証する。test_playable_content.gdは標準全問の資料を辿り、履歴保存まで検証する。

移植時の検証: Python 48テスト・カタログ照合成功。Godot 4.5.1で19/20テスト成功（112問の保存・再読込を含む）。test_content_sizing.gd:29は以前から確認されているサイズ検証の失敗が残る。最新版指定の4.7.2では未検証。

用語執筆後の検証: Python 54テスト・カタログ照合成功。Godot 4.5.1のtest_learning_support.gdとtest_playable_content.gdも成功。

## 誤答の再挑戦

誤答の再挑戦: 勤務結果・履歴詳細のボタンから、その勤務の誤答IDだけを`wrong_answer_retry.gd`で現行Catalogに照合して出題する。重複IDは一度、削除済みは除外、別Pack・読込失敗は開始不可。履歴本文を問題データとして流用しない。再開ボタン・一時停止からのやり直しは対象を維持し、タイトルへ戻ると通常出題へ戻る。結果は新規勤務IDで保存し、任意の`retry_of`に元の勤務IDを記録（schema_version=2）。索引にも任意で複写する。古い履歴や元履歴が100件上限で消えても閲覧は独立。`tests/test_wrong_answer_retry.gd`で出題・保存・再開始を確認する。

## 記入用ひな形

各問題のexplanation直前にglossaryがある。以下は追加する際の形式例。空配列なら何も表示しない。

```json
"glossary": [
  {
    "term_id": "file",
    "occurrences": [
      { "source_id": "initial_information", "section": "initial" }
    ]
  }
]
```

term_idは共通辞書のキーを指定する。実行後に表示する語は、その問題のツールIDとsection: resultを指定する。新しいPackでも辞書を利用するならglossary_pathの指定が必要。


以前の診断・監査手順は移植時に撤去した。現在の勤務結果には、別途result-analysis.mdに定義した分析・審査スタイルを追加している。履歴形式はschema_version=2。以前の形式は移行せず読み飛ばす（ファイルは削除しない）。

調査欄の名称表示修正は維持する。tool_input.gdの_layout_labelsで高さ0の自動調整に依存せず、折り返し行数から高さを確保する。test_tool_labels.gdで全問題の名称表示領域と入力案内との重なりを検証する。
