# 審査スタイル追加（2026-09-25）

勤務結果の正誤集計の下に「今回の審査スタイル」と一言を追加。正解率3段階（80%以上／50%以上80%未満／50%未満）と証拠確認率2段階（80%以上／未満）で6タイプを選ぶ。名称・文言・閾値の正本は `scripts/core/review_style.gd`。

## 変更箇所

- `scripts/core/shift.gd`：判定時のrecordsに `required_evidence_count` / `confirmed_evidence_count` を保存。
- `scripts/core/review_style.gd`：記録だけから分類する `ReviewStyle.classify()`。回答0件は空辞書、必要証拠0件は「基礎判断チャレンジャー」。
- `scripts/ui/desk.gd` / `desk_layout.gd`：分類結果の表示・配置。既存の問題別振り返りはスクロール領域を維持。
- `tests/test_review_style.gd`：分類境界、証拠集計、画面表示・文字の収まり、再開始を検証。既存の `scripts/run_tests.py` が自動検出。

## 集計の注意点

- 正解率はその勤務の全回答が対象。証拠確認率は必要証拠の合計で計算し、問題ごとの割合を平均しない。
- `initial_information` は証拠数から除外。初期情報のみの問題は証拠確認率に影響しない。
- 確認数は既存の `missing_evidence()` から算出。代替経路は一つを満たせば一件、再調査で増えない。不適切な調査・失敗・送信見送りは未確認のまま。
- 分類は今回の勤務の傾向であり、人格や恒常的な能力の評価ではない。ツール回数・速度・不要な追加調査は加点しない。



診断結果と証拠数は勤務履歴に保存する。保存仕様は [学習支援](learning-support.md) を参照。
