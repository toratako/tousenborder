# Problem index

公開教材 70問。問題JSONから生成した開発者用の索引（正解を含む）。
`python3 scripts/build_problem_catalog.py` で再生成、`--check` で差分を検証。
分類・到達性の検証はゲームと同じ `ProblemLoader` を使用する。手書きのCatalogは持たない。

| ID | 分野 | OS | 難易度 | 調査形式 | Title | 正解 |
| --- | --- | --- | --- | --- | --- | --- |
| [AUTH-LINUX-FAILURE-THRESHOLD](<../data/problems/AUTH-LINUX-FAILURE-THRESHOLD.json>) | account | linux | unrated | tools | SSH認証失敗の接続元別しきい値 | BLOCK |
| [AUTH-LINUX-LOGIN-HISTORY](<../data/problems/AUTH-LINUX-LOGIN-HISTORY.json>) | account | linux | unrated | tools | 踏み台からの通常のSSHログイン | ALLOW |
| [AUTH-LINUX-SERVICE-LOGIN](<../data/problems/AUTH-LINUX-SERVICE-LOGIN.json>) | account | linux | unrated | tools | サービスアカウントへの対話型SSHログイン | BLOCK |
| [AUTH-LINUX-SSH-PASSWORD-SPRAY](<../data/problems/AUTH-LINUX-SSH-PASSWORD-SPRAY.json>) | account | linux | unrated | tools | SSHパスワードスプレーを疑う履歴 | BLOCK |
| [AUTH-WIN-FAILURE-BURST](<../data/problems/AUTH-WIN-FAILURE-BURST.json>) | account | windows | unrated | references | 短時間の失敗と一時遮断規則 | BLOCK |
| [AUTH-WIN-PASSWORD-SPRAY](<../data/problems/AUTH-WIN-PASSWORD-SPRAY.json>) | account | windows | unrated | tools | パスワードスプレーを疑う認証失敗の分布 | BLOCK |
| [AUTH-WIN-RETIRED-USER](<../data/problems/AUTH-WIN-RETIRED-USER.json>) | account | windows | unrated | tools | 退職済みユーザーへのログイン要求 | BLOCK |
| [AUTH-WIN-REVOKED-DEVICE](<../data/problems/AUTH-WIN-REVOKED-DEVICE.json>) | account | windows | unrated | tools | 登録解除済みの端末 | BLOCK |
| [AUTH-WIN-SERVICE-INTERACTIVE](<../data/problems/AUTH-WIN-SERVICE-INTERACTIVE.json>) | account | windows | unrated | tools | サービスアカウントへの対話型ログイン | BLOCK |
| [AUTH-WIN-USUAL-LOGIN](<../data/problems/AUTH-WIN-USUAL-LOGIN.json>) | account | windows | unrated | tools | 通常端末からのMFA確認済みログイン | ALLOW |
| [EMAIL-ATTACHMENT-NAME](<../data/problems/EMAIL-ATTACHMENT-NAME.json>) | email | common | unrated | references | PDFと説明された.exe添付 | BLOCK |
| [EMAIL-AUTH-FAILURE](<../data/problems/EMAIL-AUTH-FAILURE.json>) | email | common | unrated | tools | 自社ドメインを名乗る直接配送 | BLOCK |
| [EMAIL-BEC-DESTINATION](<../data/problems/EMAIL-BEC-DESTINATION.json>) | email | common | unrated | tools | BEC — 振込先の変更依頼 | BLOCK |
| [EMAIL-BEC-REAL-ACCOUNT](<../data/problems/EMAIL-BEC-REAL-ACCOUNT.json>) | email | common | unrated | tools | BEC — 取引先アドレスからの振込先変更 | BLOCK |
| [EMAIL-DISPLAY-NAME](<../data/problems/EMAIL-DISPLAY-NAME.json>) | email | common | unrated | references | 社内役員名の表示名偽装 | BLOCK |
| [EMAIL-REPLY-ADDRESS](<../data/problems/EMAIL-REPLY-ADDRESS.json>) | email | common | unrated | tools | 返信先だけが別の組織 | BLOCK |
| [EMAIL-SERVICE-NOTICE](<../data/problems/EMAIL-SERVICE-NOTICE.json>) | email | common | unrated | tools | 承認サービスからの通常通知 | ALLOW |
| [FILE-LINUX-ARCHIVE-MEMBERS](<../data/problems/FILE-LINUX-ARCHIVE-MEMBERS.json>) | file | linux | unrated | tools | アーカイブ内の実行用スクリプト | BLOCK |
| [FILE-LINUX-ELF-AS-DOCUMENT](<../data/problems/FILE-LINUX-ELF-AS-DOCUMENT.json>) | file | linux | unrated | tools | PDFとして届いたELF | BLOCK |
| [FILE-LINUX-ELF-INTERPRETER](<../data/problems/FILE-LINUX-ELF-INTERPRETER.json>) | file | linux | unrated | tools | 承認されていないELFインタープリター | BLOCK |
| [FILE-LINUX-KNOWN-HASH](<../data/problems/FILE-LINUX-KNOWN-HASH.json>) | file | linux | unrated | external | Linux実行ファイルの外部ハッシュ照会 | BLOCK |
| [FILE-LINUX-ORDINARY-ELF](<../data/problems/FILE-LINUX-ORDINARY-ELF.json>) | file | linux | unrated | external | 普通のELFに含まれる外部URL | BLOCK |
| [FILE-LINUX-PUBLISHED-HASH](<../data/problems/FILE-LINUX-PUBLISHED-HASH.json>) | file | linux | unrated | tools | Linux配布アーカイブの同一性 | ALLOW |
| [FILE-LINUX-SCRIPT-NAME](<../data/problems/FILE-LINUX-SCRIPT-NAME.json>) | file | linux | unrated | references | PDF名を含むシェルスクリプト | BLOCK |
| [FILE-WIN-ARCHIVE-CONTENTS](<../data/problems/FILE-WIN-ARCHIVE-CONTENTS.json>) | file | windows | unrated | tools | 資料アーカイブに含まれるスクリプト | BLOCK |
| [FILE-WIN-DOUBLE-EXTENSION](<../data/problems/FILE-WIN-DOUBLE-EXTENSION.json>) | file | windows | unrated | references | 二重拡張子の請求書 | BLOCK |
| [FILE-WIN-EMBEDDED-DOMAIN](<../data/problems/FILE-WIN-EMBEDDED-DOMAIN.json>) | file | windows | unrated | external | 埋め込み文字列とドメインの検出履歴 | BLOCK |
| [FILE-WIN-FAKE-UPDATE](<../data/problems/FILE-WIN-FAKE-UPDATE.json>) | file | windows | unrated | tools | 偽のソフトウェア更新 | BLOCK |
| [FILE-WIN-KNOWN-HASH](<../data/problems/FILE-WIN-KNOWN-HASH.json>) | file | windows | unrated | external | ハッシュ照会で見つかる検出履歴 | BLOCK |
| [FILE-WIN-MODIFIED-INSTALLER](<../data/problems/FILE-WIN-MODIFIED-INSTALLER.json>) | file | windows | unrated | tools | 承認配布物とのハッシュ不一致 | BLOCK |
| [FILE-WIN-PUBLISHED-HASH](<../data/problems/FILE-WIN-PUBLISHED-HASH.json>) | file | windows | unrated | tools | ベンダー公開ハッシュとの一致 | ALLOW |
| [FILE-WIN-PUBLISHER](<../data/problems/FILE-WIN-PUBLISHER.json>) | file | windows | unrated | tools | 承認された署名付き配布物 | ALLOW |
| [NET-LINUX-ACTIVE-APPROVED](<../data/problems/NET-LINUX-ACTIVE-APPROVED.json>) | network | linux | unrated | tools | 承認済みエージェントの接続 | ALLOW |
| [NET-LINUX-IP-REPUTATION](<../data/problems/NET-LINUX-IP-REPUTATION.json>) | network | linux | unrated | external | 接続先IPの既知検出 | BLOCK |
| [NET-LINUX-PLAINTEXT-POST](<../data/problems/NET-LINUX-PLAINTEXT-POST.json>) | network | linux | unrated | tools | 平文HTTPで送る認証情報 | BLOCK |
| [NET-WIN-ACTIVE-APPROVED](<../data/problems/NET-WIN-ACTIVE-APPROVED.json>) | network | windows | unrated | tools | 承認済みエージェントの接続 | ALLOW |
| [NET-WIN-IP-REPUTATION](<../data/problems/NET-WIN-IP-REPUTATION.json>) | network | windows | unrated | external | 接続先IPの既知検出 | BLOCK |
| [NET-WIN-PLAINTEXT-POST](<../data/problems/NET-WIN-PLAINTEXT-POST.json>) | network | windows | unrated | tools | 平文HTTPで送る認証情報 | BLOCK |
| [PKG-NPM-LOCKED-DEPENDENCY](<../data/problems/PKG-NPM-LOCKED-DEPENDENCY.json>) | package | common | unrated | references | ロックファイルと一致する依存パッケージ | ALLOW |
| [PKG-NPM-REGISTRY-METADATA](<../data/problems/PKG-NPM-REGISTRY-METADATA.json>) | package | common | unrated | references | npmの正規配布情報 | ALLOW |
| [PKG-NPM-REPOSITORY-MISMATCH](<../data/problems/PKG-NPM-REPOSITORY-MISMATCH.json>) | package | common | unrated | references | リポジトリの相違 | BLOCK |
| [PKG-NPM-SUBTLE-TYPO](<../data/problems/PKG-NPM-SUBTLE-TYPO.json>) | package | common | unrated | references | 見分けにくいタイポスクワッティング | BLOCK |
| [PKG-PYPI-DEPENDENCY-CONFUSION](<../data/problems/PKG-PYPI-DEPENDENCY-CONFUSION.json>) | package | common | unrated | references | 依存関係の混同 | BLOCK |
| [PKG-PYPI-KNOWN-VULNERABILITY](<../data/problems/PKG-PYPI-KNOWN-VULNERABILITY.json>) | package | common | unrated | references | 組織方針で禁止された脆弱バージョン | BLOCK |
| [PKG-PYPI-OBVIOUS-TYPO](<../data/problems/PKG-PYPI-OBVIOUS-TYPO.json>) | package | common | unrated | references | 明白なタイポスクワッティング | BLOCK |
| [PKG-PYPI-REGISTRY-METADATA](<../data/problems/PKG-PYPI-REGISTRY-METADATA.json>) | package | common | unrated | references | PyPIの正規配布情報 | ALLOW |
| [PROC-LINUX-APPROVED-ARGS](<../data/problems/PROC-LINUX-APPROVED-ARGS.json>) | process | linux | unrated | tools | 承認済みサービスの引数 | ALLOW |
| [PROC-LINUX-CRON-JOB](<../data/problems/PROC-LINUX-CRON-JOB.json>) | process | linux | unrated | tools | 定例crontabの保守ジョブ | ALLOW |
| [PROC-LINUX-CRON-PERSISTENCE](<../data/problems/PROC-LINUX-CRON-PERSISTENCE.json>) | process | linux | unrated | tools | cronによる永続化 | BLOCK |
| [PROC-LINUX-OPEN-PRIVATE-KEY](<../data/problems/PROC-LINUX-OPEN-PRIVATE-KEY.json>) | process | linux | unrated | tools | 業務外の秘密鍵を開くプロセス | BLOCK |
| [PROC-LINUX-SERVICE-UNIT](<../data/problems/PROC-LINUX-SERVICE-UNIT.json>) | process | linux | unrated | tools | 承認済みのsystemdサービス | ALLOW |
| [PROC-LINUX-SOCKET-REPUTATION](<../data/problems/PROC-LINUX-SOCKET-REPUTATION.json>) | process | linux | unrated | external | 稼働プロセスの通信先照会 | BLOCK |
| [PROC-LINUX-WEB-CHILD](<../data/problems/PROC-LINUX-WEB-CHILD.json>) | process | linux | unrated | tools | Webサービス配下のシェル | BLOCK |
| [PROC-WIN-BACKING-HASH](<../data/problems/PROC-WIN-BACKING-HASH.json>) | process | windows | unrated | tools | 実行中イメージのハッシュ不一致 | BLOCK |
| [PROC-WIN-BACKING-SIGNATURE](<../data/problems/PROC-WIN-BACKING-SIGNATURE.json>) | process | windows | unrated | tools | 実行中イメージの署名照合 | ALLOW |
| [PROC-WIN-CLICKFIX](<../data/problems/PROC-WIN-CLICKFIX.json>) | process | windows | unrated | tools | 偽CAPTCHAによるコマンド実行誘導 | BLOCK |
| [PROC-WIN-DLL-SIDELOAD](<../data/problems/PROC-WIN-DLL-SIDELOAD.json>) | process | windows | unrated | tools | DLLサイドローディング | BLOCK |
| [PROC-WIN-HIGH-CPU](<../data/problems/PROC-WIN-HIGH-CPU.json>) | process | windows | unrated | tools | 高CPUの動画変換 | ALLOW |
| [PROC-WIN-IMAGE-PATH](<../data/problems/PROC-WIN-IMAGE-PATH.json>) | process | windows | unrated | tools | 想定外のプロセス配置 | BLOCK |
| [PROC-WIN-LOLBIN](<../data/problems/PROC-WIN-LOLBIN.json>) | process | windows | unrated | tools | LOLBinによる外部HTA実行 | BLOCK |
| [PROC-WIN-OFFICE-DOWNLOAD](<../data/problems/PROC-WIN-OFFICE-DOWNLOAD.json>) | process | windows | unrated | external | Officeからの外部取得コマンド | BLOCK |
| [PROC-WIN-STARTUP-ENTRY](<../data/problems/PROC-WIN-STARTUP-ENTRY.json>) | process | windows | unrated | tools | Temp配下からの自動起動 | BLOCK |
| [PROC-WIN-SYSTEM-NAME](<../data/problems/PROC-WIN-SYSTEM-NAME.json>) | process | windows | unrated | references | システムプロセスの管理パス照合 | ALLOW |
| [WEB-DOMAIN-REPUTATION](<../data/problems/WEB-DOMAIN-REPUTATION.json>) | web | common | unrated | external | ドメインの既知フィッシング報告 | BLOCK |
| [WEB-ISOLATED-REDIRECT](<../data/problems/WEB-ISOLATED-REDIRECT.json>) | web | common | unrated | external | 隔離解析で判明するログイン先 | BLOCK |
| [WEB-LINK-MISMATCH](<../data/problems/WEB-LINK-MISMATCH.json>) | web | common | unrated | references | 表示とパスが異なる正規公開ページ | ALLOW |
| [WEB-LINUX-DNS](<../data/problems/WEB-LINUX-DNS.json>) | web | linux | unrated | tools | Linuxで解決先を確認する | ALLOW |
| [WEB-MISLEADING-HOST](<../data/problems/WEB-MISLEADING-HOST.json>) | web | common | unrated | references | 正規ドメインに見せた別ホスト | BLOCK |
| [WEB-URL-REPUTATION](<../data/problems/WEB-URL-REPUTATION.json>) | web | common | unrated | external | 完全URLに対する検出履歴 | BLOCK |
| [WEB-WIN-DNS](<../data/problems/WEB-WIN-DNS.json>) | web | windows | unrated | tools | Windowsで解決先を確認する | ALLOW |
