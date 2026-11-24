#!/bin/bash
# K902 第 6 章互動演練：computer-toolset——用 VNC 寫一個最小的電腦操作工具組驅動程式，導讀＋小模擬，一次跑一步
# 用法：bash ch06.sh <步驟 1-8>
# 呼叫模型：只有第 6 步會呼叫模型，最多 2 次（第 1 次沒有 tool_use 時用第 2 次重試 1 次；claude -p，透過 claude_cli_client），其餘步驟全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch06/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K902 第 6 章｜電腦操作工具組 computer-toolset　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "主角登場：computer-toolset 檔案表＋「誰負責什麼」分工表"
   tip "這章是導讀＋小模擬：原始做法要 VNC 桌面、新版 SDK 的 tool runner 和 API 金鑰，這裡不能實跑，也不 import 官方模組。先用 qs_source 把原始碼當文字讀，看清楚 run.py、SDK、VncComputer 驅動程式三層各管什麼。"
   P='import os, sys
sys.path.insert(0, os.getcwd())
from qs_source import root, read_text, grep

Q = chr(34)
B = "computer-toolset/"
print("官方 repo 資料夾：", root().name, "（只讀；不安裝依賴、不執行啟動指令、不需要 VNC 桌面與金鑰）")
print()
files = [
    ("python/vnc_computer.py", "範例驅動程式 VncComputer：RFB 握手、KEYSYMS、滑鼠鍵盤事件、截圖、十個工具"),
    ("python/run.py", "入口：建立驅動程式與確認函式 ask，交給 tool runner，逐則印出模型訊息"),
    ("python/exercise.py", "不用模型的冒煙檢查：手寫 tool_use 直接送進 tool_result()"),
    ("python/requirements.txt", "Python 依賴（本教材不安裝）"),
    ("typescript/vnc-computer.ts", "同一套做法的 TypeScript 版驅動程式"),
    ("README.md", "安裝、VNC 伺服器指令、執行、實作了什麼與沒做什麼"),
]
print("【表 1】關鍵檔案")
print("{:<28} | {:>4} | {}".format("檔案", "行數", "負責什麼"))
print("-" * 110)
for rel, desc in files:
    print("{:<28} | {:>4} | {}".format(rel, len(read_text(B + rel).splitlines()), desc))
print()

flow = [
    ("run.py", "預設任務（整個命令列就是任務）", "python/run.py", "task = "),
    ("run.py", "預設模型", "python/run.py", "claude-sonnet-5-5"),
    ("run.py", "max_tokens", "python/run.py", "max_tokens=4096"),
    ("SDK", "tool runner 自動跑截圖→動作迴圈", "python/run.py", "tool_runner[(]"),
    ("SDK", "tools 裡只放一個工具組物件", "python/run.py", "tools=[[]computer[]]"),
    ("run.py", "confirm 選項接上確認函式 ask", "python/run.py", "confirm=ask"),
    ("run.py", "截圖免問", "python/run.py", "member == "),
    ("run.py", "其他動作印出呼叫並問 y/N", "python/run.py", "y/N[]]"),
    ("SDK 抽象類別", "驅動程式繼承它", "python/vnc_computer.py", "^class VncComputer"),
    ("驅動程式", "伺服器不回應時 10 秒逾時", "python/vnc_computer.py", "timeout=10"),
    ("驅動程式", "VNC 問不到游標，自己記 _cursor", "python/vnc_computer.py", "self._cursor = [(]0, 0[)]"),
    ("驅動程式", "拒絕超過 1920x1200 的螢幕", "python/vnc_computer.py", "MAX_WIDTH or"),
    ("驅動程式", "截圖前固定睡 0.5 秒", "python/vnc_computer.py", "time[.]sleep[(]0[.]5[)]"),
    ("exercise.py", "confirm 一律放行", "python/exercise.py", "confirm=lambda"),
    ("exercise.py", "不經模型，直接呼叫 tool_result", "python/exercise.py", "computer[.]tool_result[(]tool_use[)]"),
]
print("【表 2】誰負責什麼（行號從原始碼 grep 出來）")
print("{:<12} | {:<32} | {:<20} | {}".format("誰", "做什麼", "檔案:行號", "原文"))
print("-" * 150)
for who, what, rel, pat in flow:
    hits = grep(B + rel, pat)
    name = rel.split("/")[-1]
    where = name + ":" + (str(hits[0][0]) if hits else "-")
    text = hits[0][1].strip()[:90] if hits else "找不到"
    print("{:<12} | {:<32} | {:<20} | {}".format(who, what, where, text))
print()

print("【計數】工具組型別字串與 SDK 類別名稱出現次數")
print("  {:<24} | {:>25} | {}".format("檔案", "computer_toolset_20260801", "BetaAbstractComputerToolset20260801"))
for rel in ("README.md", "python/vnc_computer.py", "python/run.py", "python/exercise.py"):
    a = sum(l.count("computer_toolset_20260801") for _, l in grep(B + rel, "computer_toolset_20260801"))
    b = sum(l.count("BetaAbstractComputerToolset20260801") for _, l in grep(B + rel, "BetaAbstractComputerToolset20260801"))
    print("  {:<24} | {:>25} | {}".format(rel, a, b))
print()
print("→ 工具 schema、拒絕沒實作的工具、呼叫 confirm、工具迴圈都在 SDK；這個資料夾只看得到驅動程式那一半。")
print("→ 模型靠截圖看桌面，座標是它自己從圖上估的；驅動程式只負責把動作翻成 RFB 訊息。")'
   show "$P"; run "$P" ;;
2) banner "練習 1 之一：11 個 @override 各走哪個內部函式、變成哪種 RFB 訊息"
   tip "不執行官方程式，只把 vnc_computer.py 當純文字分析。十個工具最後只落在三種訊息：截圖請求、鍵盤事件、滑鼠事件；點擊、雙擊、三擊、捲動都共用 _click。"
   P='import os, re, sys
sys.path.insert(0, os.getcwd())
from qs_source import read_text, grep

Q = chr(34)
VNC = "computer-toolset/python/vnc_computer.py"
lines = read_text(VNC).splitlines()
DEF = re.compile("    def ([A-Za-z_]+)[(]")
PACK = re.compile("struct[.]pack[(]" + Q + "([^" + Q + "]+)" + Q + ", ([0-9]+)")
HELP = re.compile("self[.](_click|_move|_keys)[(]")
NAMES = {0: "SetPixelFormat", 2: "SetEncodings", 3: "FramebufferUpdateRequest", 4: "KeyEvent", 5: "PointerEvent"}

