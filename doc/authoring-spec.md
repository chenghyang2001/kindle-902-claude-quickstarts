# K902 教材撰寫規格（講義與演練章節重點）

本 repo 的 `lessons/chNN-<專案名>.md` 與 `prompts/chNN.md` 都照這份規格寫。後面的 NotebookLM 與演練備課工廠會直接吃這兩種檔案，格式不可自行變化。

## 共通規則

- 全部繁體中文（台灣用語）；程式碼、檔名、指令、識別字保留原文。
- 內容必須以 `~/workspace/claude-quickstarts`（commit 4a4224b）裡的實際 README 與程式碼為依據。看不出來的地方直接寫「看不出來」，不可臆測，也不可憑印象補 API 細節。
- 引用的檔名、函式名、常數、模型名稱、指令要和原始碼逐字一致。
- 路徑一律寫 `~/workspace/claude-quickstarts/...`，不寫任何使用者資料夾的絕對路徑；不寫任何個人資料。
- 不整段複製官方程式；講義裡的程式片段每段 15 行以內，只放說明重點需要的部分。
- 不提供、不教人設定任何 API 金鑰的實際值。原始做法需要金鑰時，只寫「原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）」。

## 講義 `lessons/chNN-<專案名>.md`

長度：正文約 1,200～2,000 個中文字（程式片段與表格不計）。第 10 章可到 3,000 字。

標題用全形空白分隔，不用連字號當段名分隔：

```markdown
# 第 N 章　<專案名>：<一句話副標>

> 來源：`~/workspace/claude-quickstarts/<專案資料夾>`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：實跑｜導讀＋小模擬

## 一、這個專案做什麼
## 二、架構與資料流
（一定要有一張文字流程圖，放在 ```text 區塊，用方框與箭頭）
## 三、關鍵檔案
（表格：檔案｜行數大約｜負責什麼）
## 四、關鍵程式片段
（2～4 段短片段，每段前面一句「看什麼」，後面 2～4 句說明）
## 五、用到的 Claude 功能
（條列：功能名｜在哪個檔案用到｜用來做什麼）
## 六、怎麼啟動（原始做法）
（照 README 寫指令；註明本教材沒有執行）
## 七、常見陷阱
（3～6 點，要有程式碼或 README 依據）
## 八、重點回顧
（4～6 點，一點一句）
```

## 演練章節重點 `prompts/chNN.md`

格式、欄位、長度比照 K145 的 `prompts/chNN.md`（對照檔：`~/workspace/kindle-145-swarm-intelligence-factory/prompts/ch01.md`）。整檔約 6,000～7,500 bytes。

```markdown
# chNN｜<專案名>：<副標>

## 這章在講什麼

- 4～6 點，每點 1～3 句，講這個專案的設計觀念（不是逐檔說明）。

## 作者做過的實驗／例子

- 3～4 點，寫官方 README 或程式裡實際示範的東西（內建範例、預設參數、README 記錄的數字）。

## 教練解說要點

- 4 點，教練帶演練時要強調的觀念與容易誤解的地方。

## 演練

> 說明：演練類型：<實跑｜導讀＋小模擬>（<一句理由>）。練習視窗工作目錄是 practice/。官方原始碼在 `~/workspace/claude-quickstarts/<專案資料夾>`，只讀不改、不安裝它的依賴、不執行它的啟動指令；要看原始碼用 `PYTHONUTF8=1 python qs_source.py <相對路徑> [起始行 結束行]`。自己寫的程式只用 Python 標準庫（不可 pip 安裝任何套件），檔案放 practice/chNN/interactive/，用 `PYTHONUTF8=1 python chNN/interactive/xxx.py` 執行。需要真實模型時用 practice/llm_agent.py 的 ask／ask_json，或 practice/claude_cli_client.py 的 Anthropic 相容介面（都走 claude -p，不設任何 API 金鑰、不 mock）；每個練習最多呼叫 2 次，整章最多 4 次。

