#!/bin/bash
# K902 第 3 章互動演練：agents——不到三百行的最小代理迴圈，用真模型驅動官方程式，一次跑一步
# 用法：bash ch03.sh <步驟 1-8>
# 呼叫模型：只有第 4 步會呼叫模型，最多 2 次（第 1 次要求工具、第 2 次回答；不重試；claude -p，透過 claude_cli_client），其餘步驟全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch03/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K902 第 3 章｜最小代理迴圈 agents　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "主角登場：agents 關鍵檔案表＋代理迴圈流程表"
   tip "這章是實跑：官方 agents 是純 Python，不改一行就能被真模型驅動。先用 qs_source 看清楚整個代理只是一個 while True 迴圈。注意 tool_dict 用 self.tools 全部建出來，伺服器端工具也在裡面。"
   P='import os, sys
sys.path.insert(0, os.getcwd())
from qs_source import root, read_text, grep

P = "agents/"
Q = chr(34)
print("官方 repo 資料夾：", root().name, "（只讀；不安裝依賴、不執行啟動指令）")
print()
files = [
    ("agent.py", "ModelConfig、Agent 類別、_agent_loop 代理迴圈"),
    ("tools/base.py", "Tool 基底：name、description、input_schema、to_dict、execute"),
    ("tools/think.py", "ThinkTool：什麼都不做，只回 Thinking complete!"),
    ("tools/web_search.py", "伺服器端工具設定（只有 to_dict）"),
    ("tools/code_execution.py", "伺服器端工具設定（只有 to_dict）"),
    ("utils/tool_util.py", "execute_tools：執行工具、把例外轉成 is_error"),
    ("utils/history_util.py", "MessageHistory：記 token、截斷、加快取標記"),
    ("utils/connections.py", "MCP 連線；檔案開頭就 from mcp import"),
]
print("【表 1】關鍵檔案")
print("{:<26} | {:>4} | {:<10} | {}".format("檔案", "行數", "有 execute", "負責什麼"))
print("-" * 100)
for rel, desc in files:
    text = read_text(P + rel)
    has_exec = "有" if grep(P + rel, "def execute[(]") else "-"
    print("{:<26} | {:>4} | {:<10} | {}".format(rel, len(text.splitlines()), has_exec, desc))
print()

AG = P + "agent.py"
flow = [
    ("把使用者輸入放進歷史", "add_message[(]" + Q + "user" + Q + ", user_input"),
    ("用 self.tools 全部建 tool_dict", "tool_dict = [{]"),
    ("進入 while True（沒有輪數上限）", "while True:"),
    ("每輪先截斷歷史", "self[.]history[.]truncate[(][)]"),
    ("預設 beta 標頭", "code-execution-2025-05-22"),
    ("呼叫模型", "self[.]client[.]messages[.]create[(]"),
    ("挑出 tool_use 區塊", "for block in response[.]content if block[.]type"),
    ("assistant 回覆放進歷史", Q + "assistant" + Q + ", response[.]content"),
    ("有 tool_use：判斷", "if tool_calls:"),
    ("有 tool_use：執行工具", "tool_results = await execute_tools[(]"),
    ("工具結果用 user 角色放回", "add_message[(]" + Q + "user" + Q + ", tool_results"),
    ("沒有 tool_use：結束迴圈", "return response"),
    ("run() 用 asyncio.run", "asyncio[.]run[(]"),
]
print("【表 2】_agent_loop 的流程（行號從 agent.py grep 出來）")
print("{:>2} | {:<30} | {:>4} | {}".format("#", "做什麼", "行號", "原文"))
print("-" * 110)
for k, (what, pat) in enumerate(flow, 1):
    hits = grep(AG, pat)
    if hits:
        no, line = hits[0]
        print("{:>2} | {:<30} | {:>4} | {}".format(k, what, no, line.strip()[:70]))
    else:
        print("{:>2} | {:<30} | {:>4} | {}".format(k, what, "-", "找不到"))
print()
print("ModelConfig 預設值：")
for no, line in grep(AG, "(model: str|max_tokens: int|context_window_tokens: int) = "):
    print("  第 {} 行：{}".format(no, line.strip()))
print()
print("agent.py 裡 stop_reason 出現", len(grep(AG, "stop_reason")), "次；max_turns 出現", len(grep(AG, "max_turns")), "次")
print("→ 迴圈只看「這一輪有沒有 tool_use」，不看 stop_reason，也沒有最大輪數。")'
   show "$P"; run "$P" ;;