def methods():
    out = []
    for j, line in enumerate(lines):
        m = DEF.match(line)
        if not m:
            continue
        k = j + 1
        while k < len(lines):
            nxt = lines[k]
            if nxt.startswith("    @") or nxt.startswith("    def ") or (nxt and not nxt.startswith(" ")):
                break
            k += 1
        deco = j if j > 0 and lines[j - 1].strip() == "@override" else None
        out.append({"name": m.group(1), "def": j + 1, "override": deco, "body": "\n".join(lines[j + 1:k])})
    return out

ms = methods()
by = {m["name"]: m for m in ms}

def msg_types(name, seen):
    if name in seen or name not in by:
        return []
    seen.add(name)
    body = by[name]["body"]
    found = [int(t) for _, t in PACK.findall(body)]
    for h in HELP.findall(body):
        for t in msg_types(h, seen):
            if t not in found:
                found.append(t)
    return found

def label(types_):
    return "＋".join("{}({})".format(NAMES.get(t, "?"), t) for t in types_)

def helpers(body):
    seen = []
    for h in HELP.findall(body):
        if h not in seen:
            seen.append(h)
    if seen:
        return ", ".join(seen)
    return "直接 sendall" if "sendall" in body else "-"

def click_args(body):
    for line in body.splitlines():
        if "self._click(" in line:
            inner = line.split("self._click(", 1)[1].rsplit(")", 1)[0]
            return inner.replace("input.coordinate, input.text, ", "")
    return "-"

def no_msg(body):
    if "time.sleep(input.duration)" in body:
        return "不送 RFB 訊息（只 time.sleep）"
    if "close()" in body:
        return "不送 RFB 訊息（關閉連線）"
    return "不送 RFB 訊息"

ov = [m for m in ms if m["override"]]
print("vnc_computer.py 共", len(lines), "行；grep 到", len(grep(VNC, "^    @override")), "行 @override，對應方法", len(ov), "個（十個工具＋close）")
print()
print("【表一】工具 → 內部函式 → RFB 訊息")
print("{:<13} | {:<9} | {:<12} | {:<54} | {}".format("工具", "@行/def行", "內部函式", "_click 的按鍵與次數", "最後變成哪種 RFB 訊息"))
print("-" * 150)
for m in ov:
    t = msg_types(m["name"], set())
    print("{:<13} | {:<9} | {:<12} | {:<54} | {}".format(m["name"], "{}/{}".format(m["override"], m["def"]), helpers(m["body"]), click_args(m["body"]), label(t) if t else no_msg(m["body"])))
print()
print("【內部函式】")
for name in ("_handshake", "_move", "_keys", "_click"):
    m = by[name]
    print("  {:<11} 第 {:>3} 行 | 呼叫：{:<12} | 送出：{}".format(name, m["def"], helpers(m["body"]), label(msg_types(name, set()))))
print()
print("【一次動作送幾個 PointerEvent】_click 先 _move 一次，每次點擊再送「帶遮罩、不帶遮罩」兩次")
for tool, times in (("left_click", 1), ("double_click", 2), ("triple_click", 3), ("scroll 3 格", 3)):
    print("  {:<12} times={} → 1 + 2×{} = {} 個 PointerEvent（沒有修飾鍵時不送 KeyEvent）".format(tool, times, times, 1 + 2 * times))
print("  type " + Q + "date" + Q + "＋換行：5 個字 × 按下放開 2 個 = 10 個 KeyEvent（換行查表變成 Return）")'
   show "$P"; run "$P" ;;
3) banner "練習 1 之二：5 處 struct.pack、常數、KEYSYMS 與 4 MB 驗算"
   tip "把全檔的 struct.pack 收斂成剛好五種 RFB 用戶端訊息並算出位元組數，再驗算 README 說的 about 4 MB。成果存成 ch06/interactive/rfb_map.md。"
   P='import ast, os, re, struct, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import read_text, grep

Q = chr(34)
VNC = "computer-toolset/python/vnc_computer.py"
README = "computer-toolset/README.md"
lines = read_text(VNC).splitlines()
DEF = re.compile("    def ([A-Za-z_]+)[(]")
PACK = re.compile("struct[.]pack[(]" + Q + "([^" + Q + "]+)" + Q + ", ([0-9]+)")
HELP = re.compile("self[.](_click|_move|_keys)[(]")
NAMES = {0: "SetPixelFormat", 2: "SetEncodings", 3: "FramebufferUpdateRequest", 4: "KeyEvent", 5: "PointerEvent"}
out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
map_path = out / "rfb_map.md"
map_path.unlink(missing_ok=True)

def methods():
    res = []
    for j, line in enumerate(lines):
        m = DEF.match(line)
        if not m:
            continue
        k = j + 1
        while k < len(lines):
            nxt = lines[k]
            if nxt.startswith("    @") or nxt.startswith("    def ") or (nxt and not nxt.startswith(" ")):
                break
            k += 1
        deco = j if j > 0 and lines[j - 1].strip() == "@override" else None
        res.append({"name": m.group(1), "def": j + 1, "override": deco, "body": "\n".join(lines[j + 1:k])})
    return res

ms = methods()
by = {m["name"]: m for m in ms}

def msg_types(name, seen):
    if name in seen or name not in by:
        return []
    seen.add(name)
    body = by[name]["body"]
    found = [int(t) for _, t in PACK.findall(body)]
    for h in HELP.findall(body):
        for t in msg_types(h, seen):
            if t not in found:
                found.append(t)
    return found

def helpers(body):
    seen = []
    for h in HELP.findall(body):
        if h not in seen:
            seen.append(h)
    return ", ".join(seen) if seen else ("直接 sendall" if "sendall" in body else "-")

t1 = []
for m in ms:
    if not m["override"]:
        continue
    t = msg_types(m["name"], set())
    msg = "＋".join(NAMES[x] for x in t) if t else "不送訊息"
    t1.append((m["name"], str(m["def"]), helpers(m["body"]), msg))

t2 = []
for no, line in enumerate(lines, 1):
    for fmt, kind in PACK.findall(line):
        k = int(kind)
        t2.append((k, NAMES.get(k, "?"), fmt, struct.calcsize(fmt), no))
t2.sort()
print("【表二】全檔的 struct.pack（用戶端送出的 RFB 訊息）")
print("{:>8} | {:<26} | {:<22} | {:>6} | {}".format("訊息型別", "名稱", "格式字串", "位元組", "行號"))
print("-" * 90)
for row in t2:
    print("{:>8} | {:<26} | {:<22} | {:>6} | {}".format(*row))
