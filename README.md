# （仮）— セキュリティ審査ゲーム

情報を集めてALLOW / BLOCKを判断するGodot 4の教育ゲームです。

## 起動

Godot 4とjustを用意し、プロジェクトのルートで実行します。

```sh
just run
```

起動前に素材とスクリプトをインポートし、教材を検証します。初回やスクリプト追加後に `godot` だけでクラス未登録エラーが出る場合も、インポートで更新できます。justを使わない場合:

```sh
godot --headless --path . --editor --import --quit
godot --path .
```

起動シーンは `scenes/main.tscn`、教材は `data/packs/learning.json` です。

## 教材データ

| 配置                          | 役割                                     |
| ----------------------------- | ---------------------------------------- |
| `data/packs/`                 | 問題の出題順、カテゴリ、規則、表示設定   |
| `data/problems/`              | 問題ごとの初期情報、調査資料、正解、解説 |
| `data/schemas/`               | PackとProblemの構造・許容値の定義        |
| `docs/problem-catalog.md`     | 問題JSONから生成する一覧                 |
| `build/catalog/problems.json` | 自動生成する一覧JSON（Git管理外）        |

形式は1つです。入力条件と必要証拠の確認は常に有効です。JSON Schemaに加え、参照先や各OSでの調査経路を検証します。

- [キーと値・作問手順](docs/problem-data.md)
- [問題一覧](docs/problem-catalog.md)
- [学習設計](docs/learning-design.md)
- [実行時の処理とOS条件](docs/runtime-flow.md)

## 検証

Python 3.11以上と開発用依存を用意します。必要なら仮想環境を使ってください。

```sh
python3 -m pip install -r requirements-dev.txt
just validate # PythonとGodotで教材・生成一覧を検証
just test     # PythonテストとGodotの全テスト
```

問題を変更したら一覧を更新します。

```sh
python3 scripts/build_problem_catalog.py
```

使用する実行ファイルは `GODOT` と `PYTHON` 環境変数で指定できます。ゲームの起動とエクスポートにPythonの開発用依存は不要です。

## ビルド

使用中のGodotと同じバージョンのエクスポートテンプレートが必要です。

```sh
just install-templates # 公式テンプレートを取得（Python・ネットワークが必要）
just build            # 教材検証後、Linux / Windowsを出力
just clean            # build/ 以下を削除
```

出力先は `build/linux/packets-please.x86_64` と `build/windows/packets-please.exe`。PCKとライセンス表記は実行ファイルに含まれます。Windows版は署名なしです。

画面キャプチャは `godot --path . --script tests/capture.gd` で `build/screenshots/` に保存します。描画環境が必要です。
