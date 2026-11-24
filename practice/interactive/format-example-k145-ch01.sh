#!/bin/bash
# K145 第 1 章互動演練：從單體到群體——一次「架構躍遷」的現場觀察，一次跑一步
# 用法：bash ch01.sh <步驟 1-8>
# 呼叫模型：只有第 6 步會呼叫模型 1 次（claude -p，透過 llm_agent.ask_json），其餘步驟全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch01/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K145 第 1 章｜從單體到群體　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "代理數 vs 溝通路徑：臨界點自己浮現"
   tip "代理從 5 個變成 100 個是 20 倍，溝通路徑卻從 10 條變成 4950 條，是 495 倍。"
   P='NS = (1, 5, 10, 20, 30, 50, 75, 100)
print("{:>4} | {:>6} | {:>6} | {:>7} | {:>11} | {:>9} | {:>10}".format("N", "產能", "路徑數", "路徑/人", "成本@0.0025", "成本@0.02", "淨產出@0.02"))
print("-" * 76)
for n in NS:
    paths = n * (n - 1) // 2
    c1, c2 = paths * 0.0025, paths * 0.02
    print("{:>4} | {:>6.1f} | {:>6} | {:>7.1f} | {:>11.3f} | {:>9.2f} | {:>10.2f}".format(n, float(n), paths, paths / n, c1, c2, n - c2))
best = max(NS, key=lambda n: n - n * (n - 1) / 2 * 0.02)
print()
print("代理數 5 -> 100 是 20 倍；路徑數 10 -> 4950 是", 4950 // 10, "倍")
print("係數 0.02 時，淨產出最高的 N =", best)'
   show "$P"; run "$P" ;;
2) banner "練習 1 原樣重現：全互聯 vs 分層（係數 0.0025）"
   tip "照規格跑，看結果是否真的符合「最佳 N 在 20～50」。不符合也要照實記錄，下一步找原因。"
   P='import csv, math, random
from pathlib import Path
random.seed(145)
WORK, COEF, GROUP, MAX_ROUNDS = 600, 0.0025, 8, 5000
NS = (1, 5, 10, 20, 30, 50, 75, 100)
out = Path("ch01/interactive")
out.mkdir(parents=True, exist_ok=True)
(out / "scaling.csv").unlink(missing_ok=True)

def flat_paths(n):
    return n * (n - 1) // 2