print("共", len(t2), "處 struct.pack，訊息型別", sorted(set(r[0] for r in t2)))
print("另有", len(grep(VNC, "struct[.]unpack")), "處 struct.unpack（讀伺服器回應，不算用戶端訊息）")
print()

def const(prefix):
    no, line = grep(VNC, "^" + prefix)[0]
    return no, ast.literal_eval(line.split("=", 1)[1].split("#")[0].strip())

no_mx, (mw, mh) = const("MAX_WIDTH, MAX_HEIGHT = ")
no_lr, (left, right) = const("LEFT, RIGHT = ")
no_wh, wheel = const("WHEEL = ")
start = [i for i, l in enumerate(lines) if l.startswith("KEYSYMS = {")][0]
end = start
while not lines[end].startswith("}"):
    end += 1
block = "\n".join(lines[start:end + 1])
pairs = re.findall(Q + "([a-z_]+)" + Q + ": 0x([0-9A-Fa-f]+)", block)
rng = re.search("range[(]([0-9]+), ([0-9]+)[)]", block)
base = int(re.search("0x([0-9A-Fa-f]+) [+] n", block).group(1), 16)
nf = int(rng.group(2)) - int(rng.group(1))
distinct = len(set(v.upper() for _, v in pairs))
print("【常數】")
print("  MAX_WIDTH, MAX_HEIGHT = {}, {}（第 {} 行）".format(mw, mh, no_mx))
print("  LEFT, RIGHT = {}, {}（第 {} 行，PointerEvent 的按鍵遮罩）".format(left, right, no_lr))
print("  WHEEL = {}（第 {} 行，滾輪當成四顆按鍵）".format(wheel, no_wh))
print("  KEYSYMS 在第 {}～{} 行：引號寫出的鍵名 {} 個（不重複的 keysym {} 個，其餘是別名）".format(start + 1, end + 1, len(pairs), distinct))
print("  加上 f1～f{}：{} 個（F1 = 0x{}，F12 = 0x{}）→ 總共 {} 個鍵名".format(nf, nf, format(base + 1, "04X"), format(base + nf, "04X"), len(pairs) + nf))
print("  鍵名：", ", ".join(n for n, _ in pairs))
print()

raw = 1280 * 800 * 4
big = mw * mh * 4
print("【驗算】Raw 編碼、每像素 4 位元組（SetPixelFormat 要 32 位元）")
for no, line in grep(VNC, "bytearray[(]self[.]width"):
    print("  vnc_computer.py 第 {} 行：{}".format(no, line.strip()))
print("  1280*800*4 = {:,} 位元組 = {} MB（十進位）≈ {} MiB".format(raw, raw / 1000000, round(raw / 1048576, 2)))
print("  上限 {}*{}*4 = {:,} 位元組".format(mw, mh, big))
for no, line in grep(README, "about 4 MB"):
    print("  README 第 {} 行：{}".format(no, line.strip()[:120]))

md = ["# 第 6 章練習 1：VncComputer 工具 → RFB 訊息對照表", "", "來源：computer-toolset/python/vnc_computer.py（只讀、純文字分析，未執行）", "",
      "## 表一：工具 → 內部函式 → RFB 訊息", "", "| 工具 | 行號 | 走哪個內部函式 | 最後變成哪種 RFB 訊息 |", "| --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} |".format(*r) for r in t1]
md += ["", "## 表二：struct.pack", "", "| 訊息型別 | 名稱 | 格式字串 | 位元組數 | 行號 |", "| --- | --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} | {} |".format(*r) for r in t2]
md += ["", "## 常數", "",
       "- MAX_WIDTH, MAX_HEIGHT = {}, {}".format(mw, mh),
       "- LEFT, RIGHT = {}, {}".format(left, right),
       "- WHEEL = {}".format(wheel),
       "- KEYSYMS：引號鍵名 {} 個＋f1～f{} 共 {} 個＝{} 個".format(len(pairs), nf, nf, len(pairs) + nf),
       "", "## 驗算", "",
       "- 1280*800*4 = {:,} 位元組 = {} MB，對得上 README 的 about 4 MB".format(raw, raw / 1000000),
       "- 上限 {}*{}*4 = {:,} 位元組".format(mw, mh, big)]
map_path.write_text("\n".join(md) + "\n", encoding="utf-8")
print()
print("已寫入", map_path)'
   show "$P"; run "$P" ;;
4) banner "練習 2 之一：假桌面 FakeDesktop、確認關卡與程式自己做的三步"
   tip "先認識練習 2 的假環境：文字狀態的 1280x800 假桌面，不是 VNC，截圖是一段文字；確認關卡自動放行並記錄。程式自己做三步，最後一步點 [1280,800] 會被拒絕。這一步不呼叫模型。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

DOLLAR = chr(36)
FAKE_DATE = "Thu Jan  1 00:00:00 UTC 2030"
B = "computer-toolset/python/"
out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
steps_path = out / "program_steps.json"
steps_path.unlink(missing_ok=True)

class FakeToolError(Exception):
    pass

class FakeDesktop:
    """假環境：1280x800 的文字狀態桌面，只有一個終端機視窗；不是 VNC，也沒有真的截圖。"""
    W, H = 1280, 800
    WIN = (100, 100, 900, 600)

    def __init__(self):
        self.focused = False
        self.buffer = ""
        self.lines = []

    def screenshot(self):
        x0, y0, x1, y1 = self.WIN
        text = " / ".join(self.lines) if self.lines else "（空白）"
        return "螢幕 {}x{}；終端機視窗 ({},{})-({},{})，focused={}；畫面文字：{}；輸入列：{} {}".format(self.W, self.H, x0, y0, x1, y1, self.focused, text, DOLLAR, self.buffer)

    def left_click(self, coordinate):
        if not (isinstance(coordinate, (list, tuple)) and len(coordinate) == 2):
            raise FakeToolError("coordinate must be [x, y]")
        x, y = int(coordinate[0]), int(coordinate[1])
        if not (0 <= x < self.W and 0 <= y < self.H):
            raise FakeToolError("({}, {}) is outside the {}x{} screen".format(x, y, self.W, self.H))
        x0, y0, x1, y1 = self.WIN
        if x0 <= x <= x1 and y0 <= y <= y1:
            self.focused = True
            return "clicked ({}, {})：終端機已聚焦".format(x, y)
        return "clicked ({}, {})：不在終端機視窗內，焦點不變".format(x, y)

    def _return(self):
        self.lines.append(FAKE_DATE if self.buffer.strip() == "date" else "command not found")
        self.buffer = ""

    def type(self, text):
        if not self.focused:
            return "ignored：終端機沒有聚焦，字沒有打進去"
        for ch in str(text):
            if ch == "\n":
                self._return()
            else:
                self.buffer += ch
        return "typed " + json.dumps(str(text))

    def key(self, text):
        if str(text).lower() != "return":
            raise FakeToolError("unknown key " + json.dumps(str(text)) + "; this fake desktop only knows Return")
        self._return()
        return "pressed Return"