2) banner "練習 1 之一：匯入準備與自己寫的 StockTool（離線）"
   tip "install() 讓 import anthropic 拿到轉接層；install_mcp_stub() 在沒裝 mcp 時放空殼，因為 connections.py 一開頭就 from mcp import。這一步先離線測 StockTool，順便看一個陷阱：工具自己丟的 KeyError 會被 tool_util 當成「找不到工具」。"
   P='import asyncio, json, os, sys
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client, qs_source
claude_cli_client.install()
print("install() 之後 sys.modules 裡的 anthropic 就是轉接層：", sys.modules["anthropic"] is claude_cli_client)
stub = claude_cli_client.install_mcp_stub()
print("install_mcp_stub() 回傳：", stub, "（True＝本機沒裝 mcp，已放空殼；False＝本機已有 mcp 套件）")
sys.path.insert(0, str(qs_source.root()))
import agents.agent as official
from agents.agent import Agent
from agents.tools.base import Tool
from agents.utils.tool_util import execute_tools
print("匯入成功：", Agent.__module__ + ".Agent", "與", Tool.__module__ + ".Tool")
print("官方 agent.py 拿到的 Anthropic 是轉接層：", official.Anthropic is claude_cli_client.Anthropic)
print()

STOCK = {"A-100": 42, "B-200": 0, "C-300": 7}

class StockTool(Tool):
    def __init__(self):
        super().__init__(
            name="check_stock",
            description="查詢倉庫裡某個料號的庫存數量",
            input_schema={
                "type": "object",
                "properties": {"part_no": {"type": "string", "description": "料號，例如 A-100"}},
                "required": ["part_no"],
            },
        )

    async def execute(self, part_no: str) -> str:
        if part_no not in STOCK:
            raise KeyError(part_no)
        return str(STOCK[part_no])

tool = StockTool()
print("StockTool.to_dict()（這就是送給模型的工具定義）：")
print(json.dumps(tool.to_dict(), ensure_ascii=False, indent=2))
print()
print("【直接呼叫 execute】")
for p in ("A-100", "B-200", "C-300", "Z-999"):
    try:
        print("  part_no={:<6} → {}".format(p, asyncio.run(tool.execute(part_no=p))))
    except KeyError as exc:
        print("  part_no={:<6} → 丟出 KeyError（{}）".format(p, exc))
print()
print("【經過官方 execute_tools】")
calls = [
    SimpleNamespace(id="toolu_1", name="check_stock", input={"part_no": "A-100"}),
    SimpleNamespace(id="toolu_2", name="check_stock", input={"part_no": "Z-999"}),
]
for r in asyncio.run(execute_tools(calls, {"check_stock": tool})):
    print("  {} | content={} | is_error={}".format(r["tool_use_id"], r["content"], r.get("is_error", False)))
print()
for no, line in qs_source.grep("agents/utils/tool_util.py", "except KeyError"):
    print("原因：tool_util.py 第 {} 行 {} 接住所有 KeyError，包含工具自己丟的。".format(no, line.strip()))
print("→ Z-999 明明是「料號不存在」，模型卻會看到「工具不存在」。自己的工具最好丟別種例外，或直接回傳說明文字。")'
   show "$P"; run "$P" ;;
3) banner "練習 1 之二：建立官方 Agent，看模型實際會收到什麼（離線）"
   tip "還不呼叫模型。先把 Agent 建好，看 _prepare_message_params 組出來的參數，再看轉接層怎麼把工具定義寫進系統提示、怎麼解析 <tool_use> 標記。這是「用提示詞模擬的工具呼叫」，不是 API 原生 tool use；伺服器端工具會被忽略。"
   P='import asyncio, json, os, sys
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client, qs_source
claude_cli_client.install()
claude_cli_client.install_mcp_stub()
sys.path.insert(0, str(qs_source.root()))
from agents.agent import Agent, ModelConfig
from agents.tools.base import Tool
from agents.tools.web_search import WebSearchServerTool

STOCK = {"A-100": 42, "B-200": 0, "C-300": 7}

class StockTool(Tool):
    def __init__(self):
        super().__init__(
            name="check_stock",
            description="查詢倉庫裡某個料號的庫存數量",
            input_schema={
                "type": "object",
                "properties": {"part_no": {"type": "string", "description": "料號，例如 A-100"}},
                "required": ["part_no"],
            },
        )

    async def execute(self, part_no: str) -> str:
        if part_no not in STOCK:
            raise KeyError(part_no)
        return str(STOCK[part_no])

SYSTEM = "你是倉管助理。回答庫存問題前一定要先用 check_stock 查，不可以猜。用繁體中文回答。"
QUESTION = "料號 A-100 還有幾個？夠不夠出貨 40 個？"