### 練習 1：<標題>

**目的**：一到兩句。
**送給練習視窗的提示詞**：

```text
寫 chNN/interactive/xxx.py（只用標準庫，不可 input()，30 秒內跑完；有亂數就固定種子）：
1. …
2. …
```

**觀察重點**：

- 3 點，問句形式，寫出預期會看到的數字或現象。

### 練習 2：<標題>

（同上三個欄位）

```

每章固定 2 個練習。建議分工：

- 「導讀＋小模擬」章：練習 1 是離線導讀（用 `qs_source.py` 或自己寫的小程式把關鍵檔案的結構、常數、流程抽出來做成表），練習 2 是用 `claude -p` 模擬這個專案的核心迴圈（例如工具呼叫迴圈、截圖→動作迴圈用文字狀態代替畫面、進度檔交接）。模擬是「真模型＋假環境」：模型是真的，環境（瀏覽器、桌面、雲端服務）用幾十行 Python 的假物件代替，而且要在提示詞裡明說哪一部分是假環境。
- 「實跑」章：練習直接匯入官方模組（只讀），用轉接層把 SDK 呼叫改走 `claude -p` 實際跑出結果。

提示詞要具體到練習視窗不必再問問題：寫明檔名、輸入、要印出的表格欄位、要存的檔名、模型呼叫幾次。

## 轉接層介面（寫提示詞時可用的東西）

`practice/llm_agent.py`

- `ask(prompt, system=None) -> str`：問一句、拿文字回覆。
- `ask_json(prompt, system=None) -> dict`：要求只回 JSON 並解析。

`practice/claude_cli_client.py`（模仿 `anthropic` SDK 的最小介面）

- `claude_cli_client.Anthropic().messages.create(model=..., max_tokens=..., system=..., messages=[...], tools=[...])`
- 回傳物件：`.content`（block 清單，`block.type` 是 `"text"` 或 `"tool_use"`；text 有 `.text`；tool_use 有 `.id`、`.name`、`.input`）、`.stop_reason`（`"end_turn"` 或 `"tool_use"`）、`.usage.input_tokens`、`.usage.output_tokens`。
- `tools` 傳自訂工具（含 `name`、`description`、`input_schema`）時，轉接層把工具定義寫進系統提示，請模型用固定標記回覆，再解析成 `tool_use` block；之後把 `tool_result` 放進 `messages` 再呼叫一次，就能跑完整的工具迴圈。這是「用提示詞模擬的工具呼叫」，不是 API 原生的 tool use，講解時要照實說。
- 伺服器端工具（`web_search`、`code_execution`、computer／browser toolset 這類只有 `type` 沒有 `input_schema` 的）會被忽略。
- `claude_cli_client.install()`：把轉接層註冊成 `anthropic` 模組，之後 `from anthropic import Anthropic` 拿到的是轉接層。
- `claude_cli_client.calls_made()`：本行程已呼叫幾次。
- `claude_cli_client.install_mcp_stub()`：本機沒裝 `mcp` 套件時註冊空殼模組，讓官方 `agents/` 可以匯入（只在 `mcp_servers` 為空清單時可用）。
- 環境變數（都不是金鑰）：`K902_CLI_MODEL`（指定模型別名，例 `haiku`）、`K902_CLI_TIMEOUT`（預設 180 秒）、`K902_CLI_MAX_CALLS`（預設 10）。

`practice/qs_source.py`

- `PYTHONUTF8=1 python qs_source.py <相對路徑>`：印出官方檔案（帶行號）；加 `起始行 結束行` 只印一段。
- `from qs_source import root, read_text, grep`：`root()` 回傳官方 repo 根目錄（預設 `~/workspace/claude-quickstarts`，可用 `K902_QUICKSTARTS_DIR` 改）；`read_text(rel)` 讀檔；`grep(rel, pattern)` 回傳 `(行號, 文字)` 清單。