def tiered_paths(n):
    sizes = [GROUP] * (n // GROUP) + ([n % GROUP] if n % GROUP else [])
    g = len(sizes)
    return sum(s * (s - 1) // 2 for s in sizes) + g * (g - 1) // 2

def rounds_needed(n, paths, coef):
    if n * 1.1 - paths * coef <= 0:
        return math.inf
    done, r = 0.0, 0
    while done < WORK:
        r += 1
        if r > MAX_ROUNDS:
            return math.inf
        cap = sum(random.uniform(0.9, 1.1) for _ in range(n))
        done += max(0.0, cap - paths * coef)
    return r

def mono_rounds(limit=120, step=60, drop=0.15, floor=0.2):
    done, r = 0.0, 0
    while done < WORK:
        r += 1
        k = int(max(0.0, done - limit) // step)
        done += random.uniform(0.9, 1.1) * max(floor, (1 - drop) ** k)
    return r

rows = []
for n in NS:
    fp, tp = flat_paths(n), tiered_paths(n)
    rows.append((n, fp, rounds_needed(n, fp, COEF), tp, rounds_needed(n, tp, COEF)))
mono = mono_rounds()

print("{:>4} | {:>9} | {:>9} | {:>11} | {:>11}".format("N", "flat路徑", "flat回合", "tiered路徑", "tiered回合"))
print("-" * 58)
for n, fp, fr, tp, tr in rows:
    print("{:>4} | {:>9} | {:>9} | {:>11} | {:>11}".format(n, fp, str(fr), tp, str(tr)))
best_flat = min(rows, key=lambda x: (x[2], x[0]))[0]
best_tier = min(rows, key=lambda x: (x[4], x[0]))[0]
print()
print("flat 最佳 N =", best_flat, "；tiered 最佳 N =", best_tier)
print(f"單體基準（上下文上限 120 單位、記憶衰退）：{mono} 回合")
print(f"單體基準是 N=5 全互聯的 {mono / rows[1][2]:.1f} 倍慢")

with open(out / "scaling.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["N", "flat_paths", "flat_rounds", "tiered_paths", "tiered_rounds"])
    for n, fp, fr, tp, tr in rows:
        w.writerow([n, fp, fr, tp, tr])
    w.writerow(["mono", "", mono, "", ""])
print("已寫入", out / "scaling.csv")'
   show "$P"; run "$P" ;;
3) banner "改參數找原因：臨界點約等於 1／係數"
   tip "係數 0.0025 的臨界點在 400，所以第 2 步看不到；把係數調成 0.02，就跟書裡「100 個代理比 50 個慢」對上了。"
   P='def net(n, c):
    return n - c * n * (n - 1) / 2

print("{:>8} | {:>6} | {:>10} | {:>10} | {:>11} | {:>13}".format("係數", "最佳N", "最佳淨產出", "N=50淨產出", "N=100淨產出", "淨產出歸零的N"))
print("-" * 76)
for c in (0.0025, 0.005, 0.01, 0.02, 0.04):
    best = max(range(1, 2001), key=lambda n: (round(net(n, c), 6), -n))
    zero = next(n for n in range(2, 5001) if net(n, c) <= 1e-9)
    print("{:>8} | {:>6} | {:>10.2f} | {:>10.2f} | {:>11.2f} | {:>13}".format(c, best, net(best, c), max(0.0, net(50, c)), max(0.0, net(100, c)), zero))

print()
print("規律：最佳 N 約 = 1 / 係數；淨產出歸零的 N 約 = 2 / 係數 + 1")
print()
print("書中案例：3 個代理分工做研究，反而花了將近 2 倍時間")
for c in (0.0025, 0.1, 0.5, 5 / 6):
    n3 = net(3, c)
    print("  每條路徑每回合吃 {:.4f}：3 代理淨產出 {:.2f}，耗時是單體的 {:.2f} 倍".format(c, n3, 1 / n3))'
   show "$P"; run "$P" ;;
4) banner "分層把平方成長壓回來（係數 0.02）"
   tip "分層不是讓代理變聰明，而是把「每個人要跟幾個人講話」壓低。"
   P='import math, random
random.seed(145)
WORK, COEF, GROUP, MAX_ROUNDS = 600, 0.02, 8, 5000
NS = (1, 5, 10, 20, 30, 50, 75, 100, 150, 200)

def flat_paths(n):
    return n * (n - 1) // 2

def tiered_paths(n):
    sizes = [GROUP] * (n // GROUP) + ([n % GROUP] if n % GROUP else [])
    g = len(sizes)
    return sum(s * (s - 1) // 2 for s in sizes) + g * (g - 1) // 2

def rounds_needed(n, paths, coef):
    if n * 1.1 - paths * coef <= 0:
        return math.inf
    done, r = 0.0, 0
    while done < WORK:
        r += 1
        if r > MAX_ROUNDS:
            return math.inf
        cap = sum(random.uniform(0.9, 1.1) for _ in range(n))
        done += max(0.0, cap - paths * coef)
    return r

rows = []
print("{:>4} | {:>8} | {:>9} | {:>8} | {:>10} | {:>11} | {:>10}".format("N", "flat路徑", "flat淨產出", "flat回合", "tiered路徑", "tiered淨產出", "tiered回合"))
print("-" * 82)
for n in NS:
    fp, tp = flat_paths(n), tiered_paths(n)
    fr, tr = rounds_needed(n, fp, COEF), rounds_needed(n, tp, COEF)
    rows.append((n, fr, tr))
    print("{:>4} | {:>8} | {:>9.2f} | {:>8} | {:>10} | {:>11.2f} | {:>10}".format(n, fp, n - fp * COEF, str(fr), tp, n - tp * COEF, str(tr)))
best_flat = min(rows, key=lambda x: (x[1], x[0]))[0]
best_tier = min(rows, key=lambda x: (x[2], x[0]))[0]
print()
print("flat 最佳 N =", best_flat, "；tiered 最佳 N =", best_tier)
print("N=100 時路徑數 flat / tiered =", round(flat_paths(100) / tiered_paths(100), 1), "倍")'
   show "$P"; run "$P" ;;
5) banner "單體的邊界：記憶衰退與上下文蒸餾"
   tip "作者拆成 11 個模組，做到第 7 個就忘了命名規範；改用上下文蒸餾才明顯變好。這一步把這段經驗變成數字。"
   P='import random
random.seed(145)
WORK = 600

print("把 600 單位拆成 11 個模組（每個約 54.5 單位），看每個模組做完時的產能係數：")
first = None
for i in range(1, 12):
    end = i * WORK / 11
    k = int(max(0.0, end - 120) // 60)
    f = max(0.2, 0.85 ** k)
    mark = ""
    if f < 0.6 and first is None:
        first = i
        mark = "  <- 第一次跌破 0.6"
    print("  模組 {:>2}：累積 {:>5.1f} 單位，產能係數 {:.2f}{}".format(i, end, f, mark))
print()

def solo(decay=True, distill=False, limit=120, step=60, drop=0.15, floor=0.2, cost=3, keep=20):
    done, ctx, r, n_d = 0.0, 0.0, 0, 0
    while done < WORK:
        if distill and ctx >= limit:
            r += cost
            ctx = keep
            n_d += 1
            continue
        r += 1
        k = int(max(0.0, ctx - limit) // step) if decay else 0
        got = random.uniform(0.9, 1.1) * max(floor, (1 - drop) ** k)
        done += got
        ctx += got
    return r, n_d

def team(n, coef=0.0025):
    done, r = 0.0, 0
    while done < WORK:
        r += 1
        cap = sum(random.uniform(0.9, 1.1) for _ in range(n))
        done += max(0.0, cap - coef * n * (n - 1) / 2)
    return r

r0, _ = solo(decay=False)
r1, _ = solo(decay=True)
r2, d2 = solo(decay=True, distill=True)
r5 = team(5)
print("{:<26} | {:>6}".format("做法", "回合數"))
print("-" * 38)
print("{:<26} | {:>6}".format("單體（假設不會忘）", r0))
print("{:<26} | {:>6}".format("單體（記憶衰退）", r1))
print("{:<26} | {:>6}".format("單體＋上下文蒸餾（{} 次）".format(d2), r2))
print("{:<26} | {:>6}".format("5 代理全互聯（係數0.0025）", r5))
print()
print("蒸餾讓單體快了 {:.0f}%".format((1 - r2 / r1) * 100))'
   show "$P"; run "$P" ;;
6) banner "練習 2 前半：讓真實模型當「指揮」"
   tip "這一步會呼叫模型 1 次（claude -p），最多等 180 秒；每次結果可能不同，照實記錄。"
   P='import json
from pathlib import Path
from llm_agent import ask_json

out = Path("ch01/interactive")
out.mkdir(parents=True, exist_ok=True)
raw = out / "conductor_raw.json"
raw.unlink(missing_ok=True)
prompt = """你是多代理系統的指揮（交響樂模型裡的指揮）。
任務：把一個十萬行舊系統的 11 個模組重構成新架構，並保持命名規範一致。
請規劃分工，輸出 JSON，格式如下：
{"agents": 整數, "subtasks": [{"id": "T1", "desc": "子任務說明", "depends_on": ["前置子任務 id"], "mode": "parallel 或 sequential"}], "shared_memory": "你打算讓所有代理共用什麼來避免忘記規範"}
規則：子任務 5～15 個；id 用 T1、T2、T3 依序編號；depends_on 只能填已存在的 id，沒有前置就填空陣列。"""
try:
    plan = ask_json(prompt)
except (RuntimeError, ValueError) as exc:
    raw.unlink(missing_ok=True)
    print("呼叫模型失敗：", exc)
    print("第 7 步會改用內建範例繼續。")
    raise SystemExit(0)
raw.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
subtasks = plan.get("subtasks") if isinstance(plan.get("subtasks"), list) else []
subtasks = [t for t in subtasks if isinstance(t, dict)]
print("指揮決定派出代理數：", plan.get("agents"))
print("子任務數：", len(subtasks))
for t in subtasks:
    deps = t.get("depends_on") or []
    if isinstance(deps, str):
        deps = [deps]
    print("  {:<4} [{:<10}] 依賴 {:<14} {}".format(str(t.get("id")), str(t.get("mode")), ",".join(map(str, deps)) or "-", str(t.get("desc", ""))[:40]))
print()
print("共用記憶：", plan.get("shared_memory"))
print()
print("已寫入", raw)'
   show "$P"; run "$P" ;;
7) banner "練習 2 後半：用程式檢查指揮是否過度派人"
   tip "派的人比「同一時間最多能並行的子任務數」還多，多出來的人只會閒著，還會讓溝通路徑變多。"
   P='import json
from collections import Counter
from pathlib import Path

COEF = 0.0025
out = Path("ch01/interactive")
out.mkdir(parents=True, exist_ok=True)
(out / "conductor_report.md").unlink(missing_ok=True)
raw = out / "conductor_raw.json"
FALLBACK = {
    "agents": 15,
    "subtasks": [{"id": "T1", "desc": "訂出命名規範與新架構藍圖", "depends_on": [], "mode": "sequential"}]
    + [{"id": "T" + str(i + 2), "desc": "重構模組 M" + str(i + 1), "depends_on": ["T1"], "mode": "parallel"} for i in range(11)]
    + [{"id": "T13", "desc": "整合測試與命名一致性檢查", "depends_on": ["T" + str(i + 2) for i in range(11)], "mode": "sequential"}],
    "shared_memory": "共用一份命名規範文件與設計決策紀錄（ADR）",
}
plan = None
if raw.exists():
    try:
        plan = json.loads(raw.read_text(encoding="utf-8"))
    except ValueError:
        plan = None
if isinstance(plan, dict):
    source = "第 6 步模型輸出"
else:
    plan = FALLBACK
    source = "內建範例（第 6 步沒有成功）"

try:
    agents = int(plan.get("agents", 0))
except (TypeError, ValueError):
    agents = 0
st = plan.get("subtasks") if isinstance(plan.get("subtasks"), list) else []
tasks = [t for t in st if isinstance(t, dict)]
deps = {}
for t in tasks:
    d = t.get("depends_on") or []
    if isinstance(d, str):
        d = [d]
    deps[str(t.get("id"))] = [str(x) for x in d]

missing = [(u, v) for u in deps for v in deps[u] if v not in deps]

color = {u: 0 for u in deps}
cycle = []
def dfs(u, stack):
    color[u] = 1
    stack.append(u)
    for v in deps[u]:
        if v not in color:
            continue
        if color[v] == 1:
            cycle.extend(stack[stack.index(v):] + [v])
            return True
        if color[v] == 0 and dfs(v, stack):
            return True
    stack.pop()
    color[u] = 2
    return False
has_cycle = any(color[u] == 0 and dfs(u, []) for u in list(deps))

critical, width = 0, 0
if tasks and not has_cycle:
    level = {}
    def lv(u):
        if u not in level:
            level[u] = 1 + max((lv(p) for p in deps[u] if p in deps), default=0)
        return level[u]
    for u in deps:
        lv(u)
    critical = max(level.values())
    width = max(Counter(level.values()).values())

over = width > 0 and agents > width
idle = agents - width if over else 0
cost_a = COEF * agents * (agents - 1) / 2
cost_w = COEF * width * (width - 1) / 2
extra = cost_a - cost_w if over else 0.0

KW = ("命名", "規範", "naming", "convention", "決策", "ADR", "decision", "紀錄", "記錄")
sm = str(plan.get("shared_memory", ""))
hits = [k for k in KW if k.lower() in sm.lower()]

print("資料來源：", source)
print("a. 依賴指向不存在的 id：", missing if missing else "無")
print("   是否有循環：", ("有 " + " -> ".join(cycle)) if has_cycle else "無")
print("b. 關鍵路徑長度：", critical, "回合；最大可並行寬度：", width)
print("c. 指揮派出", agents, "個代理；過度派人：", "是" if over else "否")
if over:
    print("   閒置代理 {} 個；協調成本每回合 {:.4f}（若只派 {} 人為 {:.4f}），多浪費 {:.4f} 單位".format(idle, cost_a, width, cost_w, extra))
print("d. 共用記憶命中關鍵字：", hits if hits else "無")

lines = []
if has_cycle:
    lines.append("依賴圖有循環，這份計畫無法排程，必須先修正。")
else:
    lines.append("關鍵路徑 {} 回合、最大並行寬度 {}，不是所有子任務都能同時做。".format(critical, width))
if over:
    lines.append("指揮派了 {} 個代理，超過寬度 {}：閒置 {} 人，協調成本每回合多吃 {:.4f} 單位。".format(agents, width, idle, extra))
else:
    lines.append("代理數沒有超過最大並行寬度，沒有過度派人。")
if hits:
    lines.append("共用記憶提到「{}」，用來對抗做到後面忘記規範的上下文丟失。".format("、".join(hits)))
else:
    lines.append("共用記憶沒有提到命名規範或決策紀錄，做到後面仍可能忘記規矩。")
lines.append("指揮本身也是單點：它要掌握整張依賴圖，上下文一樣會爆，誰當指揮、看多少東西是設計題。")

fence = chr(96) * 3
report = "# 第 1 章練習 2：指揮分工檢查報告\n\n資料來源：" + source + "\n\n## 模型原始輸出\n\n" + fence + "json\n" + json.dumps(plan, ensure_ascii=False, indent=2) + "\n" + fence + "\n\n## 四項檢查\n\n"
report += "- a. 依賴完整性：" + (str(missing) if missing else "全部指向存在的 id") + "；循環：" + ("有" if has_cycle else "無") + "\n"
report += "- b. 關鍵路徑 " + str(critical) + " 回合，最大可並行寬度 " + str(width) + "\n"
report += "- c. 代理數 " + str(agents) + "，過度派人：" + ("是，多浪費 {:.4f} 單位／回合".format(extra) if over else "否") + "\n"
report += "- d. 共用記憶關鍵字：" + ("、".join(hits) if hits else "無") + "\n\n## 結論\n\n" + "\n".join("- " + s for s in lines) + "\n"
(out / "conductor_report.md").write_text(report, encoding="utf-8")
print()
print("結論：")
for s in lines:
    print("  " + s)
print()
print("已寫入", out / "conductor_report.md")'
   show "$P"; run "$P" ;;
8) banner "總結：從單體到群體的五個重點"
   tip "問題從「模型夠不夠聰明」變成「多個代理怎麼分工與溝通」；而判準要能量測，本章每個結論都有一個數字撐著。"
   P='from pathlib import Path

points = [
    "單體有兩道邊界：Token 預算與上下文窗口（注意力經濟學）。記憶衰退讓單體從約 600 回合拖到約 1030 回合，11 個模組做到第 7 個產能就跌破 0.6；上下文蒸餾能拉回約 615 回合。",
    "協調成本是群體的第一個代價：溝通路徑 N(N-1)/2 平方成長，最佳 N 約 = 1/係數，淨產出在 N 約 = 2/係數+1 歸零（係數 0.02：最佳 50 人，100 人只剩 1）。",
    "臨界點不是常數：係數 0.0025 時 100 人內看不到臨界點，照規格跑出不符預期的結果也要照實記錄，再改參數找原因。",
    "分層把平方成長壓回接近線性：100 個代理從 4950 條路徑降到 420 條，最佳 N 從 50 推到 200 以上——這就是蟻群與交響樂的混合。",
    "指揮是單點、派人數有上限：代理數超過最大可並行寬度只會閒置並增加協調成本；成本交叉點、協作邊界、範式轉移三個判準都要變成可以追蹤的數字。",
]
print("第 1 章重點：")
for i, p in enumerate(points, 1):
    print(f"  {i}. {p}")
print()
print("本章產出檔案：")
for name in ("scaling.csv", "conductor_raw.json", "conductor_report.md"):
    p = Path("ch01/interactive") / name
    print("  {} {}".format("OK" if p.exists() else "缺", p))'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
