# 実行時の教材処理

標準起動は `scenes/main.tscn`。`data/packs/learning.json` の `problems` をSchema・意味検証し、画面と調査資料を組み立てます。読込失敗時は勤務を開始しません。書式・検証コマンドは [教材データと作問](problem-data.md)、判断の設計は [学習設計](learning-design.md) を参照してください。

## 調査から判定まで

初期情報 → Tool → 結果とReferenceを照合 → 必要なら結果を次のToolへ渡す → ALLOW/BLOCK。情報をToolへドラッグするか、選択後にボタンを押します。入力は型・入力元・情報ID・値・現在の問題で取得済みかを検査し、Referenceは直接開きます（[調査例](problem-data.md#資料と情報の接続)）。

同じFile型でもProcess本体と実行Scriptは別対象です。出力全体をHashとして渡したり、未取得の結果・別案件の値を使ったりできません。Vendor公開Hashと手元で取得したHashも出典で区別します。URL分解はローカル文字列処理の模擬で、Hostと登録Domainは同一とは限らず、RDAPの入力元は登録Domainの台帳等から指定します。

未調査でもALLOW/BLOCKで判定して次へ進めます。`required_evidence` は調査の充足を評価するための証拠定義として保持し、進行条件には使いません。判定時の未確認項目は履歴の `missing_evidence` に、実施した調査は `observations` に保存します。調査不足に対する評価表示・減点は未実装です。`initial_information` は開始時に満たします。`evidence_alternatives` の `any_of` にある資料は、利用可能な一つを調べればその証拠を満たします。Referenceを開いた履歴は証拠になりますが、自由記述の推論を採点する仕組みではありません。

外部照会は選んだ入力・送信内容・注意文を確認し、模擬送信／見送りを選びます。ESCでも見送れ、確認中は判定操作と時計を止めます。不適切な照会も結果を表示し、理由と件数を監査票・勤務結果に残します。見送りは減点せず、不適切な照会とともに必要証拠の取得には数えません。判定スコアとは独立し、未利用の任意サービスに正誤は付けません。

必要証拠とすべてのTool入力は、適切な内部資料だけで取得できることを各OSで検証します。外部照会の結果は必須証拠や入力取得経路の前提にできません。代替証拠に外部照会を含める場合も、内部の取得手段が必要です。

時計は勤務開始時の `00:00` から案件をまたいで経過時間を加算します。メニュー・規則集・外部送信確認・判定後の監査表示中と勤務終了後は停止し、再開始でリセットします（`tests/test_core.gd`、`tests/test_ui.gd`）。

## 対象OSと調査OS

`platform` は対象分類、`investigation_environment` は調査OSで、前者を書き換えません。Windows/Linuxを選ぶと該当OSと共通問題が出題され、OS固有問題はそのOSで調査します。「すべての環境」「共通のみ」は共通問題の調査OS（既定Windows）を選びます。難易度・カテゴリと併用して登録順に出題し、0件なら開始できません。

Toolの `environments` は `windows` / `linux` の空でない配列です。省略時は両OS対応で、空配列や `common` は指定しません。表示・ドラッグ・直接実行・送信確認・見送りで同じOS条件を使います。表示用の `platform_note` は実行制御に使わず、出題先のOSを製品の対応OSとみなしません（[実装ごとの確認資料](tool-platform-audit.md)）。

`output_by_environment` のキーは明示した `environments` と一致させ、共有の `output_information` と対象・値を揃えます。Pathや対象自体が違うなら別問題・別Toolにします。両対応の宣言だけでは他方の問題や模擬結果は増えません。OSごとに入力・必要証拠の到達性を検証し、Windowsでdigだけを必須にする等の定義を拒否します。

```json
{
  "required_evidence": ["dns_lookup"],
  "evidence_alternatives": {
    "dns_lookup": {"label": "DNSの解決先", "any_of": ["resolve_dnsname", "nslookup", "dig"]}
  }
}
```

上記は [Web初級問題](../data/problems/WEB-BEGINNER-001.json) の代替証拠を示す抜粋です。同じ証拠とする出力同士は事実も一致させます。LinuxのWireshark/tcpdumpは同じ過去SYN 2つ・接続先・60秒間隔を示す例です。

## 画面と責務

| 変更箇所 | 参照先 |
| --- | --- |
| 教材読込・登録・絞り込み | `scripts/core/catalog.gd` |
| Schemaの構造検証、検証済み問題の実行時データ | `scripts/core/content_schema.gd`、`problem_data.gd` |
| 情報の表示・入力型、調査経路・必要証拠 | `scripts/core/information.gd`、`investigation_inputs.gd` |
| 勤務進行・時計・判定・履歴、模擬結果の実行 | `scripts/core/shift.gd`、`tool_runner.gd` |
| 画面遷移・操作状態、部品生成・配置 | `scripts/ui/desk.gd`、`desk_layout.gd` |
| 共通テーマ、カード、情報・スタンプのD&D | `scripts/ui/cyber_theme.gd`、`draggable_card.gd`、`information_token.gd`、`tool_input.gd`、`stamp_tool.gd` |

部品生成は `desk_layout.gd`、画面部品と操作状態の所有は `desk.gd` に置き、画面ごとのクラス階層や別の状態管理を設けません。カードに正解・採点データを渡さず、表示項目の意味をUIで推測しません。

`ContentSchema` は同梱Schemaで使う構文に対応し、未対応キーワードをエラーにします。再帰検証は深度128までです。Python側はDraft 2020-12の検証器を使います。Schemaを拡張するときは両方で検証してください。

対象は左に固定し、「申請内容」と任意項目の「基本情報」に分けます。規則集・結果は見出しで机内を移動し、本文は情報の選択・ドラッグ・スクロールに使います。前面化は同じ親の最後の子へ移し、描画・入力順を一致させます。規則集は閉じても位置・スクロールを保ち、結果の再表示には再調査します。

スタンプは対象の本文・見出し・判定印へのD&Dだけで押印し、Action ID・案件ID・勤務世代を検証して古い操作を拒否します。印影後に監査票へ進みます。案件移動・再開時は資料と選択を消し、ESCメニュー・監査票では時計を止めます。

位置復帰・三本線メニュー・入力トレー・資料一覧・比較配置・記録ボタン・ログ専用画面・下部説明欄・対象イラストは設けません。メニューはESCで開きます。背景は濃紺、対象／結果／規則集はシアン／ブルー／パープル、ALLOW/BLOCKはミント／ピンク。ツール欄と結果は内容に応じて伸縮し、収まらない部分だけスクロールします。カード幅と対象・規則集のサイズは維持します。

## 教材の境界

全Tool・Reference・外部照会はローカルJSONの模擬資料です。実コマンドの実行、外部API呼出し、ブラウザー起動、File Uploadは行いません。資料中のCommandは表示用の文字列です。

任意Fileの解析・自由入力の照会はありません。NPC対話・自動比較・日ごとの進行・永続保存は未実装。値・出典の作り方と学習上の制約は [Tool Outputと実例](learning-design.md#tool-outputと実例) を参照してください。