cfg = ModelConfig()
print("ModelConfig 預設：model =", cfg.model, "｜max_tokens =", cfg.max_tokens, "｜context_window_tokens =", cfg.context_window_tokens)
agent = Agent(name="倉管助理", system=SYSTEM, tools=[StockTool()], mcp_servers=[], verbose=True,
              client=claude_cli_client.Anthropic())
est = (len(SYSTEM) + len("test")) // 4
print("系統提示字數：", len(SYSTEM), "；轉接層 count_tokens 估 ({} + 4) // 4 = {}，官方再減 1".format(len(SYSTEM), est))
print("history.total_tokens（初始）：", agent.history.total_tokens)
print()

asyncio.run(agent.history.add_message("user", QUESTION))
params = agent._prepare_message_params()
print("第 1 輪送給 messages.create 的參數鍵：", list(params.keys()))
print("messages（已由 format_for_api 加上 cache_control）：")
print("  " + json.dumps(params["messages"], ensure_ascii=False))
print("tools：")
print("  " + json.dumps(params["tools"], ensure_ascii=False))
for no, line in qs_source.grep("agents/agent.py", "code-execution-2025-05-22"):
    print("另外帶 extra_headers（agent.py 第 {} 行）：{}　← 轉接層會忽略".format(no, line.strip()))
print()

client_tools, ignored = claude_cli_client.split_tools(params["tools"] + [WebSearchServerTool(max_uses=5).to_dict()])
print("假設再掛一個 WebSearchServerTool(max_uses=5)：")
print("  轉接層可模擬的自訂工具：", [t["name"] for t in client_tools])
print("  轉接層會忽略的伺服器端工具：", ignored)
print()
print("=== 轉接層實際送給 claude -p 的系統提示 ===")
print(claude_cli_client.system_text(params["system"], client_tools[:1]))
print("=== 第 1 次呼叫送進 stdin 的內容 ===")
print(claude_cli_client.flatten_messages(params["messages"]))
print()
demo = [
    {"role": "user", "content": [{"type": "text", "text": QUESTION}]},
    {"role": "assistant", "content": [SimpleNamespace(type="tool_use", id="toolu_demo", name="check_stock", input={"part_no": "A-100"})]},
    {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "toolu_demo", "content": "42"}]},
]
print("=== 示意：若第 1 次要求了工具，第 2 次呼叫的 stdin 會長這樣（每次都是全新的 claude -p 行程，歷史攤平重送） ===")
print(claude_cli_client.flatten_messages(demo))
print()
tag = "<tool_use>" + json.dumps({"name": "check_stock", "input": {"part_no": "A-100"}}, ensure_ascii=False) + "</tool_use>"
cases = [
    ("照格式", "我先查庫存。" + tag),
    ("沒照格式", "A-100 大概還有 40 個左右。"),
    ("工具名不在清單", tag.replace("check_stock", "rm")),
]
print("【轉接層 parse_reply 怎麼解析模型回覆】")
for label, text in cases:
    blocks = claude_cli_client.parse_reply(text, {"check_stock"})
    calls = [(b.name, b.input) for b in blocks if b.type == "tool_use"]
    print("  {:<8} → block 種類 {}；tool_use {}".format(label, [b.type for b in blocks], calls if calls else "無（迴圈會直接結束）"))'
   show "$P"; run "$P" ;;
4) banner "練習 1 之三：真模型驅動官方 Agent，跑完一次工具迴圈"
   tip "這一步會呼叫模型最多 2 次（claude -p；第 1 次要求 check_stock、第 2 次回答；不重試，模型沒照格式呼叫工具時照實說明後結束），每次約 5～15 秒。模型是真的；工具呼叫是用提示詞模擬的，倉庫字典是假的環境。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
os.environ["K902_CLI_MAX_CALLS"] = "2"  # 保險：本行程最多呼叫 claude -p 2 次，官方迴圈沒有輪數上限
import claude_cli_client, qs_source
claude_cli_client.install()
print("install_mcp_stub() 回傳：", claude_cli_client.install_mcp_stub())
sys.path.insert(0, str(qs_source.root()))
from agents.agent import Agent
from agents.tools.base import Tool

out = Path("ch03/interactive")
out.mkdir(parents=True, exist_ok=True)
log_path = out / "run_agent_log.md"
json_path = out / "run_agent.json"
log_path.unlink(missing_ok=True)
json_path.unlink(missing_ok=True)

# 假環境：倉庫庫存是寫死的字典，不是真的倉儲系統
STOCK = {"A-100": 42, "B-200": 0, "C-300": 7}

