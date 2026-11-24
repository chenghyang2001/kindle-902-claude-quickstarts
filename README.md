# K902　Claude Quickstarts 導讀與互動演練（無原書教材）

這是一份自編教材，教材來源不是書，而是 Anthropic 官方 repo
[`anthropics/claude-quickstarts`](https://github.com/anthropics/claude-quickstarts)（本教材依據 commit `4a4224b`）。
官方 repo 頂層有 10 個專案，本教材一個專案寫一章，由淺入深排成 10 章，最後一章是長時間運行的自主寫程式 harness。

書號 902 的 9 開頭表示「沒有原書」。

## 章節

| 章 | 專案 | 類型 | 演練類型 |
| --- | --- | --- | --- |
| 1 | `customer-support-agent` | 非代理（知識庫檢索＋結構化回覆） | 導讀＋小模擬 |
| 2 | `financial-data-analyst` | 非代理（聊天＋一個繪圖工具） | 導讀＋小模擬 |
| 3 | `agents` | 單代理（最小工具迴圈） | 實跑 |
| 4 | `browser-toolset` | 工具集（CDP 瀏覽器驅動） | 導讀＋小模擬 |
| 5 | `browser-use-demo` | 工具集（Playwright 瀏覽器自動化） | 導讀＋小模擬 |
| 6 | `computer-toolset` | 工具集（VNC 桌面驅動） | 導讀＋小模擬 |
| 7 | `computer-use-demo` | 工具集（容器化 computer use） | 導讀＋小模擬 |
| 8 | `computer-use-best-practices` | 工具集（macOS 原生 computer use 教學實作） | 導讀＋小模擬 |
| 9 | `managed-agents` | 代管代理（12 個子專案） | 導讀＋小模擬 |
| 10 | `autonomous-coding` | 長時間運行（初始化代理＋寫程式代理接力） | 導讀＋小模擬 |

演練類型的定義與每章的理由見 [`practice/README.md`](practice/README.md)。

## 目錄

| 路徑 | 內容 |
| --- | --- |
| `lessons/chNN-<專案名>.md` | 各章講義：專案做什麼、架構與資料流、關鍵檔案與程式片段、用到的 Claude 功能、原始啟動方式、常見陷阱、重點回顧 |
| `prompts/chNN.md` | 各章演練重點：觀念、官方示範、教練解說要點、2 個練習（演練備課工廠讀這份產出 8 步互動演練） |
| `practice/` | 演練共用工具：`llm_agent.py`、`claude_cli_client.py`（都走 `claude -p`）、`qs_source.py`（只讀查看官方原始碼） |
| `doc/authoring-spec.md` | 講義與演練重點的撰寫規格 |

## 使用前準備

1. 取得官方原始碼（只讀參考，本 repo 不含官方程式碼）：

   ```bash
   git clone https://github.com/anthropics/claude-quickstarts ~/workspace/claude-quickstarts
   ```

2. 安裝並登入 Claude Code CLI（`claude --version` 能執行）。演練呼叫模型一律走 `claude -p`，使用訂閱額度。
3. 檢查轉接層：

   ```bash
   cd practice
   PYTHONUTF8=1 python llm_agent.py --selftest          # 離線
   echo "用一句話自我介紹" | PYTHONUTF8=1 python llm_agent.py
   PYTHONUTF8=1 python claude_cli_client.py --live      # 真模型跑一個兩次呼叫的工具迴圈
   ```

## 重要規定

- **不設定任何 API 金鑰。** 官方專案的原始做法多半需要 `ANTHROPIC_API_KEY`；本教材的演練不設定、不讀取，轉接層還會在呼叫前把相關環境變數從子程序移除。
- **不 mock 模型。** 需要模型的地方都由真模型回答；不能在本機重現的環境（瀏覽器、桌面、雲端服務）才用幾十行 Python 的假物件代替，並在練習裡明說。
- **不修改、不整包複製官方程式碼。** 講義只引用說明需要的短片段。

## 來源與授權

- 教材來源：`anthropics/claude-quickstarts`，著作權屬 Anthropic，以 MIT 授權釋出（見該 repo 的 `LICENSE`）。講義中引用的程式片段沿用該授權。
- 本 repo 的講義、演練重點與 `practice/` 底下的工具為自行撰寫的學習筆記，非 Anthropic 官方文件；內容以上述 commit 的程式碼為依據，官方之後的更新可能使部分描述過時。
