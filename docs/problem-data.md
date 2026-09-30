# 教材データ

形式は [Problem v2](../data/schemas/problem.schema.json)，[Pack v3](../data/schemas/pack.schema.json)を参照．公開教材は `data/problems/` に収録されている．

問題の追加方法は[教材の追加・変更](README.md#教材の追加・変更)を参照．

## 検証・索引

[ProblemLoader](../src/content/problem_loader.gd) が構造・意味検証の共通入口．[問題一覧](problem-catalog.md) と `build/catalog/problems.json` は生成物で，ゲームは依存しない．`--check` はMarkdownを常に，JSONは存在する場合だけ照合する．責務の索引は [実行時の処理](runtime-flow.md#画面と責務)，用語は [学習支援](learning-support.md)．
