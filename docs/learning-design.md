# セキュリティ判断の学習設計

問題・出典は [Problem Catalog](problem-catalog.md)，作問は [教材データ](problem-data.md#追加変更の手順)，採点は [実行時の処理](runtime-flow.md#調査から判定まで)．

## 種別と判定時点

| 種別                     | 判定時点                                                     |
| ------------------------ | ------------------------------------------------------------ |
| File                     | 開く・実行する前                                             |
| Web                      | ブラウザで開く前                                             |
| Package                  | インストール / アップデート前                                |
| Process                  | 起動済みプロセスの継続／停止                                 |
| Network                  | 現在の接続要求．過去Flow・現在のソケット・所有プロセスと比較 |
| Email                    | 受信保留中のメールの受入れ                                   |
| Account / Authentication | セッション成立前                                             |

## 外部照会の判断

送信先・対象の機密区分はReferenceの方針で確認します．

- Hash検索とFile本体のUploadは別操作．VirusTotalの通常のFile送信では検体が共有され得るため，Hash照会も含め組織方針に従います（[検索](https://docs.virustotal.com/docs/searching)，[共有の仕組み](https://docs.virustotal.com/docs/how-it-works)）．
- urlscan.ioはPrivateでもURLがサービスに渡ります．教材ではToken付きURLの送信を禁止し，公開Domainだけの照会を別に用意します（[API](https://urlscan.io/docs/api/)）．

## Tool Outputと実例

出力は抜粋．Hashは合成値，IPは文書用，組織・Domain・Package・脆弱性は架空とし，脆弱性IDは `TRAINING-` を使います．Command・Sourceの編集箇所は `〔…を省略〕` と表示し，判断に必要な取得先・呼出しを残します．レジストリ情報・OSVも模擬資料で，実在パッケージの評判や現在の脆弱性情報を示しません．

実例は攻撃名を知らなくても根拠から解ける構成にし，各問題の `sources` に一次資料を残します．
