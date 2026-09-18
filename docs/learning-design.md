# セキュリティ判断の学習設計

実装済みの問題・主題・Tool・出典は [Problem Catalog](problem-catalog.md)。作問手順は [教材データ](problem-data.md#追加変更の手順)、操作・採点は [実行時の処理](runtime-flow.md#調査から判定まで) を参照してください。

## 学習の流れ

何が分かり、どの比較で判断できるかを学びます。名前・署名・Port・周期・認証Pass・検出0件の一つだけで安全と決めません。共通の手引きには調査方針、各問題のReferenceにはVendor Hash・承認済みSoftware・Directory等の具体的な比較対象を置きます。

| Level | 目的 |
| --- | --- |
| 超初級 | 初期情報に明示された矛盾・偽装を見る |
| 初級 | Toolや照合資料で何が分かるかを知る |
| 中級 | 単独では不十分な複数のEvidenceを組み合わせる |
| 上級 | 攻撃と正常挙動で共通する特徴を文脈で区別する |

超初級は初期情報だけで解ける構成とし、Network・Packageには設けません。未調査でも判定可能ですが、教材は内部調査だけで必要証拠を得られる構成にします。一律の使用回数・順序を要求せず、同じ事実を得る代替Toolも認めます。

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

PackageのPyPI/npmは `ecosystem` で区別します。Email内の添付・URLは追加グループで調査し、親Emailの履歴に残します（[例](../data/problems/EMAIL-INTERMEDIATE-001.json)）。別問題へ自動遷移しません。

Accountでは今回のSession成立後のLog・操作を使いません。4624・last等は過去Sessionに限定し、今回のMFA結果はGateway/認証基盤の初期情報として明示します。Windows Security LogにMFA成功が記録されるとは仮定しません。

## 外部照会の判断

Hash検索とFile本体のUploadは別操作です。VirusTotalの通常のFile送信では検体がパートナーや顧客と共有され得ます。Hash照会も問題内の組織方針に従います。[Searching](https://docs.virustotal.com/docs/searching)、[How it works](https://docs.virustotal.com/docs/how-it-works)

urlscan.ioのPublic・Unlisted・Privateは公開範囲であり、PrivateでもURLはサービスに渡ります。教材の組織方針ではToken付きURLの送信を禁止し、公開Domainだけの照会を別に用意します。[API](https://urlscan.io/docs/api/)

## Tool Outputと実例

出力はCLI・実フィールドの抜粋、GUIはPropertiesや列のテキスト表現とし、製品UI・ロゴを複製しません。Socketの所有ProcessはSocket/Process Toolで調べ、Wiresharkだけから示しません。Packet一覧から暗号化本文も推測しません。

Hashは合成値、IPは文書用、組織・Domain・Packageは架空です。攻撃Commandは `<TRAINING-PLACEHOLDER>` 等に置換し、実行可能なPayloadを配布しません。Registry Metadata・OSVも保存済み模擬資料で、実在Packageの評判や現在の脆弱性情報を示しません。

実例は攻撃名を知らなくてもEvidenceから解ける構成にし、各問題の `sources` に一次資料を残します。ClickFix・PowerShell悪用・BEC・npm供給網の事例は [問題一覧](problem-catalog.md) から辿れます。

仕様確認には [Sigcheck](https://learn.microsoft.com/en-us/sysinternals/downloads/sigcheck)、[Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)、[Windows Event 4625](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4625)、[Wireshark Conversations](https://www.wireshark.org/docs/wsug_html_chunked/ChStatConversations.html)、[npm Scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts/)、[package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/)、[OSV API](https://google.github.io/osv.dev/api/) を参照しました。Toolの実装・利用OSごとの確認資料は [Tool利用環境](tool-platform-audit.md) に集約します。CLI/GUIのVersion・表示設定による細部の差はあります。

## 今後の192問への拡張計画

以下は未実装の目標配分です。Category・問題数・Tool・Reference・UI・Schema・Level・判定方法はプロトタイプの評価に応じて変更できます。

| Level | File Win | File Linux | Process Win | Process Linux | Web | Network Win | Network Linux | Email | Account Win | Account Linux | Package | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 超初級 | 2 | 2 | 1 | 1 | 4 | 0 | 0 | 4 | 1 | 1 | 0 | 16 |
| 初級 | 5 | 5 | 6 | 6 | 9 | 4 | 4 | 6 | 5 | 5 | 4 | 59 |
| 中級 | 5 | 5 | 6 | 6 | 7 | 6 | 6 | 8 | 5 | 5 | 5 | 64 |
| 上級 | 4 | 4 | 5 | 5 | 6 | 5 | 5 | 6 | 4 | 4 | 5 | 53 |
| Total | 16 | 16 | 18 | 18 | 26 | 15 | 15 | 24 | 15 | 15 | 14 | 192 |

QR phishing、AiTM、Fake update、Cloud通信、追加のSupply-chain事例、その他の基本Toolの反復学習は今後の拡張です。正常問題を十分に用意し、特定のIndicatorがあれば常に悪性という誤学習を防ぐ方針を維持します。
