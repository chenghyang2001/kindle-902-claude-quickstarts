#!/bin/bash
# K902 第 8 章互動演練：computer-use-best-practices——截圖尺寸、裁舊截圖、快取斷點與批次工具，導讀＋小模擬，一次跑一步
# 用法：bash ch08.sh <步驟 1-8>
# 呼叫模型：只有第 6 步會呼叫模型，最多 2 次（第 1 次執行工具、第 2 次拿回報；或第 1 次沒有 tool_use 時用第 2 次重試 1 次；claude -p，透過 claude_cli_client），其餘步驟全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch08/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K902 第 8 章｜電腦操作最佳實踐 computer-use-best-practices　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "主角登場：檔案表＋「每回合送出前做什麼」流程表"
   tip "這章是導讀＋小模擬：原專案用 pyautogui 直接操作真實 macOS 桌面，這裡不能實跑，也不 import 官方模組。先用 qs_source 把原始碼當文字讀，看懂 loop.py 每回合固定做的三件事。"
   P='import os, sys
sys.path.insert(0, os.getcwd())
from qs_source import root, read_text, grep

P = "computer-use-best-practices/"
print("官方 repo 資料夾：", root().name, "（只讀；不安裝依賴、不執行啟動指令、不需要 macOS、pyautogui 與金鑰）")
print("這章不能實跑：原專案直接用 pyautogui 操作真實 macOS 的滑鼠鍵盤，README 要求在用完即丟的虛擬機裡跑。")
print()
files = [
    ("constants.py", "Config dataclass（所有可調參數）、系統提示、BATCH_REMINDER"),
    ("computer_use/__main__.py", "CLI 入口、build_tools()、build_system_prompt()"),
    ("computer_use/loop.py", "取樣迴圈、重試、快取斷點、compaction、批次提醒"),
    ("computer_use/image.py", "target_image_size() 截圖縮放、JPEG 編碼"),
    ("computer_use/formatters.py", "舊截圖裁剪：StripOldestImages、StripImagesAtIntervals"),
    ("computer_use/tools/computer.py", "ComputerTool：schema、座標換算、zoom"),
    ("computer_use/tools/batch.py", "_BatchTool：依序執行、遇錯即停"),
    ("computer_use/tools/shell.py", "沙箱 bash／python：30 秒逾時、輸出上限"),
    ("sandbox/default.sb", "sandbox-exec 設定檔：只能寫 scratch、禁網路"),
]
print("【表 1】關鍵檔案")
print("{:<32} | {:>4} | {}".format("檔案", "行數", "負責什麼"))
print("-" * 110)
for rel, desc in files:
    print("{:<32} | {:>4} | {}".format(rel, len(read_text(P + rel).splitlines()), desc))
print()

flow = [
    ("__main__.py", "組工具：computer＋computer_batch＋open_application", "computer_use/__main__.py", "ComputerBatchTool[(]computer[)]"),
    ("__main__.py", "組工具：browser＋browser_batch", "computer_use/__main__.py", "BrowserBatchTool[(]browser[)]"),
    ("loop.py", "系統提示放 1 個快取斷點", "computer_use/loop.py", "system_prompt, .cache_control"),
    ("loop.py", "每回合 1：截掉最後一次 compaction 之前的內容", "computer_use/loop.py", "^ +_truncate_to_last_compaction[(]messages[)]"),
    ("loop.py", "每回合 2：裁舊截圖（換成 [Image Omitted]）", "computer_use/loop.py", "^ +prune[(]messages[)]"),
    ("loop.py", "每回合 3：最後幾個 tool_result 放快取斷點", "computer_use/loop.py", "^ +_set_trailing_cache_control[(]messages[)]"),
    ("loop.py", "訊息本體最多幾個斷點", "computer_use/loop.py", "^_MAX_BODY_CACHE_BREAKPOINTS = "),
    ("loop.py", "單一動作時決定要不要提醒用批次", "computer_use/loop.py", "nudge = _should_nudge_batch"),
    ("constants.py", "預設裁圖策略", "constants.py", "^    image_prune_strategy: "),
    ("image.py", "截圖縮放", "computer_use/image.py", "^def target_image_size"),
    ("formatters.py", "快取友善的裁圖類別", "computer_use/formatters.py", "^class StripImagesAtIntervals"),
    ("batch.py", "批次遇錯即停的訊息", "computer_use/tools/batch.py", "batch stopped at actions"),
    ("shell.py", "沙箱 bash／python 逾時", "computer_use/tools/shell.py", "^_TIMEOUT_S = "),
]
print("【表 2】誰負責什麼（行號從原始碼 grep 出來）")
print("{:<14} | {:<44} | {:<20} | {}".format("誰", "做什麼", "檔案:行號", "原文"))
print("-" * 150)
for who, what, rel, pat in flow:
    hits = grep(P + rel, pat)
    where = rel.split("/")[-1] + ":" + (str(hits[0][0]) if hits else "-")
    text = hits[0][1].strip()[:80] if hits else "找不到"
    print("{:<14} | {:<44} | {:<20} | {}".format(who, what, where, text))
print()
print("→ 每一回合送出前固定三件事：截 compaction、裁舊截圖、放快取斷點；後面練習 1 就是在重算「裁舊截圖」與「截圖尺寸」。")
print("→ 批次工具 computer_batch 只是把同一個 computer 工具包一層迴圈；練習 2 會在假桌面上重現它。")'
   show "$P"; run "$P" ;;
2) banner "練習 1 之一：Config 預設值＋重寫 target_image_size"
   tip "API 把圖切成 28x28 的格子，長邊上限 1568 px、格子最多 1568 個。自己先縮圖，模型看到的就是你送的圖；記住送出的寬高，才能把模型座標乘回螢幕。這一步不寫檔、不呼叫模型。"
   P='import os, sys
sys.path.insert(0, os.getcwd())
from qs_source import grep

C = "computer-use-best-practices/constants.py"
IMG = "computer-use-best-practices/computer_use/image.py"
COMP = "computer-use-best-practices/computer_use/tools/computer.py"
NAMES = ["px_per_token", "max_edge_px", "max_tokens", "keep_n_most_recent_images", "image_prune_min", "image_prune_interval", "browser_viewport"]
cfg = {}
print("【表 1】constants.py 的 Config 預設值（qs_source.grep 抓出來的）")
print("{:>4} | {:<26} | {}".format("行號", "欄位", "預設值"))
print("-" * 60)
for name in NAMES:
    no, line = grep(C, "^    " + name + ": ")[0]
    raw = line.split("=", 1)[1].split("#")[0].strip()
    cfg[name] = raw
    print("{:>4} | {:<26} | {}".format(no, name, raw))
PX = int(cfg["px_per_token"])
EDGE = int(cfg["max_edge_px"])
MAXT = int(cfg["max_tokens"])
print()
print("官方函式位置（本步不 import，照它自己重寫）：")
for no, line in grep(IMG, "^def (n_tokens_for_px|n_tokens_for_img|target_image_size)|if height > width|lo, hi = 1, width"):
    print("  image.py 第 {:>3} 行：{}".format(no, line.strip()))
print()

