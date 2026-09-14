# パケットを拝見

電子入境管理局の審査官として，プロセス・ファイル・Webサイト（URL）・パケットを調査し，証拠を審査規則と照合して「許可」「拒否」を判定します．

---

## 案件の追加

`data/cases/` のJSONを複製し，一意のIDを付け，教材の `cases` 配列に `res://` から始まるパスを追加します．

```json
{
    "id": "FL-007",
    "type": "file",
    "title": "agent.msi",
    "request": "承認済みエージェントの導入を申請します．",
    "fields": { "入手元": "社内台帳" },
    "evidence": {
        "signature": "署名: 有効 / ノーススター情報システム部 / 台帳のハッシュと一致 / 導入承認済み"
    },
    "expected": "approve",
    "explanation": "規則01: 発行元，台帳のハッシュ，導入記録がすべて確認できました．"
}
```

`fields` と `evidence` の値は文字列です．`evidence` のキーは対象に対応するツールIDにします．  
`expected` は `approve`（許可）または `deny`（拒否）です．  
調査結果が未設定の場合は「取得不可」と表示し，安全と見なしません．  
正しい判定を裏付ける証拠を用意し，解説には規則との関係を記述してください．

## ツールの追加

例えば `data/tools/hash.json` を作り，教材の `tools` 配列にパスを追加します．

```json
{
    "id": "hash",
    "label": "ハッシュ照合",
    "description": "ハッシュ値を承認済み台帳と照合します．",
    "target_types": ["file", "process"],
    "provider": "fixture"
}
```

対象案件の `evidence` に `"hash": "教材用の調査結果"` を追加すると，ツールのボタンが自動で表示されます．  
画面や勤務進行のコード変更は不要です．

計算などの独自処理を行う場合は，勤務開始前に信頼できるGDScriptのCallableを登録し，ツールの `provider` にそのIDを指定します．

```gdscript
shift.runner.register_provider("digest_simulation", func(tool, target):
    return {"ok": true, "output": target.fields.get("ハッシュ値", "ハッシュ値がありません")}
)
```

処理にはツールと案件の辞書のコピーが渡されます．戻り値は `{"ok": bool, "output": String}` にしてください．  
未登録の処理や不正な戻り値はエラーとして表示します．  
処理は同期式のため，時間のかかる処理やネットワーク連携を導入する場合は，先に非同期処理と待機状態の管理が必要です．

## 教材の追加と配布

`data/intro.json` を複製し，規則と各ファイルのパスを変更します．  
Godotのインスペクターでルートの `InspectionDesk` ノードの `Content Pack` プロパティに指定してください．  
教材が不正，または見つからない場合は，端末にエラーを表示して判定を無効にします．

---

## ビルド

Godot 4とjustをインストールして実行します．  
`just install-templates` で，使用中のGodotと同じバージョンの公式テンプレートを導入できます．Python 3.11以上とネットワーク接続が必要です．  
Godot本体にLinux・Windows用の導入CLIはないため，このレシピが取得と配置を担当します．  
Godotの「エディター → エクスポートテンプレートの管理」から導入しても構いません．

```sh
just install-templates # 使用中のGodotに対応する公式テンプレートを導入
just build          # Linux・Windowsの両方
just clean          # build/ 以下の出力を削除
```

Linux・WindowsともにPCKとライセンス表記を実行ファイルへ埋め込む設定です．配布時は実行ファイルだけを渡せます．外部の `.pck` や `FONT-LICENSE.txt` は不要です．  
Windows版は署名なしで，Linuxからのビルドに外部のアイコン編集ツールを要求しない設定です．  
詳細は[Godotのエクスポート手順](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)を参照してください．

---

## テスト

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_core.gd
godot --headless --path . --script tests/test_ui.gd
```

コアのテストでは，ツールの対応対象，採点，不正な状態遷移の防止，調査履歴，再開始，教材・証拠の欠落，独自処理の呼び出しを確認します．  
画面のテストでは，許可・拒否後の監査票，正解・誤判定の表示，調査ログの保持，6件の進行，勤務終了と再開始を確認します．

画面を撮影する場合は `godot --path . --script tests/capture.gd` を実行してください．  
ディスプレイが必要です．`/tmp/packets-please.png` に初期画面，`/tmp/packets-debrief.png` に監査票を保存します．