class StockTool(Tool):
    def __init__(self):
        super().__init__(
            name="check_stock",
            description="查詢倉庫裡某個料號的庫存數量",
            input_schema={
                "type": "object",
                "properties": {"part_no": {"type": "string", "description": "料號，例如 A-100"}},
                "required": ["part_no"],
            },
        )

    async def execute(self, part_no: str) -> str:
        if part_no not in STOCK:
            raise KeyError(part_no)
        return str(STOCK[part_no])

SYSTEM = "你是倉管助理。回答庫存問題前一定要先用 check_stock 查，不可以猜。用繁體中文回答。"
QUESTION = "料號 A-100 還有幾個？夠不夠出貨 40 個？"
MAX_CALLS = 2

def fld(block, name, default=None):
    if isinstance(block, dict):
        return block.get(name, default)
    return getattr(block, name, default)

def blocks_of(message):
    content = message.get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    return list(content or [])

def block_rows(messages):
    rows = []
    for no, m in enumerate(messages, 1):
        for b in blocks_of(m):
            t = fld(b, "type")
            if t == "tool_use":
                detail = "name=" + str(fld(b, "name")) + "　input=" + json.dumps(fld(b, "input", {}), ensure_ascii=False)
            elif t == "tool_result":
                detail = "content=" + str(fld(b, "content")) + "　is_error=" + str(bool(fld(b, "is_error", False)))
            else:
                detail = str(fld(b, "text", "")).replace("\n", " ")[:80]
            rows.append([no, m.get("role"), t, detail])
    return rows

def has_tool_use(messages):
    return any(m.get("role") == "assistant" and fld(b, "type") == "tool_use" for m in messages for b in blocks_of(m))

print("假環境：倉庫庫存是寫死的字典 {A-100: 42, B-200: 0, C-300: 7}；模型是真的（claude -p），工具呼叫用提示詞模擬。")
print()
print("=== agent.run()（只跑一次、不重試；每次 claude -p 約 5～15 秒） ===")
agent = Agent(name="倉管助理", system=SYSTEM, tools=[StockTool()], mcp_servers=[], verbose=True,
              client=claude_cli_client.Anthropic())
final, error = None, None
try:
    final = agent.run(QUESTION)
except (claude_cli_client.APIError, RuntimeError, ValueError) as exc:
    error = type(exc).__name__ + "：" + str(exc)
except Exception as exc:
    error = "其他例外 " + type(exc).__name__ + "：" + str(exc)
first_used = has_tool_use(agent.history.messages)
attempts = [{"attempt": 1, "used_tool": first_used, "error": error,
             "messages": len(agent.history.messages), "calls_so_far": claude_cli_client.calls_made()}]
print()
if error:
    print("這次呼叫沒有順利跑完，原因：" + error)
if not first_used and error is None:
    print("這次模型沒有照格式呼叫工具（回覆裡沒有 tool_use），這是「用提示詞模擬工具呼叫」的限制；官方迴圈看不到 tool_use 就直接結束。本步驟不重試（呼叫上限 {} 次），拿到的內容照樣列在下面、照實存檔。".format(MAX_CALLS))

messages = agent.history.messages
rows = block_rows(messages)
final_text = ""
if final is not None:
    final_text = "\n".join(str(fld(b, "text", "")) for b in final.content if fld(b, "type") == "text")
else:
    for m in reversed(messages):
        if m.get("role") == "assistant":
            final_text = "\n".join(str(fld(b, "text", "")) for b in blocks_of(m) if fld(b, "type") == "text")
            break
calls = claude_cli_client.calls_made()
used = has_tool_use(messages)

print()
print("【訊息歷史 agent.history.messages】")
print("{:>4} | {:<9} | {:<11} | {}".format("序號", "role", "type", "內容"))
print("-" * 100)
for no, role, t, detail in rows:
    print("{:>4} | {:<9} | {:<11} | {}".format(no, role, t, detail))
print()
print("訊息則數：", len(messages), "（預期 4）")
print("calls_made()：", calls, "（預期 2；上限 {}）".format(MAX_CALLS))
print("有沒有 tool_use：", used)
print("最終回覆含「42」：", "42" in final_text, "；含「夠」：", "夠" in final_text)
print("最終回覆：")
print(final_text if final_text else "（沒有拿到文字回覆）")

record = {"question": QUESTION, "system": SYSTEM, "attempts": attempts, "calls": calls, "message_count": len(messages),
          "used_tool": used, "rows": rows, "final_text": final_text, "error": error}
