# practice　演練共用工具與演練類型分類

## 演練類型的定義

本教材規定演練呼叫模型一律走 `claude -p`（訂閱額度），不設定任何 API 金鑰，也不 mock 模型。照這個規定，每一章歸到兩類之一：

- **實跑**：官方範例是純 Python，把它的 SDK 呼叫用轉接層改走 `claude -p` 之後，官方程式不改一行就能由真模型驅動、實際跑出結果。
- **導讀＋小模擬**：官方範例需要這裡沒有的東西（Docker 容器、Amazon Bedrock、Claude Managed Agents 雲端服務、macOS、真的瀏覽器或桌面、新版 SDK 的 tool runner、Claude Agent SDK），不能實跑。改成先逐步讀懂關鍵程式，再用一小段 `claude -p` 程式模擬它的核心迴圈。模擬的原則是「真模型＋假環境」：模型是真的，環境用幾十行 Python 的假物件代替，並在練習裡明說哪部分是假的。

## 10 章分類表

| 章 | 專案 | 演練類型 | 理由 | 練習 1 | 練習 2 |
| --- | --- | --- | --- | --- | --- |
| 1 | `customer-support-agent` | 導讀＋小模擬 | Next.js 網頁應用；知識檢索依賴 Amazon Bedrock Knowledge Bases 與 AWS 憑證 | 把回覆契約與分類表抽成一張表（離線） | 假知識庫＋真模型，產生並驗證結構化回覆 |
| 2 | `financial-data-analyst` | 導讀＋小模擬 | Next.js 網頁應用，要 `npm install` 與瀏覽器；圖表在前端畫 | 把工具 schema 改寫成 Python 並寫驗證器（離線） | 真模型對假財務 CSV 產生圖表資料 |
| 3 | `agents` | 實跑 | 純 Python；`anthropic` 換成轉接層、`mcp` 用空殼頂替後，`agent.py` 可直接由真模型驅動 | 官方 `Agent` 掛自訂工具跑完一次工具迴圈 | 離線實跑 `execute_tools` 與 `MessageHistory` |
| 4 | `browser-toolset` | 導讀＋小模擬 | 要 Chromium（CDP）與新版 SDK 的 tool runner、伺服器端 toolset 型別 | 工具→CDP 指令對照表（離線） | 真模型＋假瀏覽器的兩回合工具迴圈 |
| 5 | `browser-use-demo` | 導讀＋小模擬 | 要在 Docker 容器裡跑 Playwright 瀏覽器與虛擬顯示器 | browser 工具動作表、座標換算、裁圖函式（離線） | 假網頁＋真模型的 ref 工具迴圈 |
| 6 | `computer-toolset` | 導讀＋小模擬 | 要 VNC 桌面與新版 SDK 的 tool runner、伺服器端 toolset 型別 | 工具→RFB 訊息對照表（離線） | 真模型＋假桌面的截圖→動作迴圈 |
| 7 | `computer-use-demo` | 導讀＋小模擬 | 要在 Docker 容器裡跑 X11 桌面與 VNC | 工具版本表、座標縮放表、裁圖表（離線） | 假桌面＋真模型的座標工具迴圈 |
| 8 | `computer-use-best-practices` | 導讀＋小模擬 | 只能在 macOS 上用 pyautogui 與 sandbox-exec 操作真實桌面 | 重算截圖尺寸與舊截圖裁剪（離線） | 假桌面上的批次工具 |
| 9 | `managed-agents` | 導讀＋小模擬 | 要 Claude Managed Agents 雲端服務、`ant` CLI 與第三方服務帳號 | 12 個子專案總表與 daily-brief 設定檔拆解（離線） | 模擬 daily-brief 的跨次記憶 |
| 10 | `autonomous-coding` | 導讀＋小模擬 | 要 Claude Agent SDK、API 金鑰、Puppeteer MCP，而且要跑好幾個小時；但 `security.py`、`progress.py` 只用標準庫，可離線實跑 | 實跑官方的安全 hook 與進度計數（離線） | 用 `claude -p` 模擬初始化代理與寫程式代理的接力（3 次呼叫） |

