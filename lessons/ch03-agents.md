# 第 3 章　agents：不到三百行的最小代理迴圈

> 來源：`~/workspace/claude-quickstarts/agents`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：實跑

## 一、這個專案做什麼

前兩章的專案都是「問一次、答一次」的聊天應用。這一章開始進入代理：模型在一個迴圈裡反覆決定要不要用工具，直到它認為可以回答為止。

`agents` 是官方寫來教學的最小代理實作。README 開頭就聲明它「不是 SDK」，而是把關鍵觀念寫成參考程式，核心邏輯不到 300 行，刻意不放上線需要的功能（README 沒有列舉是哪些；從程式看，沒有重試、沒有權限控管，記錄只有 `verbose` 開啟時的 `print`）。它對應 Anthropic 的文章 Building effective agents，要說明的只有一句話：複雜的代理行為，可以從「模型在迴圈裡使用工具」這個簡單結構長出來。

專案只有三塊：

- `agent.py`：管理和 Claude API 的往來與工具執行。
- `tools/`：工具實作。README 只寫本機（native）工具與 MCP 工具兩種，實際目錄裡還有伺服器端工具。
- `utils/`：訊息歷史管理、MCP 連線（README 只列這兩項，實際還有工具執行的 `tool_util.py`）。

## 二、架構與資料流

```text
使用者輸入
    │
    ▼
┌──────────────────────────────────────────────┐
│ Agent.run()  →  run_async()                   │
│   1. setup_mcp_connections() 把 MCP 伺服器的   │
│      工具包成 MCPTool，加進 self.tools         │
│   2. 進入 _agent_loop()                        │
└──────────────────────────────────────────────┘
    │
    ▼
┌─────────────── _agent_loop（while True）───────────────┐
│ history.add_message("user", 輸入)                       │
│      │                                                  │
│      ▼                                                  │
│ history.truncate()   ← 超過 context 上限就丟最舊的一對   │
│      │                                                  │
│      ▼                                                  │
│ client.messages.create(model, system, messages, tools)  │
│      │                                                  │
│      ▼                                                  │
│ history.add_message("assistant", 回覆, usage)           │
│      │                                                  │
│      ├─ 回覆裡有 tool_use ──► execute_tools()（預設平行）│
│      │                         │                        │
│      │                         ▼                        │
│      │        history.add_message("user", tool_result)  │
│      │                         │                        │
│      │                         └──► 回到 truncate()     │
│      │                                                  │
│      └─ 沒有 tool_use ──► return 回覆（迴圈結束）        │
└────────────────────────────────────────────────────────┘
```

迴圈的結束條件只有一個：模型這一輪沒有要求任何工具。程式裡沒有最大輪數，也沒有逾時。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `agent.py` | 169 | `ModelConfig`、`Agent` 類別、`_agent_loop` 代理迴圈 |
| `tools/base.py` | 27 | `Tool` 基底類別：`name`、`description`、`input_schema`、`to_dict()`、`execute()` |
| `tools/think.py` | 32 | `ThinkTool`：不做任何外部動作，只回 `Thinking complete!` |
| `tools/file_tools.py` | 277 | `FileReadTool`（`file_read`）、`FileWriteTool`（`file_write`） |
| `tools/web_search.py`、`tools/code_execution.py` | 37、18 | 伺服器端工具的設定物件，只有 `to_dict()`，沒有 `execute()` |
| `tools/mcp_tool.py`、`tools/calculator_mcp.py` | 39、55 | 把 MCP 伺服器的工具包成 `Tool`；一個示範用的計算機 MCP 伺服器 |
| `utils/history_util.py` | 124 | `MessageHistory`：記 token、截斷舊訊息、加 prompt caching 標記 |
| `utils/tool_util.py` | 39 | `execute_tools`：執行工具並把例外轉成 `is_error` 的 `tool_result` |
| `utils/connections.py` | 150 | MCP 連線（stdio 與 SSE 兩種）與 `setup_mcp_connections` |
| `agent_demo.ipynb` | 660 | 示範筆記本：計算機 MCP、Brave 搜尋 MCP、think、伺服器端工具 |
| `test_message_params.py` | 264 | `message_params` 的測試（需要真的 API 金鑰才會跑） |

## 四、關鍵程式片段

**看什麼：迴圈怎麼判斷要不要繼續。**（`agent.py`）

```python
response = self.client.messages.create(
    **params,
    extra_headers=merged_headers
)
tool_calls = [
    block for block in response.content if block.type == "tool_use"
]

# （略：verbose 時印出文字與工具呼叫）

await self.history.add_message(
    "assistant", response.content, response.usage
)

if tool_calls:
    tool_results = await execute_tools(
        tool_calls,
        tool_dict,
    )
    # （略：verbose 時印出工具結果）
    await self.history.add_message("user", tool_results)
else:
    return response
```

整個代理就是這幾行（上面省略了 `verbose` 的列印段落）。程式不看 `stop_reason`，只看回覆內容裡有沒有 `tool_use` 區塊。工具結果用 `user` 角色放回歷史，下一輪模型就看得到。

**看什麼：工具出錯時發生什麼事。**（`utils/tool_util.py`）

```python
response = {"type": "tool_result", "tool_use_id": call.id}

try:
    # Execute the tool directly
    result = await tool_dict[call.name].execute(**call.input)
    response["content"] = str(result)
except KeyError:
    response["content"] = f"Tool '{call.name}' not found"
    response["is_error"] = True
except Exception as e:
    response["content"] = f"Error executing tool: {str(e)}"
    response["is_error"] = True
```

