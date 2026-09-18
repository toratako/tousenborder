"""Compose six how-to slides from Godot screenshots using ImageMagick.

Run tests/capture_how_to.gd with a display before this script, then reimport
Godot assets. Runtime uses only the generated PNGs, not ImageMagick.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/screenshots/how_to"
OUTPUT = ROOT / "assets/how_to"
FONT = ROOT / "assets/fonts/NotoSansCJK-Regular.ttc"
INK = "#e4f5ff"
MUTED = "#b0c8da"
GREEN = "#57edc2"
CYAN = "#57e4f2"


class Slide:
    def __init__(self, number: int, title: str, subtitle: str):
        self.args = ["magick", "-size", "1440x750", "xc:#070e1b",
                     "-font", str(FONT), "-gravity", "NorthWest"]
        self.text(40, 25, f"遊び方  /  {number:02d}", 20, GREEN)
        self.text(40, 62, title, 38)
        self.text(40, 117, subtitle, 24, MUTED)
        self.args += ["-stroke", "#34556f", "-strokewidth", "1", "-draw", "line 40,162 1400,162"]

    def text(self, x, y, text, size=28, color=INK):
        self.args += ["-stroke", "none", "-fill", color, "-pointsize", str(size),
                      "-annotate", f"+{x}+{y}", text]

    def crop(self, name, crop, x, y, width):
        self.args += ["(", str(SOURCE / f"{name}.png"), "-crop", crop,
                      "+repage", "-resize", str(width), ")", "-geometry", f"+{x}+{y}", "-composite"]

    def box(self, x, y, w, h, color=GREEN):
        self.args += ["-fill", "none", "-stroke", color, "-strokewidth", "3",
                      "-draw", f"roundrectangle {x},{y} {x+w},{y+h} 8,8"]

    def arrow(self, x1, y1, x2, y2, color=GREEN):
        import math
        angle = math.atan2(y2-y1, x2-x1)
        points = [(x2 - 20*math.cos(angle-offset), y2 - 20*math.sin(angle-offset))
                  for offset in [-0.5, 0.5]]
        self.args += ["-fill", "none", "-stroke", color, "-strokewidth", "4", "-draw",
                      f"path 'M {x1},{y1} L {x2},{y2} M {points[0][0]},{points[0][1]} L {x2},{y2} L {points[1][0]},{points[1][1]}'"]

    def save(self, name):
        subprocess.run(self.args + ["-strip", str(OUTPUT / name)], check=True, cwd=ROOT)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    slide = Slide(1, "まず、何を判断するか読む", "対象の情報を調べて、許可（ALLOW）か遮断（BLOCK）を決めます。")
    slide.crop("target", "480x592+20+94", 72, 186, 432)
    slide.box(82, 235, 410, 100, CYAN)
    slide.text(580, 223, "申請内容", 28, CYAN)
    slide.text(580, 270, "何を許可してほしいのか、\nどの時点の判断なのかを確認。", 30)
    slide.text(580, 392, "基本情報", 28, CYAN)
    slide.text(580, 439, "名前・URL・入手元などを読み、\n必要な情報を調べます。", 30)
    slide.text(580, 627, "基本情報だけで判断できる案件もあります。", 24, MUTED)
    slide.save("01-target.png")

    slide = Slide(2, "情報を選んで、Toolで調べる", "① 情報をクリック → ② 対応するツールをクリック。ドラッグでも渡せます。")
    slide.text(80, 198, "① 調べる情報を選択", 27, CYAN)
    slide.crop("tools", "480x250+20+270", 80, 258, 600)
    slide.box(94, 300, 572, 79, CYAN)
    slide.text(878, 198, "② ツールをクリック", 27, GREEN)
    slide.crop("tools", "264x228+1006+136", 878, 258, 448)
    slide.box(883, 294, 431, 110)
    slide.arrow(692, 343, 860, 343)
    slide.text(80, 615, "選ぶと、対応するツールが緑色になります。", 28)
    slide.text(80, 670, "取得した結果の情報も、対応する次のツールに渡せます。", 24, MUTED)
    slide.save("02-tools.png")

    slide = Slide(3, "調査結果を、Referenceと比較する", "Referenceはクリックで開く比較資料。結果と仕様・承認記録を照合します。")
    slide.text(72, 194, "Toolの結果", 27, CYAN)
    slide.crop("compare", "380x239+524+94", 72, 246, 570)
    slide.text(798, 194, "Referenceの資料", 27, GREEN)
    slide.crop("compare", "380x185+524+394", 798, 246, 570)
    slide.text(685, 365, "↔", 48, GREEN)
    slide.text(72, 637, "例：実体は実行ファイル（ELF）。資料ではPDFのみ。", 28)
    slide.text(72, 685, "資料が重なったら、見出しをドラッグして移動できます。", 23, MUTED)
    slide.save("03-compare.png")

    slide = Slide(4, "外部照会は、送信内容を確認", "送信する情報と、案件の外部照会方針を確認してから選びます。")
    slide.crop("external", "720x560+280+120", 40, 183, 700)
    slide.box(60, 419, 651, 62, CYAN)
    slide.text(800, 239, "URLに秘密情報が含まれていない？", 27, CYAN)
    slide.text(800, 302, "この例では、再設定用Tokenが\n外部サービスに渡ります。", 28)
    slide.text(800, 450, "送らない判断もできます。", 30, GREEN)
    slide.text(800, 511, "「送信を見送る」で調査へ戻れます。", 25)
    slide.text(800, 649, "ゲーム内の照会はすべて模擬です。", 23, MUTED)
    slide.save("04-external.png")

    slide = Slide(5, "スタンプを対象へドラッグして判定", "ALLOWは許可、BLOCKは遮断。対象に落とすと判定が確定します。")
    slide.crop("target", "480x592+20+94", 72, 186, 432)
    slide.text(655, 229, "調べた情報から、どちらかを選ぶ", 30)
    slide.crop("target", "284x90+118+710", 700, 315, 568)
    slide.arrow(686, 415, 407, 532)
    slide.box(82, 199, 410, 506, CYAN)
    slide.text(655, 556, "スタンプ → 左の検査対象", 32, GREEN)
    slide.text(655, 627, "クリックだけでは判定されません。", 26, MUTED)
    slide.save("05-stamp.png")

    slide = Slide(6, "監査票で理由を確認して、次の案件へ", "正解・誤判定と理由を読み、判断の根拠を振り返ります。")
    slide.crop("audit", "680x540+300+119", 40, 182, 680)
    slide.text(792, 239, "判定の理由を読む", 30, CYAN)
    slide.text(792, 298, "自分が見た情報と、\n監査所見を比べてみましょう。", 28)
    slide.text(792, 451, "確認したら次へ", 30, GREEN)
    slide.text(792, 510, "最後の案件では、勤務結果へ進みます。", 25)
    slide.text(792, 641, "操作を忘れたら、右上の「遊び方」へ。", 24, MUTED)
    slide.save("06-audit.png")
    print(f"Generated 6 slides in {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