def n_tokens_for_px(px, px_per_token=PX):
    return (px - 1) // px_per_token + 1

def n_tokens_for_img(w, h, px_per_token=PX):
    return n_tokens_for_px(w, px_per_token) * n_tokens_for_px(h, px_per_token)

def target_image_size(width, height, px_per_token=PX, max_edge_px=EDGE, max_tokens=MAXT):
    if width <= max_edge_px and height <= max_edge_px and n_tokens_for_img(width, height, px_per_token) <= max_tokens:
        return width, height
    if height > width:
        w, h = target_image_size(height, width, px_per_token, max_edge_px, max_tokens)
        return h, w
    aspect = width / height
    lo, hi = 1, width
    while True:
        if lo + 1 == hi:
            return lo, max(round(lo / aspect), 1)
        mid_w = (lo + hi) // 2
        mid_h = max(round(mid_w / aspect), 1)
        if mid_w <= max_edge_px and n_tokens_for_img(mid_w, mid_h, px_per_token) <= max_tokens:
            lo = mid_w
        else:
            hi = mid_w

SIZES = [(2880, 1800), (1920, 1080), (3840, 2160), (1456, 819), (1280, 720), (1080, 1920)]
print("【表 2】送出尺寸（格子 {} px、長邊上限 {}、格子上限 {}）".format(PX, EDGE, MAXT))
print("{:<11} | {:>8} | {:<11} | {:>6} | {:<6} | {}".format("原始尺寸", "原始格子", "送出尺寸", "格子數", "縮過", "螢幕/圖片比例"))
print("-" * 80)
rows = {}
for w, h in SIZES:
    sw, sh = target_image_size(w, h)
    rows[(w, h)] = (sw, sh)
    print("{:<11} | {:>8} | {:<11} | {:>6} | {:<6} | {:.3f}".format("{}x{}".format(w, h), n_tokens_for_img(w, h), "{}x{}".format(sw, sh), n_tokens_for_img(sw, sh), "是" if (sw, sh) != (w, h) else "否", w / sw))
print()
vp = tuple(int(x) for x in cfg["browser_viewport"].strip("()").split(","))
print("browser_viewport 預設", vp, "→", target_image_size(*vp), "：", "剛好不必縮" if target_image_size(*vp) == vp else "會被縮")
print()

def to_screen(x, y, sent, screen):
    sx = round(x * screen[0] / sent[0])
    sy = round(y * screen[1] / sent[1])
    return max(0, min(sx, screen[0] - 1)), max(0, min(sy, screen[1] - 1))

print("座標換算（照 computer.py 的 _scale_to_screen）：")
for no, line in grep(COMP, "def _scale_to_screen|sx = round[(]x"):
    print("  computer.py 第 {} 行：{}".format(no, line.strip()))
for screen in ((2880, 1800), (1920, 1080)):
    sent = rows[screen]
    sx, sy = to_screen(700, 400, sent, screen)
    print("  螢幕 {}x{}：模型在 {}x{} 的圖上點 (700, 400) → 螢幕 ({}, {})；若忘了換算會差 ({}, {}) px".format(screen[0], screen[1], sent[0], sent[1], sx, sy, sx - 700, sy - 400))
print("→ 縮圖是為了讓模型看到的圖就是你送的圖；記住送出的寬高，才能把模型座標乘回螢幕。")'
   show "$P"; run "$P" ;;
3) banner "練習 1 之二：模擬 60 回合裁舊截圖，數快取前綴改變幾次"
   tip "「只留最後 10 張」每回合換掉的圖都不同，請求前綴一直變；interval 策略讓同一批舊圖在一個週期內固定被換掉，prompt cache 才能持續命中。結果寫到 ch08/interactive/sizing_report.md。"
   P='import os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

C = "computer-use-best-practices/constants.py"
F = "computer-use-best-practices/computer_use/formatters.py"
NAMES = ["px_per_token", "max_edge_px", "max_tokens", "keep_n_most_recent_images", "image_prune_min", "image_prune_interval"]
consts = {}
for name in NAMES:
    no, line = grep(C, "^    " + name + ": ")[0]
    consts[name] = (no, line.split("=", 1)[1].split("#")[0].strip())
PX = int(consts["px_per_token"][1])
EDGE = int(consts["max_edge_px"][1])
MAXT = int(consts["max_tokens"][1])
KEEP = int(consts["keep_n_most_recent_images"][1])
PMIN = int(consts["image_prune_min"][1])
PINT = int(consts["image_prune_interval"][1])
out = Path("ch08/interactive")
out.mkdir(parents=True, exist_ok=True)
report = out / "sizing_report.md"
report.unlink(missing_ok=True)

def n_tokens_for_px(px, px_per_token=PX):
    return (px - 1) // px_per_token + 1

def n_tokens_for_img(w, h, px_per_token=PX):
    return n_tokens_for_px(w, px_per_token) * n_tokens_for_px(h, px_per_token)

def target_image_size(width, height, px_per_token=PX, max_edge_px=EDGE, max_tokens=MAXT):
    if width <= max_edge_px and height <= max_edge_px and n_tokens_for_img(width, height, px_per_token) <= max_tokens:
        return width, height
    if height > width:
        w, h = target_image_size(height, width, px_per_token, max_edge_px, max_tokens)
        return h, w
    aspect = width / height
    lo, hi = 1, width
    while True:
        if lo + 1 == hi:
            return lo, max(round(lo / aspect), 1)
        mid_w = (lo + hi) // 2
        mid_h = max(round(mid_w / aspect), 1)
        if mid_w <= max_edge_px and n_tokens_for_img(mid_w, mid_h, px_per_token) <= max_tokens:
            lo = mid_w
        else:
            hi = mid_w

print("官方裁圖程式：")
for no, line in grep(F, "^_PLACEHOLDER|^class Strip|keep = [(][(]total"):
    print("  formatters.py 第 {:>3} 行：{}".format(no, line.strip()))
print()

TURNS = 60
def simulate(kind, interval=None):
    replaced = []
    for total in range(1, TURNS + 1):
        keep = KEEP if kind == "simple" else (total % interval) + PMIN
        replaced.append(total - keep if total > keep else 0)
    changes = [t for t in range(1, TURNS + 1) if replaced[t - 1] != (replaced[t - 2] if t > 1 else 0)]
    return replaced, changes

runs = [
    ("A simple（只留最後 {} 張）".format(KEEP), simulate("simple")),
    ("B interval（min={}、interval={}）".format(PMIN, PINT), simulate("interval", PINT)),
    ("B interval（min={}、interval=5）".format(PMIN), simulate("interval", 5)),
]
SHOW = [1, 5, 10, 11, 12, 39, 40, 41, 45, 60]
print("【表 1】第 t 回合：被換成 [Image Omitted] 的張數（括號內是保留張數）")
print("{:>4} | {:<14} | {:<14} | {}".format("回合", "A simple", "B interval=" + str(PINT), "B interval=5"))
print("-" * 60)
for t in SHOW:
    cells = ["{}({})".format(r[0][t - 1], t - r[0][t - 1]) for _, r in runs]
    print("{:>4} | {:<14} | {:<14} | {}".format(t, *cells))
