# Tool利用環境の確認（2026-09-17）

> 当日の公式資料の確認記録です。現行の実行条件は [対象OSと調査OS](runtime-flow.md#対象osと調査os)、配置済みの教材は [Problem Catalog](problem-catalog.md) を参照してください。

`platform_note` は代表的な利用環境の説明で、出題先OSや実行制御とは別。移植版・追加ランタイム等の網羅や全バージョンの動作保証は対象外です。

| Tool / 機能 | 確認・修正内容 | 一次資料 |
| --- | --- | --- |
| Get-FileHash | 教材ではWindowsのToolとして扱う。他OSでのPowerShell 7利用は対象外 | [コマンド](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash)、[PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview) |
| Resolve-DnsName / Get-NetTCPConnection | Windows用モジュール。PowerShell本体の複数OS対応とは区別 | [DnsClient](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname)、[NetTCPIP](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection) |
| Sigcheck / Process Explorer / TCPView | WindowsのSysinternals製品。別途導入 | [Sigcheck](https://learn.microsoft.com/en-us/sysinternals/downloads/sigcheck)、[Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)、[TCPView](https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview) |
| Strings | Sysinternals版とGNU版は別実装。Fileの文字列抽出であり、PIDを渡してMemoryを読むコマンドではない | [Strings](https://learn.microsoft.com/en-us/sysinternals/downloads/strings)、[GNU Binutils](https://sourceware.org/binutils/docs/binutils.html) |
| Task Manager / Event Viewer | Windows標準機能 | [Windowsの構成ツール](https://support.microsoft.com/en-us/windows/experience/system-configuration-tools-in-windows)、[Event Viewer](https://learn.microsoft.com/en-us/shows/inside/event-viewer) |
| file | Linux/macOS等。Tool実行OSと検査Fileの対象OSは別 | [file開発元ミラー](https://github.com/file/file) |
| readelf | GNU BinutilsのELF調査。ELF対応とTool実行OSを混同しない | [readelf](https://sourceware.org/binutils/docs/binutils/readelf.html) |
| sha256sum | GNU Coreutils。各OSに標準で入っているとは限らない | [GNU Coreutils](https://www.gnu.org/s/coreutils/manual/html_node/sha2-utilities.html) |
| tar | LinuxのGNU tarとWindowsのbsdtarを区別 | [GNU tar](https://www.gnu.org/software/tar/)、[Windowsのtar](https://learn.microsoft.com/en-us/windows/tar/) |
| ExifTool / 7-Zip | Windows/Linux/macOS。7-ZipのCLI名は配布形態によって異なる | [ExifTool](https://exiftool.org/install.html)、[7-Zip](https://www.7-zip.org/download.html) |
| ps / pstree | 教材はLinuxのprocps-ng / PSmisc。別OS・別実装との違いを明記 | [procps-ng](https://gitlab.com/procps-ng/procps)、[PSmisc](https://gitlab.com/psmisc/psmisc) |
| systemctl / journalctl | 表示はLinux。教材はsystemdを使う一般的な構成を前提とし、構成差の説明は主表示に含めない | [systemd](https://github.com/systemd/systemd) |
| ss | Linuxのiproute2 | [iproute2](https://github.com/iproute2/iproute2) |
| lsof / tcpdump | Linux/macOSなどのUnix系。Linux専用とはしない | [lsof](https://github.com/lsof-org/lsof)、[tcpdump](https://github.com/the-tcpdump-group/tcpdump) |
| crontab | cronの導入・実装に依存。教材はLinuxの例 | [Cronie](https://github.com/cronie-crond/cronie) |
| last / lastlog | 教材はwtmp / shadow-utilsのlastlogを使うLinux環境。全環境で同じ記録があるとは限らない | [util-linux](https://github.com/util-linux/util-linux)、[shadow](https://github.com/shadow-maint/shadow) |
| nslookup / dig | nslookupはWindowsにもUnix系にも存在。digはWindows標準ではない。教材の出力例のOSを区別 | [Microsoft nslookup](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/nslookup)、[BIND](https://bind9.readthedocs.io/en/stable/manpages.html) |
| Wireshark | Windows/Linux/macOS等。Windows問題だけに出ることは対応OSを意味しない | [Wireshark](https://www.wireshark.org/about.html) |
| Python / URL分解 | Python 3と標準ライブラリ。ローカル文字列処理 | [urllib.parse](https://docs.python.org/3/library/urllib.parse.html) |
| RDAP / WHOIS | OS共通の照会方式。特定のOS標準コマンドとは扱わない | [ICANN RDAP](https://www.icann.org/rdap) |
| VirusTotal / urlscan.io | OS共通のWeb/APIサービス。ゲーム内は模擬照会 | [VirusTotal](https://docs.virustotal.com/docs/how-it-works)、[urlscan.io](https://urlscan.io/docs/) |

Raw HeaderはEmailの元Headerを表示する調査方法、RDAPは照会方式で、特定のOS標準コマンド名ではありません。

WSL・コンテナ・リモート実行で使えることと、Windows本体のProcess・通信を直接調べられることは別である。利用環境の説明は問題選択やTool実行可否の条件に転用しない。
