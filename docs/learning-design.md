# セキュリティ判断の学習設計

実装済みは基盤と代表24問（正常11・遮断13）。標準起動は `scenes/main.tscn`、教材は `data/packs/learning.json`、問題本体は `data/problems/` です。正解・主題・Tool・出典は [Problem Catalog](problem-catalog.md) に集約します。

## 学習の流れ

初期情報を見る → Toolで事実を取得 → Referenceと比較 → 必要に応じてExternal Reference → ALLOW / BLOCK。

標準教材のTool・External Referenceは対応する情報の選択／ドラッグで実行し、取得結果を次の調査に使えます。Referenceはクリックで閲覧します。[資料と入力の例](problem-data.md#資料と情報の接続)を参照してください。

規則違反の検索を主目的とせず、何が分かり、どの比較によって判断できるかを学びます。名前・署名・Port・周期・認証Pass・検出0件の一つだけで安全とは決めません。共通の手引きには調査方針、各問題のReferenceにはVendor Hash・承認済みSoftware・Directory等の具体的な比較対象を置きます。

| Level | 目的 | 現在の問題数 |
| --- | --- | ---: |
| 超初級 | 初期情報に明示された矛盾・偽装を見る | 2 |
| 初級 | Toolや照合資料で何が分かるかを知る | 7 |
| 中級 | 単独では不十分な複数のEvidenceを組み合わせる | 8 |
| 上級 | 攻撃と正常挙動で共通する特徴を文脈で区別する | 7 |

超初級は初期情報だけで解ける構成とし、Network・Packageには設けません。必要証拠の取得はすべての教材で判定条件です。使用回数や一律の順序は要求せず、同じ事実を得る代替Toolも認めます（[実行時の判定条件](runtime-flow.md#調査から判定まで)）。

## 種別と判定時点

| 種別 | 現在 | 判定の対象 |
| --- | ---: | --- |
| File | 4 | 開く・実行する前。形式偽装、Vendor Hash、正常な未署名Software |
| Process | 4 | 起動済みProcessの継続／停止。正常なPowerShell、systemd Service、不審な親子関係 |
| Web | 4 | 通常Browserで開く前。Host、新規の正規Domain、Fake CAPTCHA、Token付きURL |
| Network | 2 | 現在の接続要求。過去Flow・現在のSocketと所有Processを比較 |
| Email | 3 | 受信保留中のEmailの受入れ。Header、添付File、URL、業務依頼の正当性 |
| Account / Authentication | 4 | Session成立前。今回の認証結果と過去履歴・端末登録・本人確認を比較 |
| Package | 3 | Install / Update前。PyPIの類似名、npmの不正更新・正常なBuild Script |

File・Process・Network・AccountにWindows/Linuxの問題を用意し、Webの概念は共通とします。OS選択とDNSの代替出力は [環境仕様](runtime-flow.md#対象osと調査os)、PackageのPyPI/npmの区別は `ecosystem` を使います。

Emailの添付・URLは `resources.attachment_tools` と `resources.url_tools` で調査し、親Emailの履歴に残します。正規メールの代表問題が例で、別問題への自動遷移はしません。

Accountの今回のSession成立後のLogや操作は使いません。Windowsの4624・Linuxのlast等は過去の成立済みSessionに限定します。Windows Security LogにMFAの成功が記録されると仮定せず、今回のGateway/認証基盤から与えられた結果を初期情報として明示します。

## 外部照会の判断

送信確認・見送り・採点との分離は [実行時の教材処理](runtime-flow.md#調査から判定まで) を参照してください。

Hash検索はFile本体のUploadと別の操作です。VirusTotalはHashによる既存Reportの検索を提供しますが、通常のFile送信では検体がパートナーや顧客と共有され得ます。Hashの照会についても問題内の組織方針に従います。[VirusTotal: Searching](https://docs.virustotal.com/docs/searching)、[How it works](https://docs.virustotal.com/docs/how-it-works)

urlscan.ioのPublic・Unlisted・Privateは結果の公開範囲の違いであり、PrivateでもサービスにURLが渡ります。代表問題では組織の方針として認証Tokenを含むURLの外部送信を禁止し、公開Domainだけの照会を別に用意しています。[urlscan.io API](https://urlscan.io/docs/api/)

## 問題の追加と検証

[問題JSONの追加手順](problem-data.md#追加変更の手順) に沿い、既存IDを再利用せず、表示される事実と独立した照合資料から解説の結論を導ける構成にします。例：`FILE-LINUX-BEGINNER-002`、`PROC-LINUX-INTERMEDIATE-001`、`WEB-ADVANCED-001`、`AUTH-WIN-ADVANCED-001`、`PKG-NPM-ADVANCED-001`。

共通の手引きに書いた方針だけでは検証できない、資料の意味・出力抜粋の整合・判定時点は作問時に確認します。入力と証拠の到達性はSchema・意味検証、全24問とOS別経路は `tests/test_learning.gd` で確認します。

## Tool Outputと実例

出力は実際のフィールド名やCLI書式を参考にした抜粋です。GUI ToolはPropertiesや列のテキスト表現とし、製品UI・ロゴを複製しません。Process所有者はSocket/Process Toolで調べ、Wiresharkだけから分かったようには示しません。暗号化通信の本文もPacket一覧から推測しません。

Hashは教材用の合成値、IPは文書用Address、組織・Domain・Packageは架空です。攻撃Commandは `<TRAINING-PLACEHOLDER>` 等に置換し、実行可能なPayloadを配布しません。Registry MetadataやOSVの結果も保存済み模擬資料で、実在Packageの評判や現在の脆弱性情報を述べるものではありません。

Real-world inspiredは4/24問（16.7%）。攻撃名を知らなくても表示Evidenceから解ける構成にし、各問題の `sources` に一次資料の出典を残します。

- ClickFix / Fake CAPTCHA：[Microsoftの分析](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/)
- PowerShell悪用：[MITRE ATT&CK T1059.001](https://attack.mitre.org/techniques/T1059/001/)
- BEC：[Microsoftの観測報告](https://www.microsoft.com/en-us/security/blog/2022/07/12/from-cookie-theft-to-bec-attackers-use-aitm-phishing-sites-as-entry-point-to-further-financial-fraud/)
- npmの公開者・Token侵害：[npm運営元の説明](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/)

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