json_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
md = ["# 第 3 章練習 1：官方 Agent 由真模型驅動的工具迴圈紀錄", "",
      "- 假環境：庫存字典 A-100=42、B-200=0、C-300=7；模型是真的（claude -p），工具呼叫用提示詞模擬。",
      "- 問題：" + QUESTION, "- calls_made()：" + str(calls), "- 訊息則數：" + str(len(messages)),
      "- 有沒有 tool_use：" + str(used), "- 錯誤：" + (error or "無"), "",
      "| 序號 | role | type | 內容 |", "| --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} |".format(no, role, t, detail.replace("|", "／")) for no, role, t, detail in rows]
md += ["", "## 最終回覆", "", final_text if final_text else "（沒有拿到文字回覆）"]
log_path.write_text("\n".join(md) + "\n", encoding="utf-8")
print()
print("已寫入", log_path, "與", json_path)'
   show "$P"; run "$P" ;;
5) banner "練習 1 之四：把訊息歷史逐則對回 agent.py 的行號（離線）"
   tip "不再呼叫模型。讀第 4 步的 run_agent.json；找不到就改用內建範例（照實驗結果編的 4 則歷史）。每一則訊息都能對到 _agent_loop 的某一行，迴圈的結束條件只有「這一輪沒有 tool_use」。"
   P='import json, os, sys
from pathlib import Path
sys.path.insert(0, os.getcwd())
from qs_source import grep

Q = chr(34)
AG = "agents/agent.py"
SAMPLE = {
    "calls": 2, "message_count": 4, "used_tool": True,
    "final_text": "料號 A-100 目前庫存 42 個，出貨 40 個是夠的，出貨後還剩 2 個。",
    "rows": [
        [1, "user", "text", "料號 A-100 還有幾個？夠不夠出貨 40 個？"],
        [2, "assistant", "text", "我先用 check_stock 查詢 A-100 的庫存。"],
        [2, "assistant", "tool_use", "name=check_stock　input=" + json.dumps({"part_no": "A-100"})],
        [3, "user", "tool_result", "content=42　is_error=False"],
        [4, "assistant", "text", "料號 A-100 目前庫存 42 個，出貨 40 個是夠的，出貨後還剩 2 個。"],
    ],
}
src = "內建範例（找不到第 4 步的 run_agent.json）"
data = SAMPLE
p = Path("ch03/interactive/run_agent.json")
if p.exists():
    try:
        loaded = json.loads(p.read_text(encoding="utf-8"))
        if isinstance(loaded, dict) and isinstance(loaded.get("rows"), list) and loaded["rows"]:
            data, src = loaded, "ch03/interactive/run_agent.json（第 4 步的真模型紀錄）"
    except ValueError:
        pass
print("資料來源：", src)
print()

def ln(pat):
    hits = grep(AG, pat)
    return str(hits[0][0]) if hits else "?"

L = {
    "user_input": ln("add_message[(]" + Q + "user" + Q + ", user_input"),
    "create": ln("self[.]client[.]messages[.]create[(]"),
    "assistant": ln(Q + "assistant" + Q + ", response[.]content"),
    "if_tools": ln("if tool_calls:"),
    "exec": ln("tool_results = await execute_tools[(]"),
    "tool_results": ln("add_message[(]" + Q + "user" + Q + ", tool_results"),
    "ret": ln("return response"),
}

msgs = {}
for no, role, t, detail in data["rows"]:
    msgs.setdefault(no, {"role": role, "types": []})["types"].append(t)

print("{:>4} | {:<9} | {:<22} | {}".format("序號", "role", "blocks", "對應 agent.py 的哪一步"))
print("-" * 120)
call_no = 0
for no in sorted(msgs):
    m = msgs[no]
    types = m["types"]
    if m["role"] == "assistant":
        call_no += 1
        where = "第 {} 次 messages.create（第 {} 行）→ 第 {} 行放進歷史".format(call_no, L["create"], L["assistant"])
        if "tool_use" in types:
            where += " → 第 {} 行 if tool_calls 成立 → 第 {} 行 execute_tools".format(L["if_tools"], L["exec"])
        else:
            where += " → 沒有 tool_use，第 {} 行 return response，迴圈結束".format(L["ret"])
    elif "tool_result" in types:
        where = "第 {} 行：工具結果用 user 角色放回歷史，回到 while True 再呼叫一次".format(L["tool_results"])
    else:
        where = "第 {} 行：把使用者問題放進歷史".format(L["user_input"])
    print("{:>4} | {:<9} | {:<22} | {}".format(no, m["role"], "+".join(types), where))
print()