工具丟例外不會讓程式停下來，而是變成一則帶 `is_error` 的工具結果交還給模型，由模型決定怎麼補救。多個工具呼叫預設用 `asyncio.gather` 平行執行。

**看什麼：歷史太長時怎麼處理。**（`utils/history_util.py`）

```python
def truncate(self) -> None:
    """Remove oldest messages when context window limit is exceeded."""
    if self.total_tokens <= self.context_window_tokens:
        return

    TRUNCATION_NOTICE_TOKENS = 25
    TRUNCATION_MESSAGE = {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": "[Earlier history has been truncated.]",
            }
        ],
    }
```

超過上限時，一次移除最舊的兩則訊息（一對 user／assistant），再把剩下的第一則換成一句「較早的歷史已截斷」（以 25 個 token 計），如此重複到低於上限為止。這是最粗的做法：直接丟掉，不做摘要。預設上限是 `ModelConfig.context_window_tokens = 180000`。

**看什麼：一個工具最少要寫什麼。**（`tools/think.py`）

```python
async def execute(self, thought: str) -> str:
    """Simply returns the thought back to the model."""
    return "Thinking complete!"
```

`ThinkTool` 什麼事都不做。它的價值在於給模型一個「先把想法寫下來」的地方，寫下的內容會留在訊息歷史裡。

## 五、用到的 Claude 功能

- Messages API 的工具使用（tool use）｜`agent.py`｜代理迴圈的基礎。
- Prompt caching｜`utils/history_util.py` 的 `format_for_api()`｜替最後一則訊息的每個區塊加上 `cache_control: {"type": "ephemeral"}`。
- Token 計數｜`utils/history_util.py`｜建構時呼叫 `client.messages.count_tokens` 算系統提示的 token，失敗就用「系統提示的字元數除以 4」估算。
- 伺服器端工具｜`tools/web_search.py`（`web_search_20250305`）、`tools/code_execution.py`（`code_execution_20250522`）｜由 Anthropic 那一端執行，本機不需要 `execute()`。
- Beta 標頭｜`agent.py`｜每次請求預設帶 `anthropic-beta: code-execution-2025-05-22`，可用 `message_params` 的 `extra_headers` 覆蓋。
- MCP｜`utils/connections.py`｜支援 stdio 與 SSE 兩種連線，把遠端工具清單轉成本機 `Tool` 物件。
- 預設模型｜`agent.py` 的 `ModelConfig`｜`claude-sonnet-5-5`，`max_tokens = 4096`。

## 六、怎麼啟動（原始做法）

README 寫的需求是 Python 3.10 以上、`anthropic` 2.0 以上、`mcp` 2.0 以上，並設定 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。

```bash
pip install "anthropic>=2.0.0,<3" "mcp>=2.0"
```

```python
from agents.agent import Agent
from agents.tools.think import ThinkTool

agent = Agent(
    name="MyAgent",
    system="You are a helpful assistant.",
    tools=[ThinkTool()],
)
response = agent.run("What should I consider when buying a new laptop?")
```

README 的原始範例在 `Agent(...)` 裡還多傳了一個 `mcp_servers`（stdio，`python -m mcp_server`），並附有註解，上面省略了。本教材沒有執行上面的原始做法。演練改用 `practice/claude_cli_client.py` 取代 `anthropic`，讓同一份 `agent.py` 不改一行就能跑。

## 七、常見陷阱

1. **迴圈沒有上限。** `_agent_loop` 是 `while True`，只有模型不再要求工具才會結束。模型一直呼叫工具就一直跑，要自己加輪數上限。
2. **`mcp` 是硬性依賴。** `utils/connections.py` 在檔案開頭就 `from mcp import ...`，而 `agent.py` 會匯入它。所以即使完全不用 MCP，沒裝 `mcp` 也匯入不了 `Agent`。
3. **伺服器端工具在本機不能執行。** `WebSearchServerTool` 與 `CodeExecutionServerTool` 沒有 `execute()`，它們由 API 那一端執行。不過 `agent.py` 的 `tool_dict` 是用 `self.tools` 全部建出來的，所以它們也在裡面；迴圈只挑 `block.type == "tool_use"` 的區塊去執行，萬一真的有同名的 `tool_use`，呼叫 `execute()` 會丟例外，被 `tool_util.py` 接住變成 `is_error` 的工具結果。
4. **截斷會直接丟資訊。** `truncate()` 不做摘要，被移除的對話就是不見了。長任務需要另外的記憶機制（第 10 章的做法是寫進檔案）。
5. **`run()` 不能在已有事件迴圈的環境直接呼叫。** 它用 `asyncio.run()`；示範筆記本因此先 `nest_asyncio.apply()`，或直接 `await agent.run_async(...)`。
6. **筆記本的系統提示寫的工具名稱和實際不一致。** 筆記本的提示寫 `calculate`，但 `tools/calculator_mcp.py` 註冊的名稱是 `calculator`。模型看的是工具定義，所以仍能運作，但這提醒我們提示詞和工具定義要對得起來。

## 八、重點回顧

- 代理的最小形式：呼叫模型 → 有 `tool_use` 就執行工具並把結果放回歷史 → 再呼叫模型，直到沒有 `tool_use`。
- 工具只需要三樣東西：名稱、說明、輸入格式（JSON Schema），再加一個 `execute()`。
- 工具錯誤要變成 `is_error` 的工具結果交還模型，不要讓程式當掉。
- 歷史管理是代理的另一半：記 token、截斷、快取標記都在 `MessageHistory`。
- 本機工具、MCP 工具、伺服器端工具，對模型來說都只是工具清單裡的一項，差別在誰執行。
- 這份程式刻意沒有輪數上限、重試與權限控管，拿去用之前要自己補。