print()
print("【表 2】60 回合中「被換掉張數」改變幾次（改變一次＝請求前綴變了、快取要重寫）")
summary = []
for label, (replaced, changes) in runs:
    head = ", ".join(str(t) for t in changes[:6]) + (" …" if len(changes) > 6 else "")
    summary.append((label, len(changes), head))
    print("  {:<34} → {:>2} 次（發生在第 {} 回合）".format(label, len(changes), head))
print()

def simulate_inplace(kind, interval=None):
    alive, changes = 0, []
    for t in range(1, TURNS + 1):
        alive += 1
        keep = KEEP if kind == "simple" else (alive % interval) + PMIN
        if alive > keep:
            alive = keep
            changes.append(t)
    return changes

extra = [len(simulate_inplace("simple")), len(simulate_inplace("interval", PINT)), len(simulate_inplace("interval", 5))]
print("【加碼觀察】loop.py 是對同一份 messages 原地裁圖，而 _image_slots 只數還是 image 的區塊；")
print("  若照這個情況算（已換掉的不再算進 total），三組改變次數是：simple {}、interval={} {}、interval=5 {}".format(extra[0], PINT, extra[1], extra[2]))
print("  （本教材依程式碼推論；官方 tests/test_formatters.py 每次用新的訊息清單，對應上面表 2 的算法。）")
print()

SIZES = [(2880, 1800), (1920, 1080), (3840, 2160), (1456, 819), (1280, 720), (1080, 1920)]
md = ["# 第 8 章練習 1：截圖尺寸與舊截圖裁剪", "", "來源：computer-use-best-practices/constants.py、computer_use/image.py、computer_use/formatters.py（只讀，自己重寫，未 import 官方模組）", "",
      "## Config 預設值", "", "| 欄位 | 值 | 行號 |", "| --- | --- | --- |"]
md += ["| {} | {} | {} |".format(n, consts[n][1], consts[n][0]) for n in NAMES]
md += ["", "## 送出尺寸", "", "| 原始尺寸 | 送出尺寸 | 格子數 | 是否縮過 | 螢幕/圖片比例 |", "| --- | --- | --- | --- | --- |"]
for w, h in SIZES:
    sw, sh = target_image_size(w, h)
    md.append("| {}x{} | {}x{} | {} | {} | {:.3f} |".format(w, h, sw, sh, n_tokens_for_img(sw, sh), "是" if (sw, sh) != (w, h) else "否", w / sw))
md += ["", "## 60 回合的前綴改變次數", "", "| 策略 | 改變次數 | 發生在第幾回合（前 6 個） |", "| --- | --- | --- |"]
md += ["| {} | {} | {} |".format(*s) for s in summary]
md += ["", "加碼（依 loop.py 原地裁圖推論）：simple {}、interval={} {}、interval=5 {}".format(extra[0], PINT, extra[1], extra[2])]
report.write_text("\n".join(md) + "\n", encoding="utf-8")
print("已寫入", report)'
   show "$P"; run "$P" ;;
4) banner "練習 2 之一：假桌面＋兩個自訂工具＋批次本機測試"
   tip "先不碰模型。FakeDesktop 是用文字代替螢幕的假桌面，沒有任何真實滑鼠鍵盤動作。看 computer_batch 怎麼「依序執行、第一個錯誤就停」：第 3 個動作點到空白處，後面兩個就不會執行。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

BATCH = "computer-use-best-practices/computer_use/tools/batch.py"
out = Path("ch08/interactive")
out.mkdir(parents=True, exist_ok=True)
path = out / "local_batch_test.txt"
path.unlink(missing_ok=True)

class Result:
    def __init__(self, output=None, error=None):
        self.output = output
        self.error = error
    @property
    def is_error(self):
        return self.error is not None

class FakeDesktop:
    """假環境：用文字代替螢幕的表單，沒有任何真實滑鼠鍵盤動作。"""
    RADIUS = 20
    def __init__(self):
        self.elements = [
            {"key": "name", "label": "姓名", "kind": "textbox", "xy": (200, 100)},
            {"key": "email", "label": "Email", "kind": "textbox", "xy": (200, 160)},
            {"key": "agree", "label": "同意條款", "kind": "checkbox", "xy": (60, 220)},
            {"key": "submit", "label": "送出", "kind": "button", "xy": (200, 280)},
        ]
        self.reset()
    def reset(self):
        self.values = {"name": "", "email": "", "agree": False}
        self.focus = None
        self.submitted = False
    def label(self, key):
        for e in self.elements:
            if e["key"] == key:
                return e["label"]
        return "無"
    def screenshot(self):
        lines = ["[假桌面的文字版畫面，不是真的截圖]"]
        for e in self.elements:
            x, y = e["xy"]
            if e["kind"] == "textbox":
                state = "值=" + json.dumps(self.values[e["key"]], ensure_ascii=False)
            elif e["kind"] == "checkbox":
                state = "已勾選=" + ("是" if self.values["agree"] else "否")
            else:
                state = "可按"
            lines.append("- {} {} 座標 ({}, {}) {}".format(e["kind"], e["label"], x, y, state))
        lines.append("焦點：" + self.label(self.focus))
        lines.append("表單：" + ("已送出" if self.submitted else "尚未送出"))
        return Result(output="\n".join(lines))
    def hit(self, x, y):
        for e in self.elements:
            ex, ey = e["xy"]
            if (x - ex) ** 2 + (y - ey) ** 2 <= self.RADIUS ** 2:
                return e
        return None
    def left_click(self, coordinate):
        if not isinstance(coordinate, (list, tuple)) or len(coordinate) != 2:
            return Result(error="left_click requires coordinate = [x, y]")
        try:
            x, y = int(coordinate[0]), int(coordinate[1])
        except (TypeError, ValueError):
            return Result(error="coordinate must be two integers")
        e = self.hit(x, y)
        if e is None:
            return Result(error="no element at ({}, {})".format(x, y))
        if e["kind"] == "textbox":
            self.focus = e["key"]
            return Result(output="clicked {} at ({}, {}); focus={}".format(e["label"], x, y, e["label"]))
        if e["kind"] == "checkbox":
            self.focus = None
            self.values["agree"] = not self.values["agree"]
            return Result(output="clicked {}; checked={}".format(e["label"], self.values["agree"]))
        missing = [lab for key, lab in (("name", "姓名"), ("email", "Email"), ("agree", "同意條款")) if not self.values[key]]
        if missing:
            return Result(error="cannot submit: missing " + ", ".join(missing))
        self.submitted = True
        self.focus = None
        return Result(output="form submitted")
    def type_text(self, text):
        if self.focus not in ("name", "email"):
            return Result(error="no text field focused; click a text field first")
        if not isinstance(text, str) or not text:
            return Result(error="type requires non-empty text")
        self.values[self.focus] += text
        return Result(output="typed {} into {}".format(json.dumps(text, ensure_ascii=False), self.label(self.focus)))
    def execute(self, action=None, coordinate=None, text=None, **extra):
        if action == "screenshot":
            return self.screenshot()
        if action == "left_click":
            return self.left_click(coordinate)
        if action == "type":
            return self.type_text(text)
        return Result(error="unknown action: " + str(action))

