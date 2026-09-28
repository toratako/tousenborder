# Tool利用環境の確認（2026-09-18）

当日の公式資料の確認記録で、動作保証ではありません。`platform_note` は代表環境の説明専用です。現行の制御は [OS条件](runtime-flow.md#対象osと調査os)、配置教材は [問題一覧](problem-catalog.md)。移植版・追加ランタイム・全バージョンの網羅は対象外です。

| Tool / 機能 | 確認・修正内容 | 一次資料 |
| --- | --- | --- |
| Get-FileHash | 教材ではWindowsのToolとして扱う。他OSでのPowerShell 7利用は対象外 | [コマンド](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash)、[PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview) |
| Resolve-DnsName / Get-NetTCPConnection | Windows用モジュール。PowerShell本体の複数OS対応とは区別 | [DnsClient](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname)、[NetTCPIP](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection) |
| Sigcheck / Process Explorer / TCPView / Autoruns | WindowsのSysinternals製品。別途導入。Autorunsは選択ProcessのImageに対応する自動起動登録を調べる | [Sigcheck](https://learn.microsoft.com/en-us/sysinternals/downloads/sigcheck)、[Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)、[TCPView](https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview)、[Autoruns](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns) |
| Strings | Sysinternals版とGNU版は別実装。Fileの文字列抽出であり、PIDを渡してMemoryを読むコマンドではない | [Strings](https://learn.microsoft.com/en-us/sysinternals/downloads/strings)、[GNU Binutils](https://sourceware.org/binutils/docs/binutils.html) |
| Task Manager / Event Viewer | Windows標準機能 | [Windowsの構成ツール](https://support.microsoft.com/en-us/windows/experience/system-configuration-tools-in-windows)、[Event Viewer](https://learn.microsoft.com/en-us/shows/inside/event-viewer) |
| file | Linux/macOS等。Tool実行OSと検査Fileの対象OSは別 | [file開発元ミラー](https://github.com/file/file) |
| readelf | GNU BinutilsのELF調査。ELF対応とTool実行OSを混同しない | [readelf](https://sourceware.org/binutils/docs/binutils/readelf.html) |
| sha256sum | GNU Coreutils。各OSに標準で入っているとは限らない | [GNU Coreutils](https://www.gnu.org/s/coreutils/manual/html_node/sha2-utilities.html) |
| tar | LinuxのGNU tarとWindowsのbsdtarを区別 | [GNU tar](https://www.gnu.org/software/tar/)、[Windowsのtar](https://learn.microsoft.com/en-us/windows/tar/) |
| ExifTool / 7-Zip | Windows/Linux/macOS。7-ZipのCLI名は配布形態によって異なる | [ExifTool](https://exiftool.org/install.html)、[7-Zip](https://www.7-zip.org/download.html) |
| unzip | Linux教材でZIPの一覧表示に使用。添付の実行や展開はしない | [Info-ZIP UnZip](https://infozip.sourceforge.net/UnZip.html) |
| ps / pstree | 教材はLinuxのprocps-ng / PSmisc。別OS・別実装との違いを明記 | [procps-ng](https://gitlab.com/procps-ng/procps)、[PSmisc](https://gitlab.com/psmisc/psmisc) |
| systemctl / journalctl | 表示はLinux。教材はsystemdを使う一般的な構成を前提とし、構成差の説明は主表示に含めない | [systemd](https://github.com/systemd/systemd) |
| ss | Linuxのiproute2 | [iproute2](https://github.com/iproute2/iproute2) |
| lsof / tcpdump | Linux/macOSなどのUnix系。Linux専用とはしない | [lsof](https://github.com/lsof-org/lsof)、[tcpdump](https://github.com/the-tcpdump-group/tcpdump) |
| crontab | cronの導入・実装に依存。教材はLinuxの例 | [Cronie](https://github.com/cronie-crond/cronie) |
| last / lastlog | 教材はwtmp / shadow-utilsのlastlogを使うLinux環境。全環境で同じ記録があるとは限らない | [util-linux](https://github.com/util-linux/util-linux)、[shadow](https://github.com/shadow-maint/shadow) |
| nslookup / dig | nslookupはWindowsにもUnix系にも存在。digはWindows標準ではない。教材の出力例のOSを区別 | [Microsoft nslookup](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/nslookup)、[BIND](https://bind9.readthedocs.io/en/stable/manpages.html) |
| Wireshark | Windows/Linux/macOS等。Windows問題だけに出ることは対応OSを意味しない | [Wireshark](https://www.wireshark.org/about.html) |
| RDAP | OS共通の登録・割当情報。IP・登録Domainを送るExternal Referenceに分類し、非公開の組織情報を推測しない | [ICANN RDAP](https://www.icann.org/rdap) |
| Reputation / Isolated URL Analysis | OS共通のWeb/APIサービスを模したExternal Reference。Hash・File・Domain・IP・完全URLの送信を区別 | [VirusTotal](https://docs.virustotal.com/docs/how-it-works)、[urlscan.io](https://urlscan.io/docs/) |

Raw HeaderはEmailの元Headerを表示する方法で、OS標準コマンド名ではありません。

WSL・コンテナ・リモートで使えることと、Windows本体のProcess・通信を直接調べられることは別です。

## 旧24問から新112問への差分

以下は問題JSON内の調査定義の差分です。実行コードの追加ではありません。現在の問題別の配置・入力・根拠は [Problem Catalog](problem-catalog.md) を正本とします。

### Tool

表示名は旧33種類から現在35種類へ変更。用途別の別名を含み、製品数ではありません。旧表示名をすべて以下に対応付けます。

| 旧Tool | 新Tool・扱い |
| --- | --- |
| Get-FileHash | 継続。PIDからBacking Executableを直接選択できる問題を追加。`Get-FileHash / DLL`・`Get-FileHash / Script`は別の対象Fileを明示した同じTool |
| 7-Zip / 添付Hash | `7-Zip / SHA-256`へ整理。`7-Zip`によるArchive一覧も使用 |
| Event Viewer | `Event Viewer / Windows Security Log`へ統一。独立した重複Toolにはしない |
| Raw Header | `Raw Header / View Source`へ統一。MIME内のURL・添付を同じEmail案件で扱う |
| ExifTool / 添付 | 現在の112問では未使用。`EMAIL-GENUINE-URGENT`の任意調査から削除。Tool実装・UIは変更なし |
| Resolve-DnsName [Windows] | `Resolve-DnsName`。対応OSはenvironmentsで指定 |
| dig [Linux] | `dig`。対応OSはenvironmentsで指定 |
| Strings（Sysinternals）、strings（GNU） | `Strings (Sysinternals)`、`strings (GNU)`。表記整理のみ、別実装として維持 |
| lsof -i | 継続。FileのFDを調べる`lsof`の用途を追加 |
| RDAP、RDAP / URL | External Referenceの`RDAP`に統一 |
| Python / URL分解 | プレイヤー向けToolから削除。Hostは受付情報またはMIMEの抽出情報 |
| Sigcheck、Get-NetTCPConnection、Process Explorer、TCPView、Task Manager、Wireshark、crontab、file、journalctl、last、lastlog、nslookup、ps、pstree、readelf、sha256sum、ss、systemctl、tar、tcpdump | 表示名を維持。旧問題の出力は引き継がず、新問題の対象・時系列に合わせて作成 |
| なし | `Autoruns`を追加。自動起動の登録内容と方針を比較 |
| なし | `unzip`を追加。Emailの添付ZIPを7-Zipと同じ一覧で調べる代替経路 |

### Reference

表示名は33種類から37種類へ整理。旧33種類の対応先と新規資料は次のとおりです。

| 旧Reference | 新Reference・扱い |
| --- | --- |
| Approved Software、Company Directory、Service構成台帳、管理Script台帳、外部照会方針、npm Registry / Package Metadata | 表示名を維持し、新しい案件の記録へ置換 |
| Vendor公開Hash | Vendor Published Hash |
| Approved Server、Approved Server / Software | Approved ServersとApproved Softwareへ分離 |
| Official Domain、承認済みDNS台帳、会議サービスの手引き | Official Service / Domain。変更中のDomainはCampaign / Change Reference・契約 / Change Referenceも参照 |
| Device登録 / 交換申請、過去Login / Device台帳 | Device Reference・Login History・Release / Change Referenceへ分離 |
| 過去Login / Approved VPN | Login History・Approved VPNへ分離 |
| 認証方針、保守予定 / 認証方針、保守予定 / Company Directory | User / Account Policy・承認済みJob・Company Directoryへ整理 |
| 取引先Directory | Vendor Directory |
| 別経路の確認記録 | 口座変更手順と申請・独立確認の登録状況。新問題は確認未完了を根拠に保留し、侵害を断定しない |
| 配送書類の仕様 | 受入れ形式 |
| 公開済み資料台帳 | 公開資料 / Change Reference |
| PyPI / Package Metadata | PyPI Registry / Package Metadata |
| Repository / Approved Component、Repository / Build Review、Repository / 配布物のReview | Official Repository / Approved Component・Package Source / 静的Review |
| Lock file、Lock file / 承認済み依存 | Lock File |
| Maintainer告知 | Release / Change Reference。Maintainer侵害を前提にした旧問題は削除 |
| OSV | Vulnerability Database。架空の脆弱性記録と利用条件を照合 |
| 接続先の調査記録、組織内の調査記録 | 外部評判を内部資料で代用する構成を削除し、IP Reputation等をExternal Referenceに配置 |
| 組織内の隔離調査レポート | 削除。Isolated URL AnalysisのExternal Referenceを実際に選ぶ問題へ置換 |
| 旧ToolのRDAP | External ReferenceのRDAPへ移動 |
| なし | Trusted Publisher、Approved Bastion、Approved Administrative Path、Internal Package Reference、Past Thread、Mail Gateway構成、自動起動方針、通信方針、File / 通信方針、Component導入方針、振込手順を追加 |

### External Reference

旧5種類を次の7種類に整理しました。サービス名ではなく、送信対象と用途を表示します。

| 旧表示名 | 新表示名 | 送信対象 |
| --- | --- | --- |
| VirusTotal / Hash検索 | External Hash Reputation | SHA-256のみ |
| VirusTotal / File Upload | External File Reputation | File本体 |
| VirusTotal / Domain検索 | Domain Reputation | Domainのみ |
| なし | IP Reputation | IPのみ |
| なし | URL Reputation | Path・Queryを含む完全URL |
| urlscan.io / 公開URL、urlscan.io / 完全URL | Isolated URL Analysis | 完全URLを隔離環境へ送信し、アクセス結果を取得 |
| RDAP（Tool / Reference） | RDAP | IPまたは登録Domain |

公開Fileの送信が可能な問題と、社外秘File・Token付きURLの送信が禁止される問題を両方用意しています。PCAP・Email本体の外部解析サービスは追加せず、資料内の送信方針で機密情報を含む対象として区別しています。