final_text = str(data.get("final_text", ""))
n_msgs = int(data.get("message_count", len(msgs)))
calls = int(data.get("calls", call_no))
print("【練習 1 觀察重點】")
print("  訊息歷史剛好 4 則：", "是" if n_msgs == 4 else "否（實際 {} 則，照實記錄）".format(n_msgs))
print("  calls_made() 是 2：", "是" if calls == 2 else "否（實際 {} 次，照實記錄）".format(calls))
print("  有 tool_use：", "是" if data.get("used_tool") else "否（提示詞模擬工具呼叫的限制）")
print("  最終回覆用到 42：", "是" if "42" in final_text else "否", "；提到「夠」：", "是" if "夠" in final_text else "否")
print("  最終回覆：", final_text[:120] if final_text else "（無）")
print()
print("第 2 次呼叫時，轉接層把第 1～3 則攤平成逐字稿整份重送：每次都是全新的 claude -p 行程，歷史越長、每輪送得越多。")
print("agent.py 裡 stop_reason 出現", len(grep(AG, "stop_reason")), "次 → 結束條件只有「這一輪沒有 tool_use」。")'
   show "$P"; run "$P" ;;
6) banner "練習 2 之一：A 段——離線實跑 execute_tools 的錯誤處理"
   tip "不呼叫模型。三個假的工具呼叫：think 正常、boom 一定丟 ValueError、not_exist 不在工具清單。官方 execute_tools 不會中斷，而是把錯誤包成帶 is_error 的 tool_result 交還模型。"
   P='import asyncio, json, os, sys
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client, qs_source
claude_cli_client.install()
claude_cli_client.install_mcp_stub()
sys.path.insert(0, str(qs_source.root()))
from agents.utils.tool_util import execute_tools
from agents.utils.history_util import MessageHistory
from agents.tools.think import ThinkTool
from agents.tools.base import Tool

out = Path("ch03/interactive")
out.mkdir(parents=True, exist_ok=True)
a_path = out / "offline_part_a.md"
a_path.unlink(missing_ok=True)

class BoomTool(Tool):
    def __init__(self):
        super().__init__(name="boom", description="一定會壞掉的工具", input_schema={"type": "object", "properties": {}})

    async def execute(self, **kwargs) -> str:
        raise ValueError("壞掉了")

tool_dict = {"think": ThinkTool(), "boom": BoomTool()}
calls = [
    SimpleNamespace(id="toolu_a", name="think", input={"thought": "先想一下"}),
    SimpleNamespace(id="toolu_b", name="boom", input={}),
    SimpleNamespace(id="toolu_c", name="not_exist", input={}),
]
print("工具清單 tool_dict 的鍵：", list(tool_dict.keys()))
print("假的工具呼叫：", [(c.id, c.name, c.input) for c in calls])
print()

par = asyncio.run(execute_tools(calls, tool_dict))
seq = asyncio.run(execute_tools(calls, tool_dict, parallel=False))

def cell(r):
    return str(r["is_error"]) if "is_error" in r else "-（沒有這個欄位）"

print("【A 段】execute_tools（預設 parallel=True）")
print("{:<9} | {:<32} | {}".format("tool_use_id", "content", "is_error"))
print("-" * 70)
for r in par:
    print("{:<9} | {:<32} | {}".format(r["tool_use_id"], r["content"], cell(r)))
print()
print("parallel=False 的結果與平行版完全相同：", par == list(seq))
print("結果順序與呼叫順序一致：", [r["tool_use_id"] for r in par])
print("程式沒有因為 boom 與 not_exist 而中斷。")
print()
print("對應原始碼（agents/utils/tool_util.py）：")
for pat in ("execute[(][*][*]call[.]input[)]", "except KeyError", "except Exception", "parallel: bool = True", "asyncio[.]gather"):
    for no, line in qs_source.grep("agents/utils/tool_util.py", pat)[:1]:
        print("  第 {:>2} 行：{}".format(no, line.strip()))

md = ["## A 段：execute_tools 的錯誤處理", "", "| tool_use_id | content | is_error |", "| --- | --- | --- |"]
md += ["| {} | {} | {} |".format(r["tool_use_id"], r["content"], cell(r)) for r in par]
md += ["", "- parallel=False 結果相同：" + str(par == list(seq))]
a_path.write_text("\n".join(md) + "\n", encoding="utf-8")
print()
print("已寫入", a_path)'
   show "$P"; run "$P" ;;