def run_batch(desk, actions):
    if not isinstance(actions, list) or not actions:
        return [], "computer_batch requires a non-empty actions array"
    done = []
    for i, step in enumerate(actions):
        name = step.get("action", "?") if isinstance(step, dict) else "?"
        label = "{}:{}".format(i, name)
        try:
            res = desk.execute(**step) if isinstance(step, dict) else Result(error="each action must be an object")
        except Exception as exc:
            res = Result(error="{}: {}".format(type(exc).__name__, exc))
        done.append((label, res))
        if res.is_error:
            remaining = len(actions) - i - 1
            return done, "batch stopped at actions[{}] ({}): {} ({} completed, {} skipped)".format(i, label, res.error, i, remaining)
    return done, None

def render(done, error):
    lines = ["[{}] {}".format(label, r.error if r.is_error else (r.output or "(ok)")) for label, r in done]
    if error:
        lines.append(error)
    return "\n".join(lines) or "(empty batch)"

COMPUTER_SCHEMA = {"type": "object", "properties": {
    "action": {"type": "string", "enum": ["screenshot", "left_click", "type"]},
    "coordinate": {"type": "array", "items": {"type": "integer"}, "minItems": 2, "maxItems": 2, "description": "[x, y]，以最近一張 screenshot 的座標為準"},
    "text": {"type": "string", "description": "type 要輸入的文字"}}, "required": ["action"]}
TOOLS = [
    {"name": "computer", "description": "操作文字模擬的假桌面：screenshot、left_click(coordinate)、type(text)。", "input_schema": COMPUTER_SCHEMA},
    {"name": "computer_batch", "description": "在同一回合依序執行多個 computer 動作。遇到第一個錯誤就停。每一項的形狀和單次 computer 呼叫相同。所有座標都以這個批次之前的那張 screenshot 為準。",
     "input_schema": {"type": "object", "properties": {"actions": {"type": "array", "minItems": 1, "items": COMPUTER_SCHEMA}}, "required": ["actions"]}},
]
print("假環境：FakeDesktop 是幾十行的文字表單物件，不是真的螢幕；這一步不呼叫模型。")
print("自訂工具：", [t["name"] for t in TOOLS], "｜computer_batch 的 actions.items 就是 computer 的 schema（照 batch.py 的 _batch_schema）")
print()
print("對照官方 batch.py：")
for no, line in grep(BATCH, "def _batch_schema|minItems|    def execute|if res.is_error|remaining = len|batch stopped at actions"):
    print("  第 {:>3} 行：{}".format(no, line.strip()[:90]))
print()

desk = FakeDesktop()
print("=== 初始 screenshot ===")
print(desk.screenshot().output)
print()
test = [
    {"action": "left_click", "coordinate": [200, 100]},
    {"action": "type", "text": "Test User"},
    {"action": "left_click", "coordinate": [400, 400]},
    {"action": "left_click", "coordinate": [200, 160]},
    {"action": "type", "text": "test@example.com"},
]
done, err = run_batch(desk, test)
text = render(done, err)
print("=== 本機測試：5 步批次，第 3 步（index 2）點空白處 ===")
print(text)
state = "批次後狀態：姓名 = {}｜Email = {}｜index 3、4 有沒有執行：{}".format(desk.values["name"] or "（空）", desk.values["email"] or "（空）", "有" if desk.values["email"] else "沒有")
print(state)
desk.reset()
print("已重設桌面。")
print()
print("【額外檢查】")
print("  沒焦點就 type →", desk.execute(action="type", text="x").error)
print("  沒填就按送出 →", desk.execute(action="left_click", coordinate=[200, 280]).error)
print("  不存在的動作 →", desk.execute(action="double_click", coordinate=[200, 100]).error)
desk.reset()
good = [
    {"action": "left_click", "coordinate": [200, 100]}, {"action": "type", "text": "Test User"},
    {"action": "left_click", "coordinate": [200, 160]}, {"action": "type", "text": "test@example.com"},
    {"action": "left_click", "coordinate": [60, 220]}, {"action": "left_click", "coordinate": [200, 280]},
    {"action": "screenshot"},
]
done2, err2 = run_batch(desk, good)
print()
print("=== 對照：正確的 7 步批次（最後加 screenshot） ===")
print(render(done2, err2))
print("submitted =", desk.submitted)
desk.reset()
path.write_text("本機測試（5 步批次，第 3 步點空白處）\n" + text + "\n" + state + "\n\n正確的 7 步批次：submitted = True\n", encoding="utf-8")
print()
print("已寫入", path)'
   show "$P"; run "$P" ;;
5) banner "練習 2 之二：模型會收到什麼？什麼時候附 BATCH_REMINDER"
   tip "還不呼叫模型。轉接層把兩個自訂工具寫進系統提示，請模型用 <tool_use> 標記回覆——這是用提示詞模擬的工具呼叫，不是 API 原生 tool use。提醒規則照 loop.py 的 _should_nudge_batch 重寫。"
   P='import json, os, re, sys
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client
from qs_source import grep, read_text

Q = chr(34)
C = "computer-use-best-practices/constants.py"
LOOP = "computer-use-best-practices/computer_use/loop.py"
out = Path("ch08/interactive")
out.mkdir(parents=True, exist_ok=True)
preview = out / "prompt_preview.txt"
preview.unlink(missing_ok=True)

lines = read_text(C).splitlines()
start = grep(C, "^BATCH_REMINDER = ")[0][0]
end = grep(C, "^BATCH_REMINDER_ACTIONS = ")[0][0]
REMINDER = "".join(re.findall(Q + "(.*?)" + Q, "\n".join(lines[start - 1:end - 1])))
stop = end
while lines[stop - 1].strip() != "}":
    stop += 1
ACTIONS = re.findall(Q + "([a-z_]+)" + Q, "\n".join(lines[end:stop]))
print("constants.py 第 {} 行 BATCH_REMINDER：".format(start))
print("  " + REMINDER)
print("constants.py 第 {}～{} 行 BATCH_REMINDER_ACTIONS（{} 個）：{}".format(end, stop, len(ACTIONS), ", ".join(ACTIONS)))
print()
print("官方系統提示裡關於批次的兩句：")
for no, line in grep(C, "Prefer the computer_batch|Include a screenshot call at the end"):
    print("  constants.py 第 {} 行：{}".format(no, line.strip()))
print("官方迴圈怎麼附提醒：")
for no, line in grep(LOOP, "^def _should_nudge_batch|nudge = _should_nudge_batch|if nudge and not res.is_error"):
    print("  loop.py 第 {} 行：{}".format(no, line.strip()))
print()

def should_nudge(uses):
    if len(uses) != 1:
        return False
    tu = uses[0]
    if tu.name not in ("computer", "browser"):
        return False
    action = tu.input.get("action") if isinstance(tu.input, dict) else None
    return action in ACTIONS

def tu(name, inp):
    return SimpleNamespace(type="tool_use", id="toolu_demo", name=name, input=inp)