rows = []
confirms = []

def confirm(name, tool_input):
    if name == "screenshot":
        return True
    line = "Allow {} {}? -> y（自動放行）".format(name, json.dumps(tool_input, ensure_ascii=False))
    print("  " + line)
    confirms.append(line)
    return True

def record(who, call_no, tool, tool_input, fn):
    asked = tool != "screenshot"
    confirm(tool, tool_input)
    try:
        result, err = str(fn()), False
    except (FakeToolError, ValueError, TypeError) as exc:
        result, err = str(exc), True
    rows.append({"step": len(rows) + 1, "who": who, "call": call_no, "tool": tool, "input": tool_input,
                 "confirmed": "已確認（自動放行）" if asked else "免問", "result": result, "is_error": err})
    return result, err

desk = FakeDesktop()
print("假環境：FakeDesktop 是幾十行的文字狀態物件（focused、buffer、lines），不是 VNC 桌面；截圖是文字描述；這一步不呼叫模型。")
print()
print("【確認關卡的紀錄】")
record("程式", 0, "screenshot", {}, desk.screenshot)
record("程式", 0, "left_click", {"coordinate": [640, 400]}, lambda: desk.left_click([640, 400]))
record("程式", 0, "left_click", {"coordinate": [1280, 800]}, lambda: desk.left_click([1280, 800]))
print()
print("{:>4} | {:<6} | {:<10} | {:<26} | {:<18} | {:<8} | {}".format("步驟", "誰發起", "工具", "輸入", "確認", "is_error", "結果"))
print("-" * 150)
for r in rows:
    print("{:>4} | {:<6} | {:<10} | {:<26} | {:<18} | {:<8} | {}".format(r["step"], r["who"], r["tool"], json.dumps(r["input"]), r["confirmed"], str(r["is_error"]), r["result"]))
print()
print("三步之後：focused =", desk.focused, "｜buffer =", json.dumps(desk.buffer), "｜lines =", desk.lines, "｜確認紀錄", len(confirms), "筆")
after = desk.screenshot()
print("聚焦後的截圖文字：", after)
print()

print("【額外檢查，用另一個全新的假桌面，不記錄】")
d2 = FakeDesktop()
print("  left_click [1279, 799] →", d2.left_click([1279, 799]))
print("  沒聚焦就 type date＋換行 →", d2.type("date\n"), "｜lines =", d2.lines)
try:
    d2.key("ctrl+c")
except FakeToolError as exc:
    print("  key ctrl+c →", exc)
d2.left_click([640, 400])
d2.type("date\n")
d2.type("ls")
d2.key("Return")
print("  聚焦後 type date＋換行、type ls、key Return → lines =", d2.lines)
print()

who = [
    ("left_click 超出螢幕", "驅動程式 _move 丟 ToolError", "vnc_computer.py", "is outside the"),
    ("（理由）", "拒絕而不是夾回邊界", "vnc_computer.py", "refused, not clamped"),
    ("zoom", "SDK：驅動程式沒實作，回報停用並拒絕", "exercise.py", "does not implement zoom"),
    ("不認得的鍵名", "驅動程式 keysym 丟 ToolError", "vnc_computer.py", "unknown key"),
    ("截圖以外的每個動作", "run.py 的 ask 問 y/N（截圖免問）", "run.py", "member == "),
    ("exercise.py 的確認", "一律放行", "exercise.py", "confirm=lambda"),
]
print("【誰擋下了什麼（官方做法）】")
print("{:<20} | {:<34} | {}".format("被擋或把關的呼叫", "誰擋", "原始碼"))
print("-" * 150)
for call, by, rel, pat in who:
    hits = grep(B + rel, pat)
    src = "{}:{} {}".format(rel, hits[0][0], hits[0][1].strip()[:80]) if hits else rel + "：找不到"
    print("{:<20} | {:<34} | {}".format(call, by, src))

steps_path.write_text(json.dumps({"rows": rows, "confirms": confirms, "screenshot_after": after,
                                  "focused": desk.focused, "lines": desk.lines}, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已寫入", steps_path)'
   show "$P"; run "$P" ;;
5) banner "練習 2 之二：模型實際會收到什麼（離線看轉接層）"
   tip "呼叫模型之前，先看四個自訂工具怎麼被轉接層寫進系統提示、模型的回覆又怎麼被解析成 tool_use。這是用提示詞模擬的工具呼叫，不是 API 原生 tool use；工具組項目會被忽略，圖片也不會送出。這一步不呼叫模型。"
   P='import json, os, sys
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client

DOLLAR = chr(36)
SAMPLE_SHOT = "螢幕 1280x800；終端機視窗 (100,100)-(900,600)，focused=True；畫面文字：（空白）；輸入列：" + DOLLAR + " "
shot, src = SAMPLE_SHOT, "內建範例（找不到第 4 步的 program_steps.json）"
p = Path("ch06/interactive/program_steps.json")
if p.exists():
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        if isinstance(data, dict) and isinstance(data.get("screenshot_after"), str) and data["screenshot_after"]:
            shot, src = data["screenshot_after"], "ch06/interactive/program_steps.json（第 4 步）"
    except ValueError:
        pass
print("聚焦後截圖文字的來源：", src)
print()

TOOLS = [
    {"name": "screenshot", "description": "取得目前螢幕的截圖（這個假桌面用一段文字描述代替圖片）。", "input_schema": {"type": "object", "properties": {}}},
    {"name": "left_click", "description": "在螢幕座標 [x, y] 按一下滑鼠左鍵。座標以像素計，左上角是 [0, 0]。",
     "input_schema": {"type": "object", "properties": {"coordinate": {"type": "array", "items": {"type": "integer"}, "description": "[x, y]"}}, "required": ["coordinate"]}},
    {"name": "type", "description": "在聚焦的視窗打字；文字裡的換行等於按 Return。",
     "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
    {"name": "key", "description": "按一個鍵，例如 Return。",
     "input_schema": {"type": "object", "properties": {"text": {"type": "string", "description": "鍵名，例如 Return"}}, "required": ["text"]}},
]
SYSTEM = "你是電腦操作助理，正在操作一個 1280x800 的桌面。你只能透過提供的工具操作；每次動作後可以用 screenshot 看結果。不要假裝做了沒做的動作。用繁體中文回報。"
TASK = "目前的螢幕截圖（文字描述）：\n" + shot + "\n\n任務：在終端機執行 date，然後告訴我輸出。"

client_tools, ignored = claude_cli_client.split_tools(TOOLS)
print("可模擬的自訂工具：", [t["name"] for t in client_tools], "｜忽略：", ignored)
_, ignored2 = claude_cli_client.split_tools(TOOLS + [{"type": "computer_toolset_20260801", "name": "computer"}])
print("若照官方把工具組項目也放進 tools，轉接層會忽略：", ignored2, "（沒有 input_schema 的伺服器端型別）")
print("圖片 block 在逐字稿裡會變成：", claude_cli_client._block_text({"type": "image"}))
print()
print("=== 轉接層送給 claude -p 的系統提示 ===")
print(claude_cli_client.system_text(SYSTEM, client_tools))
print()
print("=== 第 1 次呼叫送進 stdin 的內容 ===")
print(claude_cli_client.flatten_messages([{"role": "user", "content": TASK}]))
print()
demo = [
    {"role": "user", "content": TASK},
    {"role": "assistant", "content": [SimpleNamespace(type="tool_use", id="toolu_demo", name="type", input={"text": "date\n"})]},
    {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "toolu_demo", "content": "typed " + json.dumps("date\n")}]},
]
print("=== 示意：第 2 次呼叫的 stdin（歷史攤平成逐字稿整份重送，每次都是全新的 claude -p 行程） ===")
print(claude_cli_client.flatten_messages(demo))
print()
names = {t["name"] for t in client_tools}