7) banner "練習 2 之二：B 段歷史截斷＋C 段快取標記，存成 offline_parts.md"
   tip "不呼叫模型。假 client 的 count_tokens 故意丟 RuntimeError，逼官方程式用「系統提示字數除以 4」估算（400 個 s → 100.0）。上限設 1000，看第 4 輪超過後最舊的一對被丟掉、第一則換成截斷提示；截斷不做摘要，資訊就是不見了。"
   P='import asyncio, json, os, sys
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.getcwd())
import claude_cli_client, qs_source
claude_cli_client.install()
claude_cli_client.install_mcp_stub()
sys.path.insert(0, str(qs_source.root()))
from agents.utils.tool_util import execute_tools
from agents.utils.history_util import MessageHistory
from agents.tools.think import ThinkTool
from agents.tools.base import Tool

out = Path("ch03/interactive")
out.mkdir(parents=True, exist_ok=True)
parts_path = out / "offline_parts.md"
parts_path.unlink(missing_ok=True)

class FakeMessages:
    def count_tokens(self, **kwargs):
        raise RuntimeError("假 client：故意失敗，逼官方程式改用字數除以 4")

class FakeClient:
    def __init__(self):
        self.messages = FakeMessages()

print("假環境：FakeClient 不連任何服務，count_tokens 一律丟 RuntimeError。")
h = MessageHistory(model="x", system="s" * 400, context_window_tokens=1000, client=FakeClient())
est_hits = qs_source.grep("agents/utils/history_util.py", "len[(]self[.]system[)] / 4")
est_no = est_hits[0][0] if est_hits else "?"
print("初始 total_tokens：", h.total_tokens, "（400 / 4，history_util.py 第 {} 行的估算）".format(est_no))
print()
print("【B 段】每輪 user + assistant（input_tokens = 加入前 total_tokens + 100，output_tokens = 150），再 truncate()")
print("{:>4} | {:>8} | {:>20} | {:>14} | {}".format("輪次", "訊息則數", "截斷前 total_tokens", "total_tokens", "第一則訊息前 30 字"))
print("-" * 100)
b_rows = []
for i in range(1, 7):
    asyncio.run(h.add_message("user", f"第{i}輪問題"))
    cum = h.total_tokens + 100
    asyncio.run(h.add_message("assistant", f"第{i}輪回答", usage=SimpleNamespace(input_tokens=cum, output_tokens=150)))
    before = h.total_tokens
    h.truncate()
    first = h.messages[0]["content"][0]["text"][:30]
    b_rows.append((i, len(h.messages), before, h.total_tokens, first))
    print("{:>4} | {:>8} | {:>20} | {:>14} | {}".format(i, len(h.messages), before, h.total_tokens, first))
print()
print("最後的 message_tokens：", h.message_tokens)
print("最後留下的訊息：", [(m["role"], m["content"][0]["text"]) for m in h.messages])
for no, line in qs_source.grep("agents/utils/history_util.py", "TRUNCATION_NOTICE_TOKENS = |Earlier history has been truncated"):
    print("  history_util.py 第 {} 行：{}".format(no, line.strip()))
print()

api = h.format_for_api()
tagged = [k for k, m in enumerate(api, 1) if any("cache_control" in b for b in m["content"])]
print("【C 段】format_for_api() 最後一則的 content：")
print("  " + json.dumps(api[-1]["content"], ensure_ascii=False))
print("帶 cache_control 的訊息序號：", tagged, "（共", len(api), "則）")
print("原本的 h.messages 最後一則有沒有被改成帶 cache_control：", any("cache_control" in b for b in h.messages[-1]["content"]))
print()

a_file = out / "offline_part_a.md"
a_lines = []
if a_file.exists():
    a_lines = a_file.read_text(encoding="utf-8").splitlines()
if a_lines:
    print("（合併檔案用）A 段直接讀第 6 步的", a_file)
else:
    class BoomTool(Tool):
        def __init__(self):
            super().__init__(name="boom", description="一定會壞掉的工具", input_schema={"type": "object", "properties": {}})

        async def execute(self, **kwargs) -> str:
            raise ValueError("壞掉了")

    calls = [
        SimpleNamespace(id="toolu_a", name="think", input={"thought": "先想一下"}),
        SimpleNamespace(id="toolu_b", name="boom", input={}),
        SimpleNamespace(id="toolu_c", name="not_exist", input={}),
    ]
    td = {"think": ThinkTool(), "boom": BoomTool()}
    a_par = asyncio.run(execute_tools(calls, td))
    a_seq = asyncio.run(execute_tools(calls, td, parallel=False))
    print("（合併檔案用）找不到第 6 步的 offline_part_a.md，A 段改為離線重跑一次，parallel 與依序結果相同：", a_par == list(a_seq))
    a_lines = ["## A 段：execute_tools 的錯誤處理", "", "| tool_use_id | content | is_error |", "| --- | --- | --- |"]
    a_lines += ["| {} | {} | {} |".format(r["tool_use_id"], r["content"], r.get("is_error", "-")) for r in a_par]
    a_lines += ["", "- parallel=False 結果相同：" + str(a_par == list(a_seq))]