cases = [
    ("單一 computer left_click", [tu("computer", {"action": "left_click", "coordinate": [200, 100]})]),
    ("單一 computer screenshot", [tu("computer", {"action": "screenshot"})]),
    ("單一 computer_batch", [tu("computer_batch", {"actions": [{"action": "screenshot"}]})]),
    ("兩個 computer（click＋type）", [tu("computer", {"action": "left_click", "coordinate": [200, 100]}), tu("computer", {"action": "type", "text": "Test User"})]),
]
print("【表】_should_nudge_batch 重寫版的判斷")
for label, uses in cases:
    print("  {:<28} → {}".format(label, "附提醒" if should_nudge(uses) else "不附"))
print()

COMPUTER_SCHEMA = {"type": "object", "properties": {
    "action": {"type": "string", "enum": ["screenshot", "left_click", "type"]},
    "coordinate": {"type": "array", "items": {"type": "integer"}, "minItems": 2, "maxItems": 2, "description": "[x, y]，以最近一張 screenshot 的座標為準"},
    "text": {"type": "string", "description": "type 要輸入的文字"}}, "required": ["action"]}
TOOLS = [
    {"name": "computer", "description": "操作文字模擬的假桌面：screenshot、left_click(coordinate)、type(text)。", "input_schema": COMPUTER_SCHEMA},
    {"name": "computer_batch", "description": "在同一回合依序執行多個 computer 動作。遇到第一個錯誤就停。每一項的形狀和單次 computer 呼叫相同。所有座標都以這個批次之前的那張 screenshot 為準。",
     "input_schema": {"type": "object", "properties": {"actions": {"type": "array", "minItems": 1, "items": COMPUTER_SCHEMA}}, "required": ["actions"]}},
]
SYSTEM = "你在操作一個文字模擬的桌面（假桌面，不是真的螢幕），畫面用文字列出元件、座標、目前值與焦點。座標以最近一張 screenshot 為準；批次內所有座標都以批次之前那張 screenshot 為準。能有把握預測兩步以上時就用 computer_batch 一次送出多個動作，這樣更快也更省；可能改變畫面的批次，最後要加一個 screenshot 動作來驗證。不要假裝做了沒做的動作。用繁體中文回報。"
SHOT = "\n".join([
    "[假桌面的文字版畫面，不是真的截圖]",
    "- textbox 姓名 座標 (200, 100) 值=" + Q + Q,
    "- textbox Email 座標 (200, 160) 值=" + Q + Q,
    "- checkbox 同意條款 座標 (60, 220) 已勾選=否",
    "- button 送出 座標 (200, 280) 可按",
    "焦點：無",
    "表單：尚未送出",
])
TASK = "目前畫面（screenshot 的結果）：\n" + SHOT + "\n\n任務：填姓名 Test User、Email test@example.com、勾選同意、按送出。"
client_tools, ignored = claude_cli_client.split_tools(TOOLS)
sys_text = claude_cli_client.system_text(SYSTEM, client_tools)
first_stdin = claude_cli_client.flatten_messages([{"role": "user", "content": TASK}])
print("可模擬的自訂工具：", [t["name"] for t in client_tools], "｜忽略：", ignored)
print()
print("=== 轉接層送給 claude -p 的系統提示 ===")
print(sys_text)
print()
print("=== 第 1 次呼叫送進 stdin 的內容 ===")
print(first_stdin)
print()
demo = [
    {"role": "user", "content": TASK},
    {"role": "assistant", "content": [tu("computer", {"action": "left_click", "coordinate": [200, 100]})]},
    {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "toolu_demo", "content": [{"type": "text", "text": "clicked 姓名 at (200, 100); focus=姓名"}, {"type": "text", "text": REMINDER}]}]},
]
print("=== 示意：模型只送單一 left_click 時，第 2 次呼叫的 stdin（提醒附在 tool_result 裡，不是改系統提示） ===")
print(claude_cli_client.flatten_messages(demo))
print()
names = {t["name"] for t in client_tools}
batch_tag = "<tool_use>" + json.dumps({"name": "computer_batch", "input": {"actions": [{"action": "left_click", "coordinate": [200, 100]}, {"action": "type", "text": "Test User"}, {"action": "screenshot"}]}}) + "</tool_use>"
replies = [
    ("照格式（批次）", "我一次送出三個動作。" + batch_tag),
    ("沒照格式", "我已經把表單填好並送出了。"),
    ("工具不在清單", batch_tag.replace("computer_batch", "mouse")),
]
print("【parse_reply 怎麼解析模型回覆】")
for label, text in replies:
    blocks = claude_cli_client.parse_reply(text, names)
    calls = [(b.name, len(b.input.get("actions", []))) for b in blocks if b.type == "tool_use"]
    print("  {:<12} → block 種類 {}；tool_use {}".format(label, [b.type for b in blocks], calls if calls else "無（第 6 步會當成沒呼叫工具）"))
preview.write_text("=== system ===\n" + sys_text + "\n\n=== 第 1 次 stdin ===\n" + first_stdin + "\n", encoding="utf-8")
print()
print("已寫入", preview)'
   show "$P"; run "$P" ;;
6) banner "練習 2 之三：真模型＋假桌面，用 computer_batch 填表"
   tip "這一步會呼叫模型最多 2 次（claude -p，每次約 5～15 秒，最多等 180 秒）。模型是真的，桌面是假的（文字表單），工具呼叫是用提示詞模擬的。每次結果可能不同，照實記錄；模型沒照格式或呼叫失敗也會照樣存檔、正常結束。"
   P='import json, os, re, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
os.environ["K902_CLI_MAX_CALLS"] = "2"
import claude_cli_client
from qs_source import grep, read_text

Q = chr(34)
MAX_CALLS = 2
C = "computer-use-best-practices/constants.py"
out = Path("ch08/interactive")
out.mkdir(parents=True, exist_ok=True)
md_path = out / "batch_report.md"
json_path = out / "batch_log.json"
md_path.unlink(missing_ok=True)
json_path.unlink(missing_ok=True)

lines = read_text(C).splitlines()
start = grep(C, "^BATCH_REMINDER = ")[0][0]
end = grep(C, "^BATCH_REMINDER_ACTIONS = ")[0][0]
REMINDER = "".join(re.findall(Q + "(.*?)" + Q, "\n".join(lines[start - 1:end - 1])))
stop = end
while lines[stop - 1].strip() != "}":
    stop += 1
ACTIONS = re.findall(Q + "([a-z_]+)" + Q, "\n".join(lines[end:stop]))

class Result:
    def __init__(self, output=None, error=None):
        self.output = output
        self.error = error
    @property
    def is_error(self):
        return self.error is not None

