# セキュリティ判断の学習設計

実装済みの問題・主題・Tool・出典は [Problem Catalog](problem-catalog.md)。作問手順は [教材データ](problem-data.md#追加変更の手順)、操作・採点は [実行時の処理](runtime-flow.md#調査から判定まで) を参照してください。

## 学習の流れ

何が分かり、どの比較で判断できるかを学びます。名前・署名・Port・周期・認証Pass・検出0件の一つだけで安全と決めません。共通の手引きには調査方針、各問題のReferenceにはVendor Hash・承認済みSoftware・Directory等の具体的な比較対象を置きます。

難易度と調査形式は分離する。難易度は作問者の任意評価で、初級・中級・上級。既存教材は評価基準が未確定のため未評価とする。調査形式は対応する資料から「初期情報のみ・資料の照合・ツールあり・外部照会あり」を導出し、開始画面で別々に絞り込む。外部照会が存在することと必須であることも区別する。

規則・正規連絡先・承認情報は調査側のReferenceに置き、検査対象には対象の情報を表示する。単純な照合から複数の証拠の統合まで扱う。Referenceだけで成立する問題に分類目的で不要なToolを追加しない。

適切な外部照会が必要な問題も認めます。一律の使用回数・順序や調査完了を回答条件にせず、同じ事実を得る代替Toolも認めます。ALLOWは現在のCheckpointの通過許可、BLOCKはその不許可であり、Malwareの証明とは限りません。

## 種別と判定時点

| 種別 | 判定時点 |
| --- | --- |
| File | 開く・実行する前 |
| Web | 通常Browserで開く前 |
| Package | Install / Update前 |
| Process | 起動済みProcessの継続／停止 |
| Network | 現在の接続要求。過去Flow・現在のSocket・所有Processと比較 |
| Email | 受信保留中のEmailの受入れ |
| Account / Authentication | Session成立前 |

PackageのPyPI/npmは問題の初期情報・資料で区別します。Email内の添付・URLは資料の `section`で調査し、親Emailの履歴に残します（[例](../authoring/archive/problems/EMAIL-GENUINE-URGENT.json)）。別問題へ自動遷移しません。

Accountでは今回のSession成立後のLog・操作を使いません。4624・last等は過去Sessionに限定し、今回のMFA結果はGateway/認証基盤の初期情報として明示します。Windows Security LogにMFA成功が記録されるとは仮定しません。

## 外部照会の判断

外部照会では公開到達性だけで送信可とせず、送信先・対象の機密区分をReferenceの方針で確認します。

Hash検索とFile本体のUploadは別操作です。VirusTotalの通常のFile送信では検体がパートナーや顧客と共有され得ます。Hash照会も問題内の組織方針に従います。[Searching](https://docs.virustotal.com/docs/searching)、[How it works](https://docs.virustotal.com/docs/how-it-works)

urlscan.ioのPublic・Unlisted・Privateは公開範囲であり、PrivateでもURLはサービスに渡ります。教材の組織方針ではToken付きURLの送信を禁止し、公開Domainだけの照会を別に用意します。[API](https://urlscan.io/docs/api/)

## Tool Outputと実例

出力はCLI・実フィールドの抜粋、GUIはPropertiesや列のテキスト表現とし、製品UI・ロゴを複製しません。Socketの所有ProcessはSocket/Process Toolで調べ、Wiresharkだけから示しません。Packet一覧から暗号化本文も推測しません。

Hashは合成値、IPは文書用、組織・Domain・Package・脆弱性は架空です。脆弱性IDは `TRAINING-` とし、「（架空）」を個々のIDに付けません。Command・Sourceの編集箇所は `〔…を省略〕` と表示し、判断に必要な取得先・呼出しを残します。実行可能なPayloadは配布しません。Registry Metadata・OSVも保存済み模擬資料で、実在Packageの評判や現在の脆弱性情報を示しません。

実例は攻撃名を知らなくてもEvidenceから解ける構成にし、各問題の `sources` に一次資料を残します。ClickFix・DLL Side-loading・Cron Persistence・BEC・Password Spraying・Package供給元の事例は [問題一覧](problem-catalog.md) から辿れます。

仕様確認には [Sigcheck](https://learn.microsoft.com/en-us/sysinternals/downloads/sigcheck)、[Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)、[Windows Event 4625](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4625)、[Wireshark Conversations](https://www.wireshark.org/docs/wsug_html_chunked/ChStatConversations.html)、[npm Scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts/)、[package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/)、[OSV API](https://google.github.io/osv.dev/api/) を参照しました。Toolの実装・利用OSごとの確認資料は [Tool利用環境](tool-platform-audit.md) に集約します。CLI/GUIのVersion・表示設定による細部の差はあります。

## 現行教材の方針

問題数の目標は設けず、判断根拠・Tool選択・正常例との一貫性を優先します。現行Packは70問です。RDAPは判断への寄与が小さいため扱わず、専用の3問と付随する調査資料を削除しています。出題対象外の39問は `authoring/archive/problems/` に保管し、公開教材と配布から除外します。

Vulnerability DatabaseはReference、Hash／File／Domain／IP／URL ReputationとIsolated URL AnalysisはExternal Referenceです。Referenceを含む調査結果は比較する事実を示し、攻撃名・ゲーム上の結論はTitle・Explanationへ置きます。外部サービス本来の検出数・分類の表示は可能です。

Hash・Domain・IP・Full URL・File・PCAP・Emailの送信内容を区別し、機密FileやToken付きURLの外部送信を必要証拠にしません。

Real-world inspiredはFake Update、ClickFix／Fake CAPTCHA（Windows Process）、DLL Side-loading、LOLBin、Cron Persistence、BEC、Windows／SSH Password Spraying、Typosquatting、Dependency Confusionの範囲とします。出典と観測Evidenceが支えない原因・攻撃名を断定せず、正常例も残します。
