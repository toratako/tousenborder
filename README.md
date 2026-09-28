# とーせんぼ～だ～ — セキュリティ審査ゲーム

情報を集めてALLOW / BLOCKを判断するGodot 4の教育ゲームです。

## 起動

Godot 4とjustを用意し、プロジェクトのルートで `just run`。素材・スクリプトのインポートと教材検証後に起動します。justを使わない場合:

```sh
godot --headless --path . --editor --import --quit
godot --path .
```

初回・スクリプト追加後のクラス未登録エラーはインポートで更新します。起動シーンは `scenes/main.tscn`、標準教材は `data/packs/learning.json`。

## 開発・教材編集

- [作問・検証](docs/problem-data.md)：Schema、入力の接続例、一覧の再生成
- [問題一覧](docs/problem-catalog.md)：全問題の初期情報・想定手順・決定的証拠・正解を確認する設計レビュー表
- [学習設計](docs/learning-design.md)：判定時点、教材の制約、未実装の拡張計画
- [学習支援](docs/learning-support.md)：用語集・勤務履歴の編集先
- [実行時の処理](docs/runtime-flow.md)：OS条件、状態管理、変更箇所の索引

Python 3.11以上を使います。ゲームの起動・エクスポートにPythonの開発用依存は不要です。

```sh
python3 -m pip install -r requirements-dev.txt
just validate # Python・Godotで教材と生成一覧を検証
just test     # Python・Godotの全テスト
```

実行ファイルは `GODOT` / `PYTHON` 環境変数で指定できます。

## ビルド

使用中のGodotと同じバージョンのエクスポートテンプレートが必要です。

```sh
just install-templates # 公式テンプレートを取得（Python・ネットワークが必要）
just build            # 教材検証後、Linux / Windowsを出力
just clean            # build/ 以下を削除
```

出力は `build/linux/packets-please.x86_64` と `build/windows/packets-please.exe`。PCK・ライセンス表記を内包し、Windows版は署名なしです。

`v1.2.3` 形式のタグをpushすると、[Releaseワークフロー](.github/workflows/release.yml)がテスト・ビルド後にGitHub Releaseを公開し、Linux版（tar.gz）とWindows版（zip）を添付します。`v1.2.3-rc.1` などの接尾辞付きタグはプレリリースになります。

画面キャプチャは `godot --path . --script tests/capture.gd` → `build/screenshots/`（描画環境が必要）。