class FakeDesktop:
    """假環境：用文字代替螢幕的表單，沒有任何真實滑鼠鍵盤動作。"""
    RADIUS = 20
    def __init__(self):
        self.elements = [
            {"key": "name", "label": "姓名", "kind": "textbox", "xy": (200, 100)},
            {"key": "email", "label": "Email", "kind": "textbox", "xy": (200, 160)},
            {"key": "agree", "label": "同意條款", "kind": "checkbox", "xy": (60, 220)},
            {"key": "submit", "label": "送出", "kind": "button", "xy": (200, 280)},
        ]
        self.reset()
    def reset(self):
        self.values = {"name": "", "email": "", "agree": False}
        self.focus = None
        self.submitted = False
    def label(self, key):
        for e in self.elements:
            if e["key"] == key:
                return e["label"]
        return "無"
    def screenshot(self):
        lines = ["[假桌面的文字版畫面，不是真的截圖]"]
        for e in self.elements:
            x, y = e["xy"]
            if e["kind"] == "textbox":
                state = "值=" + json.dumps(self.values[e["key"]], ensure_ascii=False)
            elif e["kind"] == "checkbox":
                state = "已勾選=" + ("是" if self.values["agree"] else "否")
            else:
                state = "可按"
            lines.append("- {} {} 座標 ({}, {}) {}".format(e["kind"], e["label"], x, y, state))
        lines.append("焦點：" + self.label(self.focus))
        lines.append("表單：" + ("已送出" if self.submitted else "尚未送出"))
        return Result(output="\n".join(lines))
    def hit(self, x, y):
        for e in self.elements:
            ex, ey = e["xy"]
            if (x - ex) ** 2 + (y - ey) ** 2 <= self.RADIUS ** 2:
                return e
        return None
    def left_click(self, coordinate):
        if not isinstance(coordinate, (list, tuple)) or len(coordinate) != 2:
            return Result(error="left_click requires coordinate = [x, y]")
        try:
            x, y = int(coordinate[0]), int(coordinate[1])
        except (TypeError, ValueError):
            return Result(error="coordinate must be two integers")
        e = self.hit(x, y)
        if e is None:
            return Result(error="no element at ({}, {})".format(x, y))
        if e["kind"] == "textbox":
            self.focus = e["key"]
            return Result(output="clicked {} at ({}, {}); focus={}".format(e["label"], x, y, e["label"]))
        if e["kind"] == "checkbox":
            self.focus = None
            self.values["agree"] = not self.values["agree"]
            return Result(output="clicked {}; checked={}".format(e["label"], self.values["agree"]))
        missing = [lab for key, lab in (("name", "姓名"), ("email", "Email"), ("agree", "同意條款")) if not self.values[key]]
        if missing:
            return Result(error="cannot submit: missing " + ", ".join(missing))
        self.submitted = True
        self.focus = None
        return Result(output="form submitted")
    def type_text(self, text):
        if self.focus not in ("name", "email"):
            return Result(error="no text field focused; click a text field first")
        if not isinstance(text, str) or not text:
            return Result(error="type requires non-empty text")
        self.values[self.focus] += text
        return Result(output="typed {} into {}".format(json.dumps(text, ensure_ascii=False), self.label(self.focus)))
    def execute(self, action=None, coordinate=None, text=None, **extra):
        if action == "screenshot":
            return self.screenshot()
        if action == "left_click":
            return self.left_click(coordinate)
        if action == "type":
            return self.type_text(text)
        return Result(error="unknown action: " + str(action))

def run_batch(desk, actions):
    if not isinstance(actions, list) or not actions:
        return [], "computer_batch requires a non-empty actions array"
    done = []
    for i, step in enumerate(actions):
        name = step.get("action", "?") if isinstance(step, dict) else "?"
        label = "{}:{}".format(i, name)
        try:
            res = desk.execute(**step) if isinstance(step, dict) else Result(error="each action must be an object")
        except Exception as exc:
            res = Result(error="{}: {}".format(type(exc).__name__, exc))
        done.append((label, res))
        if res.is_error:
            remaining = len(actions) - i - 1
            return done, "batch stopped at actions[{}] ({}): {} ({} completed, {} skipped)".format(i, label, res.error, i, remaining)
    return done, None

def render(done, error):
    lines = ["[{}] {}".format(label, r.error if r.is_error else (r.output or "(ok)")) for label, r in done]
    if error:
        lines.append(error)
    return "\n".join(lines) or "(empty batch)"

def should_nudge(uses):
    if len(uses) != 1:
        return False
    tu = uses[0]
    if tu.name not in ("computer", "browser"):
        return False
    action = tu.input.get("action") if isinstance(tu.input, dict) else None
    return action in ACTIONS

COMPUTER_SCHEMA = {"type": "object", "properties": {
    "action": {"type": "string", "enum": ["screenshot", "left_click", "type"]},
    "coordinate": {"type": "array", "items": {"type": "integer"}, "minItems": 2, "maxItems": 2, "description": "[x, y]，以最近一張 screenshot 的座標為準"},
    "text": {"type": "string", "description": "type 要輸入的文字"}}, "required": ["action"]}
TOOLS = [
    {"name": "computer", "description": "操作文字模擬的假桌面：screenshot、left_click(coordinate)、type(text)。", "input_schema": COMPUTER_SCHEMA},
    {"name": "computer_batch", "description": "在同一回合依序執行多個 computer 動作。遇到第一個錯誤就停。每一項的形狀和單次 computer 呼叫相同。所有座標都以這個批次之前的那張 screenshot 為準。",
     "input_schema": {"type": "object", "properties": {"actions": {"type": "array", "minItems": 1, "items": COMPUTER_SCHEMA}}, "required": ["actions"]}},
]
SYSTEM = "你在操作一個文字模擬的桌面（假桌面，不是真的螢幕），畫面用文字列出元件、座標、目前值與焦點。座標以最近一張 screenshot 為準；批次內所有座標都以批次之前那張 screenshot 為準。能有把握預測兩步以上時就用 computer_batch 一次送出多個動作，這樣更快也更省；可能改變畫面的批次，最後要加一個 screenshot 動作來驗證。不要假裝做了沒做的動作。用繁體中文回報。"

desk = FakeDesktop()
TASK = "目前畫面（screenshot 的結果）：\n" + desk.screenshot().output + "\n\n任務：填姓名 Test User、Email test@example.com、勾選同意、按送出。"
log = {"calls": [], "first_tool": None, "n_actions": 0, "batch_done": 0, "ends_with_screenshot": False, "nudged": False,
       "retried": False, "error": None, "tool_results": [], "final_text": "", "submitted": False, "calls_made": 0, "stepwise_calls": None}
print("假環境：FakeDesktop 是文字表單物件，沒有任何真實滑鼠鍵盤動作；模型是真的（claude -p）；工具呼叫用提示詞模擬，不是 API 原生 tool use。")
print()

def execute_uses(uses):
    nudge = should_nudge(uses)
    blocks = []
    for u in uses:
        inp = u.input if isinstance(u.input, dict) else {}
        if u.name == "computer_batch":
            acts = inp.get("actions")
            done, err = run_batch(desk, acts)
            text, is_err = render(done, err), err is not None
            n = len(acts) if isinstance(acts, list) else 0
            log["batch_done"] += len(done)
            last = acts[-1].get("action") if isinstance(acts, list) and acts and isinstance(acts[-1], dict) else None
        elif u.name == "computer":
            try:
                r = desk.execute(**inp)
            except Exception as exc:
                r = Result(error="{}: {}".format(type(exc).__name__, exc))
            text, is_err, n, last = (r.error if r.is_error else (r.output or "(ok)")), r.is_error, 1, inp.get("action")
        else:
            text, is_err, n, last = "unknown tool: " + str(u.name), True, 0, None
        log["n_actions"] += n
        log["ends_with_screenshot"] = last == "screenshot"
        content = [{"type": "text", "text": text}]
        if nudge and not is_err:
            content.append({"type": "text", "text": REMINDER})
            log["nudged"] = True
        block = {"type": "tool_result", "tool_use_id": u.id, "content": content}
        if is_err:
            block["is_error"] = True
        blocks.append(block)
        log["tool_results"].append({"tool": u.name, "input": inp, "result": text, "is_error": is_err})
        print("  執行 {}（{} 個動作）→ is_error = {}".format(u.name, n, is_err))
        for row in text.splitlines():
            print("    " + row)
        if nudge and not is_err:
            print("  單一動作：已在 tool_result 後附上 BATCH_REMINDER")
    return blocks

