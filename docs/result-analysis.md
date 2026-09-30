# 審査結果の分析

## 編集先

| 変更箇所 | 参照先 |
| --- | --- |
| 集計・しきい値・助言 | [result_analysis.gd](../src/domain/result_analysis.gd)：`RULES`，`_style()`，`_level()`，`_advice()` |
| 表示名・正解非表示時の制御 | [result_analysis_view.gd](../src/ui/results/result_analysis_view.gd)：`profile()`，`build()` |
| 三角形の指標・描画 | `result_analysis.gd` の `radar_metrics()` / `radar_findings()`，[result_radar.gd](../src/ui/results/result_radar.gd) |
| 分析から振り返りへの絞込・フォーカス | [summary_screen.gd](../src/ui/results/summary_screen.gd) の `select_tab()` / `update_focus()` |
| しきい値・少数・旧履歴・UIの検証 | [test_result_analysis.gd](../tests/test_result_analysis.gd)．未評価の教材と難易度を明示したfixtureを分ける |

## 指標の注意点

- 必要情報充足率は初期情報だけで足りる問題も含む．スタイルの確認率は追加調査が必要な問題だけで，分母が異なる．どちらも読解力・性格の尺度ではない．
- 調査操作数は記録された失敗を含み，送信見送り・Referenceの再表示・UIで止めた操作を除く．「実行完了」は適切な調査という意味ではない．不適切調査は `ok && correct_usage == false` で，外部送信以外にも設定できる．
- 未出題・分母0は未評価．0点・100点で補完せず，三角形は全軸にデータがあるときだけ塗る．見た箇所や誤答の原因は推測しない．
- 時間と操作数はタイプ判定に使わない．時間の棒は審査ごとに目盛りが変わり，長さだけで審査間を比較できない．表示は合計のみ．

プロ級は根拠確認を優先し，直感型・中間との組み合わせを作らない．未評価・未知の難易度から高難度を推測しない．表示名は内部判定と分離し，記録不足は「セキュリティチャレンジャー」，`retry_of` のある結果は「復習者」．プロフィール・具体的助言・復習リンクは `show_expected && show_reason`，三角形は `show_expected` のときだけ表示する．

## 保存互換・未実装

形式と再挑戦は [用語と履歴](learning-support.md)．分析は保存済みの事実だけから閲覧時に計算するため，ルール変更は過去履歴にも反映される．旧履歴の不足項目を現行教材から補完しない．当時の判定を固定するには，別途バージョン付き保存が必要．新項目を知らない旧アプリでの読込互換は保証しない．

学習テーマ・問題別時間の記録は未追加．教材へのタグ付与と保存，時間の計測境界を設計してから拡張する．合計時間を各問の実時間として扱わない．