md = ["# 第 3 章練習 2：離線實跑工具錯誤處理與歷史截斷", "",
      "- 全部離線，不呼叫模型；FakeClient 是假的，count_tokens 故意丟 RuntimeError。", ""]
md += a_lines
md += ["", "## B 段：MessageHistory 截斷（context_window_tokens=1000）", "", "- 初始 total_tokens：100.0", "",
       "| 輪次 | 訊息則數 | 截斷前 total_tokens | total_tokens | 第一則前 30 字 |", "| --- | --- | --- | --- | --- |"]
md += ["| {} | {} | {} | {} | {} |".format(*r) for r in b_rows]
md += ["", "## C 段：format_for_api 的快取標記", "", "- 最後一則 content：" + json.dumps(api[-1]["content"], ensure_ascii=False),
       "- 帶 cache_control 的訊息序號：" + str(tagged) + "（共 " + str(len(api)) + " 則）"]
parts_path.write_text("\n".join(md) + "\n", encoding="utf-8")
print("已寫入", parts_path)'
   show "$P"; run "$P" ;;
8) banner "總結：本章 6 個重點與產出檔案"
   tip "這份程式是教學用的參考實作，不是 SDK：沒有輪數上限、重試與權限控管，拿去用之前要自己補。演練裡模型是真的，但工具呼叫是用提示詞模擬的，伺服器端工具與 MCP 在這裡都不能用。"
   P='import json
from pathlib import Path

points = [
    "代理就是一個 while True 迴圈（agent.py 第 100 行）：呼叫模型 → 回覆裡有 tool_use 就執行工具、用 user 角色放回歷史 → 再呼叫；沒有 tool_use 就 return（第 151 行）。程式不看 stop_reason，也沒有輪數上限，所以演練用 K902_CLI_MAX_CALLS 當保險。",
    "工具只要名稱、說明、JSON Schema 與一個 async execute()；ThinkTool 只回 Thinking complete!，作用是讓模型把想法留在歷史裡。本機、MCP、伺服器端工具對模型來說都是工具清單裡的一項，差別在誰執行。",
    "工具出錯不會讓程式停下：execute_tools 把例外包成 Error executing tool: …、找不到工具包成 Tool … not found，都帶 is_error 交還模型；預設用 asyncio.gather 平行執行。注意第 17 行接住所有 KeyError，工具自己丟的 KeyError 也會被誤報成找不到工具。",
    "伺服器端工具也在 tool_dict 裡（第 98 行用 self.tools 全部建）；它們沒有 execute()，萬一在本機被呼叫會丟例外，同樣變成 is_error 的工具結果。",
    "MessageHistory 是代理的另一半：超過 context_window_tokens 就丟最舊的一對訊息、把新的第一則換成 [Earlier history has been truncated.]（記 25 token），不做摘要；format_for_api 只替最後一則加 cache_control。長任務要把狀態寫進檔案（第 10 章）。",
    "演練用 claude_cli_client 取代 anthropic、用空殼頂替 mcp，官方 agent.py 不改一行就由真模型驅動；但自訂工具是提示詞模擬的（模型偶爾不照格式）、每次呼叫都是全新 claude -p 行程、extra_headers 與伺服器端工具被忽略，要照實說。",
]
print("第 3 章重點：")
for i, p in enumerate(points, 1):
    print("  {}. {}".format(i, p))
print()
calls_note = "第 4 步沒有留下紀錄"
rp = Path("ch03/interactive/run_agent.json")
if rp.exists():
    try:
        rec = json.loads(rp.read_text(encoding="utf-8"))
        calls_note = "第 4 步呼叫模型 {} 次、訊息 {} 則、有 tool_use：{}".format(rec.get("calls"), rec.get("message_count"), rec.get("used_tool"))
    except ValueError:
        calls_note = "run_agent.json 讀不懂"
print("本章模型呼叫：", calls_note, "（本章最多 2 次，只有第 4 步呼叫；規則上限：一步 2 次、整章 4 次）")
print()
print("本章產出檔案：")
for name in ("run_agent_log.md", "run_agent.json", "offline_part_a.md", "offline_parts.md"):
    p = Path("ch03/interactive") / name
    print("  {} {}".format("OK" if p.exists() else "缺", p))'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