client = claude_cli_client.Anthropic()
messages = [{"role": "user", "content": TASK}]
executed = False
print("=== 工具迴圈（最多 {} 次 claude -p，每次約 5～15 秒） ===".format(MAX_CALLS))
while claude_cli_client.calls_made() < MAX_CALLS:
    try:
        reply = client.messages.create(model="claude-sonnet-5-5", max_tokens=1024, system=SYSTEM, messages=messages, tools=TOOLS)
    except (claude_cli_client.APIError, RuntimeError, ValueError) as exc:
        log["error"] = type(exc).__name__ + "：" + str(exc)
        print("這次呼叫失敗，原因：" + log["error"] + "（照樣把已有的紀錄存檔，結束碼 0）")
        break
    n = claude_cli_client.calls_made()
    texts = [str(b.text) for b in reply.content if b.type == "text"]
    uses = [b for b in reply.content if b.type == "tool_use"]
    log["calls"].append({"call": n, "stop_reason": reply.stop_reason, "tool_uses": [[u.name, u.input] for u in uses], "text": "\n".join(texts)})
    print("第 {} 次呼叫：stop_reason = {}｜tool_use = {}".format(n, reply.stop_reason, [u.name for u in uses] if uses else "無"))
    if texts:
        print("  模型文字：" + " ".join(texts).replace("\n", " ")[:200])
    if executed:
        log["final_text"] = "\n".join(texts)
        if uses:
            print("  第 2 次回覆又要求工具；已達 2 次上限，不再執行。")
        break
    if not uses:
        log["final_text"] = "\n".join(texts)
        print("  這次模型沒有照格式呼叫工具（回覆裡沒有 tool_use），這是提示詞模擬工具呼叫的限制。")
        if n < MAX_CALLS and not log["retried"]:
            log["retried"] = True
            print("  在上限內重試 1 次，提醒它用 <tool_use> 標記。")
            messages = [{"role": "user", "content": TASK + "\n\n提醒：請實際用 <tool_use> 標記呼叫 computer_batch 或 computer，不要只用文字描述。"}]
            continue
        print("  照實記錄拿到的文字，不再呼叫。")
        break
    log["first_tool"] = uses[0].name
    results = execute_uses(uses)
    executed = True
    messages = messages + [{"role": "assistant", "content": reply.content}, {"role": "user", "content": results}]
    if claude_cli_client.calls_made() >= MAX_CALLS:
        print("  已用完 2 次呼叫上限：工具已執行並記錄，但不再送回模型拿最後回報。")

log["submitted"] = desk.submitted
log["calls_made"] = claude_cli_client.calls_made()
log["stepwise_calls"] = log["n_actions"] + 1 if log["n_actions"] else None
print()
print("=== 最後的假桌面畫面 ===")
print(desk.screenshot().output)
print()
rows = [
    ("第一個執行的工具", log["first_tool"] or "（沒有）"),
    ("動作數（批次項目或單一動作合計）", log["n_actions"]),
    ("批次實際執行到第幾個", log["batch_done"]),
    ("最後一個動作是 screenshot", log["ends_with_screenshot"]),
    ("表單是否送出成功", log["submitted"]),
    ("calls_made()", log["calls_made"]),
    ("逐步做法需要幾次呼叫（動作數＋1）", log["stepwise_calls"] if log["stepwise_calls"] else "-"),
    ("相差幾次", (log["stepwise_calls"] - log["calls_made"]) if log["stepwise_calls"] else "-"),
    ("附了 BATCH_REMINDER", log["nudged"]),
    ("重試過", log["retried"]),
    ("錯誤", log["error"] or "無"),
]
for k, v in rows:
    print("  {:<34} {}".format(k, v))
if log["final_text"]:
    print("  模型最後的文字：", log["final_text"].replace("\n", " ")[:300])
md = ["# 第 8 章練習 2：假桌面上的批次工具", "",
      "- 假環境：FakeDesktop（文字表單，沒有真實滑鼠鍵盤）；模型是真的（claude -p）。",
      "- 這是提示詞模擬的工具呼叫，不是 API 原生 tool use。", "", "| 項目 | 值 |", "| --- | --- |"]
md += ["| {} | {} |".format(k, str(v).replace("|", "／")) for k, v in rows]
md += ["", "## 工具結果", ""]
for r in log["tool_results"]:
    md += ["### " + r["tool"], "", "~~~text", r["result"], "~~~", ""]