合計：實跑 1 章、導讀＋小模擬 9 章。

## 共用工具

| 檔案 | 用途 | 自我檢查 |
| --- | --- | --- |
| `llm_agent.py` | `ask(prompt, system=None)`、`ask_json(prompt, system=None)`：問一次、拿文字或 JSON | `PYTHONUTF8=1 python llm_agent.py --selftest`（離線） |
| `claude_cli_client.py` | 模仿 `anthropic` SDK 的 `Anthropic().messages.create(...)`，含用提示詞模擬的自訂工具呼叫；`install()` 註冊成 `anthropic` 模組；`install_mcp_stub()` 在沒裝 `mcp` 時放空殼模組 | `PYTHONUTF8=1 python claude_cli_client.py`（離線）；加 `--live` 真的呼叫模型 2 次 |
| `qs_source.py` | 只讀方式查看官方原始碼（帶行號、可 grep） | `PYTHONUTF8=1 python qs_source.py --selftest` |

兩支轉接層呼叫 `claude -p` 的方式相同：

- 提示詞走 stdin、系統提示走 `--system-prompt-file`（Windows 的 `claude.CMD` 會截斷多行參數）。
- 呼叫前從子程序環境移除 `ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、`CLAUDECODE` 與所有 `CLAUDE_CODE_*` 變數。
- 加上 `--tools ""`、`--restricted`、`--strict-mcp-config`、`--disable-slash-commands`、`--no-session-persistence`，並在空的暫存資料夾啟動：模型只能回文字，不讀個人設定，也不會把 `.claude/` 寫進練習目錄。

可調環境變數（都不是金鑰）：`K902_CLI_MODEL`（模型別名，例 `haiku`）、`K902_CLI_TIMEOUT`（預設 180 秒）、`K902_CLI_MAX_CALLS`（預設 10，只對 `claude_cli_client.py` 有效）、`K902_QUICKSTARTS_DIR`（官方 repo 位置，預設 `~/workspace/claude-quickstarts`）。

## 轉接層的限制（講解時要照實說）

- 自訂工具是「用提示詞模擬的工具呼叫」：工具定義寫進系統提示，模型用 `<tool_use>{...}</tool_use>` 標記回覆，轉接層再解析成 `tool_use` block。這不是 API 原生的 tool use，模型偶爾會不照格式，那時整段當成文字回傳。
- 伺服器端工具（`web_search`、`code_execution`、computer／browser toolset）會被忽略；圖片不會送給模型。
- `max_tokens`、`temperature`、`tool_choice`、`thinking`、`betas`、`extra_headers`、`cache_control` 會被忽略；`model` 參數預設不傳給 CLI。
- 每次呼叫都是一個全新的 `claude -p` 行程，多輪對話是把歷史攤平成逐字稿再送一次；沒有串流；`count_tokens` 只是估算。

## 給演練備課工廠的建議設定

- 每章 8 步；呼叫模型的步驟最多 2 步。一步裡可能呼叫 2 次（工具迴圈），第 10 章有一步呼叫 3 次，單步逾時建議設 300 秒以上（實測單次呼叫約 5～10 秒，但要留餘裕）。
- 腳本不可修改 `practice/llm_agent.py`、`practice/claude_cli_client.py`、`practice/qs_source.py`。
- 第 3、10 章的腳本會匯入官方模組，執行的電腦上要有 `~/workspace/claude-quickstarts`。
- 互動腳本與教練稿的格式範本（K145 用的是 `practice/interactive/format-example-k142-*`）本 repo 還沒有放，建工廠專案時再補。
- 第 3 章「官方 `Agent` 經轉接層實跑」這條路徑是依程式碼逐行對照設計的，寫教材時依規定沒有執行官方程式，所以還沒有實測；工廠第一次跑第 3 章時要留意。