def tag(name, tool_input):
    return "<tool_use>" + json.dumps({"name": name, "input": tool_input}) + "</tool_use>"

cases = [
    ("照格式", "我來輸入指令。" + tag("type", {"text": "date\n"})),
    ("一次兩個", tag("type", {"text": "date"}) + tag("key", {"text": "Return"})),
    ("沒照格式", "我已經在終端機打了 date，輸出應該是今天的日期。"),
    ("工具不在清單", tag("zoom", {"region": [0, 0, 100, 100]})),
]
print("【parse_reply 怎麼解析模型回覆】")
for label, text in cases:
    blocks = claude_cli_client.parse_reply(text, names)
    calls = [(b.name, b.input) for b in blocks if b.type == "tool_use"]
    print("  {:<8} → block 種類 {}；tool_use {}".format(label, [b.type for b in blocks], calls if calls else "無（下一步會當成沒呼叫工具）"))'
   show "$P"; run "$P" ;;
6) banner "練習 2 之三：真模型＋假桌面，跑截圖→動作迴圈"
   tip "這一步會呼叫模型最多 2 次（claude -p，每次約 5～15 秒，最多等 180 秒）；第 1 次沒有 tool_use 時用第 2 次重試 1 次。模型是真的，桌面、截圖、date 輸出都是假的，工具呼叫是用提示詞模擬的。每次結果可能不同，照實記錄；失敗也會存檔並正常結束。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
os.environ["K902_CLI_MAX_CALLS"] = "2"  # 保險：本行程最多呼叫 claude -p 2 次
import claude_cli_client

DOLLAR = chr(36)
FAKE_DATE = "Thu Jan  1 00:00:00 UTC 2030"
MAX_CALLS = 2
out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
md_path = out / "loop_log.md"
json_path = out / "loop_log.json"
md_path.unlink(missing_ok=True)
json_path.unlink(missing_ok=True)

class FakeToolError(Exception):
    pass

class FakeDesktop:
    """假環境：1280x800 的文字狀態桌面，只有一個終端機視窗；不是 VNC，也沒有真的截圖。"""
    W, H = 1280, 800
    WIN = (100, 100, 900, 600)

    def __init__(self):
        self.focused = False
        self.buffer = ""
        self.lines = []

    def screenshot(self):
        x0, y0, x1, y1 = self.WIN
        text = " / ".join(self.lines) if self.lines else "（空白）"
        return "螢幕 {}x{}；終端機視窗 ({},{})-({},{})，focused={}；畫面文字：{}；輸入列：{} {}".format(self.W, self.H, x0, y0, x1, y1, self.focused, text, DOLLAR, self.buffer)

    def left_click(self, coordinate):
        if not (isinstance(coordinate, (list, tuple)) and len(coordinate) == 2):
            raise FakeToolError("coordinate must be [x, y]")
        x, y = int(coordinate[0]), int(coordinate[1])
        if not (0 <= x < self.W and 0 <= y < self.H):
            raise FakeToolError("({}, {}) is outside the {}x{} screen".format(x, y, self.W, self.H))
        x0, y0, x1, y1 = self.WIN
        if x0 <= x <= x1 and y0 <= y <= y1:
            self.focused = True
            return "clicked ({}, {})：終端機已聚焦".format(x, y)
        return "clicked ({}, {})：不在終端機視窗內，焦點不變".format(x, y)

    def _return(self):
        self.lines.append(FAKE_DATE if self.buffer.strip() == "date" else "command not found")
        self.buffer = ""

    def type(self, text):
        if not self.focused:
            return "ignored：終端機沒有聚焦，字沒有打進去"
        for ch in str(text):
            if ch == "\n":
                self._return()
            else:
                self.buffer += ch
        return "typed " + json.dumps(str(text))

    def key(self, text):
        if str(text).lower() != "return":
            raise FakeToolError("unknown key " + json.dumps(str(text)) + "; this fake desktop only knows Return")
        self._return()
        return "pressed Return"

desk = FakeDesktop()
rows = []
confirms = []

def confirm(name, tool_input):
    if name == "screenshot":
        return True
    line = "Allow {} {}? -> y（自動放行）".format(name, json.dumps(tool_input, ensure_ascii=False))
    print("  " + line)
    confirms.append(line)
    return True

def record(who, call_no, tool, tool_input, fn):
    asked = tool != "screenshot"
    confirm(tool, tool_input)
    try:
        result, err = str(fn()), False
    except (FakeToolError, ValueError, TypeError) as exc:
        result, err = str(exc), True
    rows.append({"step": len(rows) + 1, "who": who, "call": call_no, "tool": tool, "input": tool_input,
                 "confirmed": "已確認（自動放行）" if asked else "免問", "result": result, "is_error": err})
    return result, err