md += ["模型最後的文字：" + (log["final_text"].replace("\n", " ") if log["final_text"] else "（無）")]
md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
json_path.write_text(json.dumps(log, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
print()
print("已寫入", md_path, "與", json_path)'
   show "$P"; run "$P" ;;
7) banner "練習 2 之四：檢查觀察重點，對回官方批次、提醒與快取斷點"
   tip "不再呼叫模型。把第 4、6 步的結果對到三個觀察重點；找不到第 4、6 步的檔案時改用內建範例。再對照原始碼：快取斷點以 loop.py 為準（系統提示 1 個＋訊息本體最多 3 個），README 只寫了「另一個」。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

P = "computer-use-best-practices/"
out = Path("ch08/interactive")
out.mkdir(parents=True, exist_ok=True)
review = out / "batch_review.md"
review.unlink(missing_ok=True)

LOCAL_SAMPLE = "batch stopped at actions[2] (2:left_click): no element at (400, 400) (2 completed, 2 skipped)"
local, lsrc = LOCAL_SAMPLE, "內建範例（找不到第 4 步的 local_batch_test.txt）"
lp = out / "local_batch_test.txt"
if lp.exists():
    local, lsrc = lp.read_text(encoding="utf-8"), "ch08/interactive/local_batch_test.txt（第 4 步）"
SAMPLE = {"first_tool": "computer_batch", "n_actions": 7, "batch_done": 7, "ends_with_screenshot": True, "submitted": True,
          "calls_made": 2, "stepwise_calls": 8, "nudged": False, "retried": False, "error": None}
data, src = SAMPLE, "內建範例（找不到第 6 步的 batch_log.json；照常見結果編的）"
bp = out / "batch_log.json"
if bp.exists():
    try:
        loaded = json.loads(bp.read_text(encoding="utf-8"))
        if isinstance(loaded, dict) and "n_actions" in loaded:
            data, src = loaded, "ch08/interactive/batch_log.json（第 6 步的真模型紀錄）"
    except ValueError:
        pass
print("本機測試來源：", lsrc)
print("模型紀錄來源：", src)
print()

q1 = "(2 completed, 2 skipped)" in local and "[3:" not in local
calls = data.get("calls_made") or 0
steps = data.get("stepwise_calls")
q2 = data.get("first_tool") == "computer_batch" and (data.get("n_actions") or 0) >= 6 and bool(data.get("ends_with_screenshot"))
single = data.get("first_tool") == "computer"
print("【觀察重點】")
print("  1. 本機測試在第 3 步失敗後停止（2 completed, 2 skipped），後面沒執行：", "是" if q1 else "否")
print("  2. 模型一次用 computer_batch 送出 6 個以上動作並以 screenshot 結尾：", "是" if q2 else "否（照實記錄：工具 {}、動作 {}、結尾 screenshot {}）".format(data.get("first_tool"), data.get("n_actions"), data.get("ends_with_screenshot")))
if steps:
    print("     呼叫次數：實際 {} 次 vs 逐步 {} 次（動作數＋1），差 {} 次".format(calls, steps, steps - calls))
else:
    print("     呼叫次數：實際 {} 次；沒有執行到任何動作，無法比較".format(calls))
print("  3. 單一動作時附提醒：", ("有附" if data.get("nudged") else "沒附（請查）") if single else "這次不是單一 computer 動作，不需要提醒")
print("  表單送出：", data.get("submitted"), "｜重試過：", data.get("retried"), "｜錯誤：", data.get("error") or "無")
print()

checks = [
    ("批次工具說明：遇第一個錯誤就停", "computer_use/tools/batch.py", "Stops on the first error"),
    ("出錯時批次裡的圖片換成提示文字", "computer_use/tools/batch.py", "IMAGE_OMITTED_ON_ERROR[}]"),
    ("模型座標要乘比例換回螢幕", "computer_use/tools/computer.py", "def _scale_to_screen"),
    ("系統提示 1 個快取斷點", "computer_use/loop.py", "system_prompt, .cache_control"),
    ("訊息本體最多 3 個斷點", "computer_use/loop.py", "^_MAX_BODY_CACHE_BREAKPOINTS = "),
    ("README 的說法：只多一個斷點", "README.md", "another on the final tool-result block"),
    ("README：每張截圖約 1,500 token", "README.md", "roughly 1,500 input tokens"),
    ("compaction 觸發門檻", "constants.py", "^    autocompaction_trigger_tokens: "),
]
print("【對回官方原始碼】")
table = []
for what, rel, pat in checks:
    hits = grep(P + rel, pat)
    where = rel.split("/")[-1] + ":" + (str(hits[0][0]) if hits else "-")
    text = hits[0][1].strip()[:80] if hits else "找不到"
    table.append((what, where, text))
    print("  {:<30} | {:<18} | {}".format(what, where, text))
print()
print("→ 快取斷點以程式為準：系統提示 1 個＋訊息本體最多 3 個＝最多 4 個；README 只寫了「另一個」。")
print("→ 假桌面省略了：真的截圖（圖片）、送出尺寸與螢幕的座標換算、出錯時圖片換成提示文字；這裡畫面是文字、座標就是螢幕座標。")
md = ["# 第 8 章練習 2：檢查與對照", "", "- 本機測試來源：" + lsrc, "- 模型紀錄來源：" + src,
      "- 遇錯即停（2 completed, 2 skipped）：" + str(q1),
      "- computer_batch 6 個以上動作且以 screenshot 結尾：" + str(q2),
      "- 呼叫次數：實際 {}；逐步 {}".format(calls, steps if steps else "-"),
      "- 附了 BATCH_REMINDER：" + str(data.get("nudged")), "",
      "| 對照項目 | 位置 | 原文 |", "| --- | --- | --- |"]
md += ["| {} | {} | {} |".format(a, b, c.replace("|", "／")) for a, b, c in table]
review.write_text("\n".join(md) + "\n", encoding="utf-8")
print()
print("已寫入", review)'
   show "$P"; run "$P" ;;
8) banner "總結：本章 6 個重點與產出檔案"
   tip "截圖尺寸、裁圖與快取、快取斷點、批次工具、安全邊界，加上「演練裡哪些是假的」：本章每個結論都對得回原始碼的某一行。"
   P='import json
from pathlib import Path

points = [
    "截圖要自己先縮：API 把圖切成 28x28 格子，長邊上限 1568 px、格子上限 1568；2880x1800 送出 1389x868（1550 格，比例 2.073），1920x1080 與 3840x2160 都送 1456x819（1560 格）。browser_viewport 預設 (1456, 819) 就是為了剛好不必縮。",
    "兩個座標系要分清楚：模型回傳的是「送出那張圖」的像素，_scale_to_screen 乘上比例才是螢幕座標；伺服器若再縮一次，座標就落在你沒看過的圖上（image.py 檔頭：16:10 的 MacBook 約 14% 漂移）。",
    "裁舊截圖是「刪圖不刪字」，換成 [Image Omitted]。60 回合裡 simple（留最後 10 張）前綴改變 50 次，interval（min=3、interval=40）只改 1 次，interval=5 改 12 次：同一批舊圖固定被換掉，prompt cache 才能持續命中。",
    "快取斷點以程式為準：系統提示 1 個＋訊息本體最多 3 個（_MAX_BODY_CACHE_BREAKPOINTS），README 只寫了另一個；第三層是伺服器端 compaction，輸入超過 150,000 token 才整段摘要。",
    "computer_batch 把可預測的連續動作併成一回合：依序執行、第一個錯誤就停並寫出「i completed, n skipped」；批次內座標以批次前的截圖為準，所以最後加 screenshot。模型只送單一點擊／輸入時，loop.py 在工具結果後附 BATCH_REMINDER，不是改系統提示。",
    "安全靠外圍：明確 schema 不會觸發 computer use 專屬安全分類器；bash／python 包在 sandbox-exec（只能寫 scratch、禁網路、30 秒逾時），README 仍要求在用完即丟的虛擬機裡跑。本章演練是真模型＋假桌面（文字表單），工具呼叫用提示詞模擬，不是 API 原生 tool use。",
]
print("第 8 章重點：")
for i, p in enumerate(points, 1):
    print("  {}. {}".format(i, p))
print()
note = "第 6 步沒有留下紀錄"
lp = Path("ch08/interactive/batch_log.json")
if lp.exists():
    try:
        rec = json.loads(lp.read_text(encoding="utf-8"))
        note = "第 6 步呼叫模型 {} 次、第一個工具 {}、動作 {} 個、表單送出 {}".format(rec.get("calls_made"), rec.get("first_tool"), rec.get("n_actions"), rec.get("submitted"))
    except ValueError:
        note = "batch_log.json 讀不懂"
print("本章模型呼叫：", note, "（本章只有第 6 步呼叫，最多 2 次；規則上限整章 4 次）")
print()
print("本章產出檔案：")
for name in ("sizing_report.md", "local_batch_test.txt", "prompt_preview.txt", "batch_report.md", "batch_log.json", "batch_review.md"):
    p = Path("ch08/interactive") / name
    print("  {} {}".format("OK" if p.exists() else "缺", p))'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
