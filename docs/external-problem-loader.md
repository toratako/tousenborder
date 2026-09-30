# 外部から問題をImportする

現在この要素はタイトル上で非表示になっている．  
本来は外部ファイルから問題をImportするための機能．

## Pack・ZIP

Packは問題IDによる出題順と，任意の抽選設定を管理する．問題の定義は持たない．ZIPでは次の構成を直下に置く．

```text
problems/first.json
packs/story/pack.json
```

`pack.json` は `{ "schema_version": 3, "id": "story", "title": "物語", "problems": ["EXAMPLE-FILE"] }`．問題IDは同じ読込元を参照し，同じIDを複数回指定できる．旧章付きPackは v3 への変換が必要．

ランダム出題は任意の `sampling.count` で総出題数を指定する．[learning/pack.json](../data/packs/learning/pack.json) は20問．`problems` 全件から難易度を区別せず等確率で重複なく抽選し，出題順も混ぜる．難易度ごとの数・上限・最低数は設けない．指定数は1以上で，候補不足は読込エラー（同じIDの重複は候補数に含めない）．`sampling` がないPackは従来どおり指定順・全件出題．

タイトルからの開始で再抽選し，途中のやり直し・結果画面の「同じ問題に再挑戦」は問題と順番を維持する．抽選は [ProblemLibrary.draw_pack_cases](../src/content/problem_library.gd)，検証は [PackLoader](../src/content/pack_loader.gd)，回帰テストは [test_pack_sampling.gd](../tests/test_pack_sampling.gd)．

教材追加ボタンはタイトル画面では非表示．ZIP・単独Problem JSONの読込処理（`game.gd` の `_import_content`）と保存済み教材の読込は維持する．全体の検証・保存成功後に登録し，無効な読込元があっても他の教材は維持する．保存先は `user://content/`，内容のSHA-256が識別子．同じ内容の再追加は重複せず，内容変更は別の読込元になる．削除UIは未実装で，不要な教材はアプリ終了後に保存先から削除する．

ZIPはJSONとディレクトリのみ，store/deflateに対応する．暗号化・分割・ZIP64・特殊ファイルは対象外．容量上限は [ContentSource](../src/content/content_source.gd) の `MAX_*`．教材領域へ展開せずに読む．検証は [test_imports.gd](../tests/test_imports.gd)．

```sh
godot --headless --path . --script scripts/validate_content.gd -- /path/to/content.zip
python3 scripts/build_problem_catalog.py --source /path/to/content.zip --json-output build/custom.json --markdown-output build/custom.md
```