print("假環境：FakeDesktop 是文字狀態物件、截圖是文字描述、date 輸出是寫死的假字串；模型是真的（claude -p）；工具呼叫用提示詞模擬，不是 API 原生 tool use，也不是真的 computer_toolset_20260801。")
print()
print("【程式先做三步（不經模型）】")
record("程式", 0, "screenshot", {}, desk.screenshot)
record("程式", 0, "left_click", {"coordinate": [640, 400]}, lambda: desk.left_click([640, 400]))
record("程式", 0, "left_click", {"coordinate": [1280, 800]}, lambda: desk.left_click([1280, 800]))
print("  結果：", [(r["tool"], r["is_error"]) for r in rows])
shot = desk.screenshot()

TOOLS = [
    {"name": "screenshot", "description": "取得目前螢幕的截圖（這個假桌面用一段文字描述代替圖片）。", "input_schema": {"type": "object", "properties": {}}},
    {"name": "left_click", "description": "在螢幕座標 [x, y] 按一下滑鼠左鍵。座標以像素計，左上角是 [0, 0]。",
     "input_schema": {"type": "object", "properties": {"coordinate": {"type": "array", "items": {"type": "integer"}, "description": "[x, y]"}}, "required": ["coordinate"]}},
    {"name": "type", "description": "在聚焦的視窗打字；文字裡的換行等於按 Return。",
     "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
    {"name": "key", "description": "按一個鍵，例如 Return。",
     "input_schema": {"type": "object", "properties": {"text": {"type": "string", "description": "鍵名，例如 Return"}}, "required": ["text"]}},
]
SYSTEM = "你是電腦操作助理，正在操作一個 1280x800 的桌面。你只能透過提供的工具操作；每次動作後可以用 screenshot 看結果。不要假裝做了沒做的動作。用繁體中文回報。"
TASK = "目前的螢幕截圖（文字描述）：\n" + shot + "\n\n任務：在終端機執行 date，然後告訴我輸出。"

def run_tool(name, tool_input):
    if name == "screenshot":
        return desk.screenshot()
    if name == "left_click":
        return desk.left_click(tool_input.get("coordinate"))
    if name == "type":
        return desk.type(tool_input.get("text", ""))
    if name == "key":
        return desk.key(tool_input.get("text", ""))
    raise FakeToolError("unknown tool: " + str(name))

client = claude_cli_client.Anthropic()
messages = [{"role": "user", "content": TASK}]
details = []
final_text = ""
error = None
retried = False
print()
print("=== 截圖→動作迴圈（最多 {} 次 claude -p，每次約 5～15 秒） ===".format(MAX_CALLS))
while claude_cli_client.calls_made() < MAX_CALLS:
    try:
        reply = client.messages.create(model="claude-sonnet-5-5", max_tokens=1024, system=SYSTEM, messages=messages, tools=TOOLS)
    except (claude_cli_client.APIError, RuntimeError, ValueError) as exc:
        error = type(exc).__name__ + "：" + str(exc)
        print("這次呼叫失敗，原因：" + error + "（照樣把已有的紀錄存檔，結束碼 0）")
        break
    call_no = claude_cli_client.calls_made()
    texts = [str(b.text) for b in reply.content if b.type == "text"]
    uses = [b for b in reply.content if b.type == "tool_use"]
    details.append({"call": call_no, "stop_reason": reply.stop_reason, "tool_uses": [[u.name, u.input] for u in uses], "text": "\n".join(texts)})
    print("第 {} 次呼叫：stop_reason = {}｜tool_use = {}".format(call_no, reply.stop_reason, json.dumps([[u.name, u.input] for u in uses], ensure_ascii=False) if uses else "無"))
    if texts:
        print("  模型文字：" + " ".join(texts).replace("\n", " ")[:200])
    if not uses:
        if call_no == 1 and call_no < MAX_CALLS:
            retried = True
            print("  這次模型沒有照格式呼叫工具（回覆裡沒有 tool_use），這是提示詞模擬工具呼叫的限制。在上限內重試 1 次，並提醒它用 <tool_use> 標記。")
            messages = [{"role": "user", "content": TASK + "\n\n提醒：請實際用 <tool_use> 標記呼叫工具，不要只用文字描述。"}]
            continue
        final_text = "\n".join(texts)
        if not any(r["who"] == "模型" for r in rows):
            print("  模型這次也沒有照格式呼叫工具（提示詞模擬工具呼叫的限制）；照實記錄拿到的文字，不再呼叫。")
        break
    results = []
    for u in uses:
        res, err = record("模型", call_no, u.name, u.input, lambda u=u: run_tool(u.name, u.input))
        print("  執行 {} {} → {}{}".format(u.name, json.dumps(u.input, ensure_ascii=False), res, "（is_error）" if err else ""))
        block = {"type": "tool_result", "tool_use_id": u.id, "content": res}
        if err:
            block["is_error"] = True
        results.append(block)
    messages = messages + [{"role": "assistant", "content": reply.content}, {"role": "user", "content": results}]
    if claude_cli_client.calls_made() >= MAX_CALLS:
        print("  已用完 {} 次呼叫上限：這回合的工具已執行並記錄，但不再送回模型拿最後的文字回答。".format(MAX_CALLS))

calls = claude_cli_client.calls_made()

def cell(v):
    return str(v).replace("\n", " / ").replace("|", "／")

print()
print("{:>4} | {:<6} | {:<10} | {:<28} | {:<18} | {:<8} | {}".format("步驟", "誰發起", "工具", "輸入", "確認", "is_error", "結果"))
print("-" * 150)
for r in rows:
    print("{:>4} | {:<6} | {:<10} | {:<28} | {:<18} | {:<8} | {}".format(r["step"], r["who"], r["tool"], json.dumps(r["input"], ensure_ascii=False), r["confirmed"], str(r["is_error"]), cell(r["result"])))
non_shot = sum(1 for r in rows if r["tool"] != "screenshot")
summary = "lines = {}｜確認紀錄 {} 筆（截圖以外的動作 {} 個）｜calls_made() = {}｜假桌面、假 date 輸出、提示詞模擬的工具呼叫".format(json.dumps(desk.lines, ensure_ascii=False), len(confirms), non_shot, calls)
print()
print(summary)
if error:
    print("錯誤：", error)
if final_text:
    print("模型最後的文字：", final_text.replace("\n", " ")[:300])

md = ["# 第 6 章練習 2：真模型＋假桌面的截圖→動作迴圈紀錄", "",
      "- 假環境：FakeDesktop（1280x800，終端機視窗 (100,100)-(900,600)，文字截圖）；date 輸出是寫死的假字串；模型是真的（claude -p），工具呼叫用提示詞模擬。",
      "- 是否重試：" + str(retried) + "｜錯誤：" + (error or "無"), "",
      "| 步驟 | 誰發起 | 工具 | 輸入 | 有沒有經過確認 | 結果 | is_error |", "| --- | --- | --- | --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} | {} | {} | {} |".format(r["step"], r["who"], r["tool"], cell(json.dumps(r["input"], ensure_ascii=False)), r["confirmed"], cell(r["result"]), r["is_error"]) for r in rows]
md += ["", "## 確認紀錄", ""] + ["- " + cell(c) for c in confirms]
md += ["", "## 結果", "", "- lines：" + cell(json.dumps(desk.lines, ensure_ascii=False)), "- calls_made()：" + str(calls),
       "- 模型最後的文字：" + (cell(final_text) if final_text else "（無）"), "", "註：假桌面、假 date 輸出、提示詞模擬的工具呼叫。"]
md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
json_path.write_text(json.dumps({"rows": rows, "confirms": confirms, "details": details, "lines": desk.lines, "calls": calls,
                                 "retried": retried, "final_text": final_text, "error": error}, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已寫入", md_path, "與", json_path)'
   show "$P"; run "$P" ;;
7) banner "練習 2 之四：檢查觀察重點，逐行對回官方 exercise.py"
   tip "不再呼叫模型。讀第 6 步的 loop_log.json（找不到就用內建範例），回答三個觀察重點，再把演練每一步對回 exercise.py 的十行 call，說清楚假桌面省略了什麼。"
   P='import json, os, re, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

Q = chr(34)
DOLLAR = chr(36)
FAKE_DATE = "Thu Jan  1 00:00:00 UTC 2030"
EX = "computer-toolset/python/exercise.py"
VNC = "computer-toolset/python/vnc_computer.py"
out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
review_path = out / "loop_review.md"
review_path.unlink(missing_ok=True)

def shot(focused, lines_):
    text = " / ".join(lines_) if lines_ else "（空白）"
    return "螢幕 1280x800；終端機視窗 (100,100)-(900,600)，focused={}；畫面文字：{}；輸入列：{} ".format(focused, text, DOLLAR)

ASK = "已確認（自動放行）"
sample_rows = [
    {"step": 1, "who": "程式", "call": 0, "tool": "screenshot", "input": {}, "confirmed": "免問", "result": shot(False, []), "is_error": False},
    {"step": 2, "who": "程式", "call": 0, "tool": "left_click", "input": {"coordinate": [640, 400]}, "confirmed": ASK, "result": "clicked (640, 400)：終端機已聚焦", "is_error": False},
    {"step": 3, "who": "程式", "call": 0, "tool": "left_click", "input": {"coordinate": [1280, 800]}, "confirmed": ASK, "result": "(1280, 800) is outside the 1280x800 screen", "is_error": True},
    {"step": 4, "who": "模型", "call": 1, "tool": "type", "input": {"text": "date\n"}, "confirmed": ASK, "result": "typed " + json.dumps("date\n"), "is_error": False},
    {"step": 5, "who": "模型", "call": 2, "tool": "screenshot", "input": {}, "confirmed": "免問", "result": shot(True, [FAKE_DATE]), "is_error": False},
]
SAMPLE = {"calls": 2, "retried": False, "error": None, "final_text": "", "lines": [FAKE_DATE], "rows": sample_rows,
          "confirms": ["Allow {} {}? -> y（自動放行）".format(r["tool"], json.dumps(r["input"], ensure_ascii=False)) for r in sample_rows if r["tool"] != "screenshot"]}
data, src = SAMPLE, "內建範例（找不到第 6 步的 loop_log.json；照常見結果編的）"
p = out / "loop_log.json"
if p.exists():
    try:
        loaded = json.loads(p.read_text(encoding="utf-8"))
        if isinstance(loaded, dict) and isinstance(loaded.get("rows"), list) and loaded["rows"]:
            data, src = loaded, "ch06/interactive/loop_log.json（第 6 步的真模型紀錄）"
    except ValueError:
        pass
print("資料來源：", src)
rows = data["rows"]
lines_ = data.get("lines") or []
confirms = data.get("confirms") or []
model_rows = [r for r in rows if r.get("who") == "模型"]
print("模型發起的工具呼叫：", json.dumps([[r["tool"], r["input"]] for r in model_rows], ensure_ascii=False) if model_rows else "無")
print("是否重試過：", data.get("retried"), "｜錯誤：", data.get("error") or "無", "｜calls_made()：", data.get("calls"))
print()

def text_of(r):
    return str(r["input"].get("text", "")) if isinstance(r.get("input"), dict) else ""

types_ = [r for r in model_rows if r["tool"] == "type"]
keys_ = [r for r in model_rows if r["tool"] == "key"]
if any(text_of(r).endswith("\n") for r in types_):
    way = "一次 type date＋換行"
elif types_ and any(text_of(r).lower() == "return" for r in keys_):
    way = "先 type date，再 key Return"
elif model_rows:
    way = "其他（照實記錄：" + ", ".join(r["tool"] for r in model_rows) + "）"
else:
    way = "模型沒有發起工具呼叫"
non_shot = sum(1 for r in rows if r.get("tool") != "screenshot")
outside = [r for r in rows if r.get("who") == "程式" and r.get("input") == {"coordinate": [1280, 800]}]
q3 = bool(outside) and outside[0]["is_error"] is True and "outside" in str(outside[0]["result"])
print("【觀察重點】")
print("  1. 模型怎麼打 date：", way)
print("     lines 出現假日期：", "是" if FAKE_DATE in lines_ else "否", "｜lines =", json.dumps(lines_, ensure_ascii=False))
print("  2. 確認紀錄", len(confirms), "筆；截圖以外的動作", non_shot, "個 → ", "相等" if len(confirms) == non_shot else "不相等")
print("  3. [1280,800] 被拒絕且訊息含 outside：", "是" if q3 else "否")
cond = grep(VNC, "0 <= x < self[.]width")
print("     驅動程式的判斷（vnc_computer.py 第 {} 行）：{}".format(cond[0][0], cond[0][1].strip()))
for x, y in ([0, 0], [1279, 799], [1280, 799], [1280, 800]):
    ok = 0 <= x < 1280 and 0 <= y < 800
    print("     [{}, {}] → {}".format(x, y, "合法" if ok else "出界，拒絕"))
print("     → 像素從 0 開始編號，寬 1280 就是 0～1279、高 800 就是 0～799；exercise.py 故意用 [width, height] 正好超出一個像素。")
print()

LABEL = {
    93: ("answered", "-", "程式第 1 步 screenshot"),
    96: ("answered", "-", "程式第 2 步 left_click [640,400]（剛好是 1280x800 的中心）"),
    99: ("answered", "-", "模型的 type"),
    100: ("answered", "-", "模型的 key Return（模型一次 type date＋換行時就沒有）"),
    101: ("answered", "-", "沒做：假桌面沒有 wait 工具"),
    104: ("answered", "-", "模型的第二張 screenshot（若有）"),
    109: ("重試迴圈", "-", "沒做：伺服器畫面還沒變時才跑"),
    110: ("重試迴圈", "-", "沒做：同上"),
    116: ("refused", "驅動程式 _move 丟 ToolError", "程式第 3 步 left_click [1280,800]"),
    121: ("refused", "SDK：沒實作，回報停用並拒絕", "沒做：假桌面沒給 zoom；轉接層把不在清單的工具名當文字"),
}
hits = grep(EX, "call[(]computer, " + Q)
table = []
for no, line in hits:
    m = re.search("call[(]computer, " + Q + "([a-z_]+)" + Q, line)
    res, blocker, ours = LABEL.get(no, ("?", "?", "?"))
    table.append((no, m.group(1) if m else "?", res, blocker, ours))
print("【對回官方 exercise.py】")
print("{:>4} | {:<11} | {:<9} | {:<30} | {}".format("行號", "工具", "官方結果", "誰擋", "本演練對應"))
print("-" * 130)
for row in table:
    print("{:>4} | {:<11} | {:<9} | {:<30} | {}".format(*row))
print("共", len(table), "行 call(computer, ...)；扣掉重試迴圈的 2 行，就是 README 說的八個呼叫（六個 answered、兩個 refused）")
print()
print("【假桌面省略了什麼】")
for pat in ("time[.]sleep[(]0[.]5[)]", "VNC cannot report where the pointer is"):
    for no, line in grep(VNC, pat)[:1]:
        print("  vnc_computer.py 第 {} 行：{}".format(no, line.strip()[:110]))
print("  → 真的 VNC 沒有「動作做完」的訊號，截圖可能是舊畫面；假桌面的文字截圖永遠是最新狀態，也不需要記 _cursor、不送任何 RFB 訊息、模型也看不到圖。")

md = ["# 第 6 章練習 2：檢查與對照", "", "- 資料來源：" + src,
      "- 模型怎麼打 date：" + way, "- lines：" + json.dumps(lines_, ensure_ascii=False),
      "- 確認紀錄 {} 筆／截圖以外的動作 {} 個".format(len(confirms), non_shot),
      "- [1280,800] 被拒絕且含 outside：" + str(q3) + "（合法最大座標是 [1279,799]）", "",
      "| exercise.py 行號 | 工具 | 官方結果 | 誰擋 | 本演練對應 |", "| --- | --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} | {} |".format(*r) for r in table]
review_path.write_text("\n".join(md) + "\n", encoding="utf-8")
print()
print("已寫入", review_path)'
   show "$P"; run "$P" ;;
8) banner "總結：本章 6 個重點與產出檔案"
   tip "把工具組宣告、截圖→動作迴圈、五種 RFB 訊息、錯誤寫給模型看、confirm 把關，以及演練裡哪些是假的，收成 6 句話，並確認本章檔案都在。"
   P='import json
from pathlib import Path

points = [
    "電腦操作工具組是在 tools 宣告一個項目、模型看到多個工具（screenshot、left_click、type…各自獨立呼叫）。型別字串 computer_toolset_20260801 只在 README 出現 1 次，.py 裡只有 SDK 類別 BetaAbstractComputerToolset20260801（vnc_computer.py 3 次、exercise.py 2 次）。",
    "核心迴圈是「截圖 → 模型決定動作 → 驅動程式執行 → 再截圖」，模型只看得到圖，座標自己估。run.py 的預設任務是 Open a terminal, run date...，模型 claude-sonnet-5-5、max_tokens=4096，交給 SDK 的 tool_runner。",
    "VncComputer 不用 VNC 函式庫：11 個 @override＝十個工具＋close；全檔 5 處 struct.pack 剛好是五種用戶端訊息 SetPixelFormat(0) 20 B、SetEncodings(2) 8 B、FramebufferUpdateRequest(3) 10 B、KeyEvent(4) 8 B、PointerEvent(5) 6 B。點擊、雙擊、三擊、捲動共用 _click，只差按鍵遮罩與次數。",
    "錯誤要讓模型看得到：座標出界是拒絕不是夾回（0 <= x < width，1280x800 的合法最大座標是 [1279,799]），由驅動程式丟 ToolError；zoom 是 SDK 因為沒實作而拒絕，兩者是不同層擋的。",
    "人工把關放在工具組的 confirm：run.py 的 ask 截圖免問、其他動作印出 json 問 y/N，因為聚焦的終端機會執行模型打的任何字；exercise.py 用 lambda context: True 一律放行。VNC 沒有完成訊號，所以截圖前睡 0.5 秒；問不到游標，所以自己記 _cursor；Raw 編碼 1280x800 一張是 4,096,000 位元組。",
    "本章演練是真模型＋假桌面：截圖用文字描述代替 PNG、date 輸出是寫死的 Thu Jan  1 00:00:00 UTC 2030、工具呼叫是轉接層用提示詞模擬的，不是 API 原生 tool use；轉接層會忽略工具組項目，也不傳圖片。",
]
print("第 6 章重點：")
for i, p in enumerate(points, 1):
    print("  {}. {}".format(i, p))
print()
note = "第 6 步沒有留下紀錄"
lp = Path("ch06/interactive/loop_log.json")
if lp.exists():
    try:
        rec = json.loads(lp.read_text(encoding="utf-8"))
        note = "第 6 步呼叫模型 {} 次、lines = {}、重試過：{}".format(rec.get("calls"), json.dumps(rec.get("lines"), ensure_ascii=False), rec.get("retried"))
    except ValueError:
        note = "loop_log.json 讀不懂"
print("本章模型呼叫：", note, "（本章只有第 6 步呼叫，最多 2 次；規則上限整章 4 次）")
print()
print("本章產出檔案：")
for name in ("rfb_map.md", "program_steps.json", "loop_log.md", "loop_log.json", "loop_review.md"):
    p = Path("ch06/interactive") / name
    print("  {} {}".format("OK" if p.exists() else "缺", p))'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
