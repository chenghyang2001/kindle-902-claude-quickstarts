# 第 10 章　autonomous-coding：跨多個 session 的長時間自主寫程式 harness

> 來源：`~/workspace/claude-quickstarts/autonomous-coding`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

前九章的代理都活在「一次對話」裡：context 滿了，任務就結束或開始失憶。這一章的專案要解決的是另一個量級的問題：一件要做好幾個小時、遠遠超過一個 context 視窗的工作，怎麼讓代理一段一段接力做完。

README 第一句話就是定位：這是一個最小的 harness，示範用 Claude Agent SDK 做長時間運行的自主寫程式。它把一份應用程式規格（內建範例是 claude.ai 聊天介面的複製品）交給代理，讓代理跨很多個 session 把它做成完整的網頁應用。

README 給的時間預期很直接：第一個 session 要好幾分鐘，看起來像當掉；之後每個 session 約 5～15 分鐘；做完全部 200 項功能要「很多個小時」。

做法可以濃縮成四件事，這也是整章的骨架：

1. **兩種角色分工**：初始化代理只跑一次，負責把規格變成一份可檢查的待辦清單；寫程式代理跑很多次，每次只做一項。
2. **每個 session 都是全新的 context**：代理對之前的 session 沒有任何記憶。
3. **狀態全部放在檔案裡**：`feature_list.json`、`claude-progress.txt`、git 提交紀錄。
4. **harness 本身很笨**：外層迴圈只負責「開新 session、送提示詞、等它結束、再開下一個」，所有判斷都交給提示詞與檔案。

## 二、架構與資料流

```text
python autonomous_agent_demo.py --project-dir ./my_project
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ run_autonomous_agent()（agent.py）                           │
│                                                             │
│  專案資料夾裡有 feature_list.json 嗎？                        │
│     沒有 → is_first_run = True，把 app_spec.txt 複製進去      │
│     有   → 接續既有專案，先印目前通過數                        │
│                                                             │
│  while True:                                                │
│    ┌──────────────────────────────────────────────────────┐ │
│    │ client = create_client(project_dir, model)            │ │
│    │          ↑ 每一輪都新建 = 全新的 context                │ │
│    │                                                      │ │
│    │ 第一輪       → initializer_prompt.md（初始化代理）      │ │
│    │ 之後每一輪   → coding_prompt.md（寫程式代理）           │ │
│    │                                                      │ │
│    │ async with client: run_agent_session(...)             │ │
│    │    代理在專案資料夾裡讀檔、寫檔、跑指令、開瀏覽器測試    │ │
│    └──────────────────────────────────────────────────────┘ │
│    印出 feature_list.json 的通過數／總數                      │
│    等 3 秒 → 下一輪（出錯也一樣：開新 session 重試）           │
└─────────────────────────────────────────────────────────────┘

        session 之間唯一的橋樑：專案資料夾裡的檔案

┌──────────────────┐  ┌─────────────────────┐  ┌──────────────┐
│ feature_list.json│  │ claude-progress.txt │  │ git 提交紀錄  │
│ 唯一事實來源      │  │ 留給下一棒的筆記     │  │ 存檔點＋歷史  │
│ 只能把 passes     │  │ 做了什麼、接著做什麼  │  │ git log -20  │
│ 由 false 改 true  │  │ 目前通過幾項         │  │              │
└──────────────────┘  └─────────────────────┘  └──────────────┘
        ▲                       ▲                      ▲
        └────── 初始化代理建立，寫程式代理每個 session 讀取並更新 ──────┘
```

寫程式代理每個 session 固定走十步（`prompts/coding_prompt.md`）：

```text
1 了解現況（pwd、ls、讀規格、讀清單、讀進度筆記、git log、數剩幾項）
2 啟動環境（跑 init.sh）
3 先重測 1～2 項已通過的核心功能（上一棒可能弄壞東西）
4 挑一項 passes 為 false、優先度最高的功能
5 實作
6 用瀏覽器自動化從介面驗證並截圖
7 只把那一項的 passes 改成 true
8 git commit
9 更新 claude-progress.txt
10 乾淨收尾（不留未提交的變更、不留壞掉的功能）
```

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `autonomous_agent_demo.py` | 116 | 進入點：解析參數、檢查金鑰、把相對路徑放到 `generations/` 底下 |
| `agent.py` | 206 | `run_autonomous_agent`（外層迴圈）與 `run_agent_session`（跑一個 session、印出工具呼叫） |
| `client.py` | 122 | `create_client`：建立 SDK client，設定沙箱、權限、允許的工具、Puppeteer MCP、安全 hook |
| `security.py` | 359 | Bash 指令允許清單與 `bash_security_hook` |
| `test_security.py` | 290 | 安全 hook 的測試（哪些指令該擋、哪些該放） |
| `progress.py` | 57 | 讀 `feature_list.json` 算通過數、印 session 標題 |
| `prompts.py` | 37 | 載入提示詞、把 `app_spec.txt` 複製進專案資料夾 |
| `prompts/initializer_prompt.md` | 106 | 初始化代理的提示詞 |
| `prompts/coding_prompt.md` | 197 | 寫程式代理的提示詞（十步流程） |
| `prompts/app_spec.txt` | 679 | 內建規格：Claude.ai Clone（React＋Vite、Node.js＋Express、SQLite） |
| `requirements.txt` | 1 | `claude-code-sdk>=0.0.25` |

## 四、關鍵程式片段

**看什麼：harness 怎麼知道現在是第一次還是接續。**（`agent.py`）

```python
tests_file = project_dir / "feature_list.json"
is_first_run = not tests_file.exists()
```

判斷只靠一個檔案存不存在。沒有資料庫、沒有狀態檔、沒有 session 編號。這就是為什麼按 `Ctrl+C` 中斷後，重跑同一個指令就能接續。

**看什麼：「全新 context」是怎麼做到的。**（`agent.py`）

```python
while True:
    iteration += 1
    if max_iterations and iteration > max_iterations:
        break
    # Create client (fresh context)
    client = create_client(project_dir, model)
    if is_first_run:
        prompt = get_initializer_prompt()
        is_first_run = False  # Only use initializer once
    else:
        prompt = get_coding_prompt()
    async with client:
        status, response = await run_agent_session(client, prompt, project_dir)
```

每一輪都重新 `create_client`，上一輪的對話完全不帶過來。兩種角色用的是同一個 client 設定、同一個系統提示，差別只有送進去的那份提示詞。所謂「兩個代理」其實是同一支程式輪流用兩份提示詞開 session，同一時間只有一個在跑。

**看什麼：清單的鐵則寫在哪裡。**（`prompts/initializer_prompt.md`）

```text
**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).
Never remove features, never edit descriptions, never modify testing steps.
```

`feature_list.json` 的每一筆有四個欄位：`category`（`functional` 或 `style`）、`description`、`steps`、`passes`。規則是只能把 `passes` 由 false 改成 true。這條規則只存在於提示詞裡：`agent.py` 與 `progress.py` 都沒有檢查清單有沒有被刪改，`progress.py` 只負責數數。

**看什麼：安全 hook 怎麼擋指令。**（`security.py`）

```python
commands = extract_commands(command)
if not commands:
    return {"decision": "block",
            "reason": f"Could not parse command for security validation: {command}"}
for cmd in commands:
    if cmd not in ALLOWED_COMMANDS:
        return {"decision": "block",
                "reason": f"Command '{cmd}' is not in the allowed commands list"}
```

這是允許清單，不是禁止清單：沒列在 `ALLOWED_COMMANDS` 的一律擋。解析不了的指令（例如引號沒關）也擋，這叫失敗時偏向安全。清單裡的 `pkill`、`chmod`、`init.sh` 還要再過一層檢查：`pkill` 只能殺 `node`、`npm`、`npx`、`vite`、`next`；`chmod` 只能是 `+x` 類的模式而且不能帶旗標；腳本只能是 `./init.sh`。

## 五、初始化代理與寫程式代理的分工

| | 初始化代理 | 寫程式代理 |
| --- | --- | --- |
| 何時跑 | 只有第 1 個 session（專案資料夾還沒有 `feature_list.json`） | 第 2 個 session 起，每次都是 |
| 提示詞 | `prompts/initializer_prompt.md` | `prompts/coding_prompt.md` |
| 主要產出 | `feature_list.json`（至少 200 筆、全部 `"passes": false`、依優先度排序、至少 25 筆要有 10 個以上步驟）、`init.sh`、`git init` 與首次提交、專案骨架、`claude-progress.txt` | 一項功能的實作、瀏覽器驗證截圖、該項 `passes` 改 true、一次 git 提交、更新 `claude-progress.txt` |
| 有剩餘時間時 | 可以開始做優先度最高的功能 | 繼續做下一項 |
| 開場動作 | 讀 `app_spec.txt` | 先了解現況，再重測已通過的核心功能 |

這個分工回答了長時間任務的兩個難題。第一，**怎麼知道做完了沒**：先把規格展開成一份逐項可驗證的清單，之後每個 session 都對著同一份清單。第二，**怎麼避免每一棒都重新理解整個專案**：開場固定讀進度筆記與 git 歷史，收尾固定寫進度筆記與提交。

兩份提示詞裡還有幾句值得注意的話。寫程式代理的提示詞開頭直說「這是全新的 context，你對之前的 session 沒有記憶」；中間說「這個 session 只完成一項功能也沒關係，之後還有更多 session」；結尾說「你有無限的時間，最重要的是結束前把程式庫留在乾淨的狀態」。這些話的目的都是讓代理不要急著一次做完，而是把每一棒交接好。

## 六、用到的 Claude 功能

- Claude Agent SDK（套件名 `claude-code-sdk`）｜`client.py`、`agent.py`｜`ClaudeSDKClient` 與 `ClaudeCodeOptions`，底層是 Claude Code CLI。
- 內建工具｜`client.py` 的 `BUILTIN_TOOLS`｜`Read`、`Write`、`Edit`、`Glob`、`Grep`、`Bash`。
- MCP 伺服器｜`client.py`｜`puppeteer`（`npx puppeteer-mcp-server`），提供 7 個瀏覽器自動化工具做介面驗證。
- PreToolUse hook｜`client.py` 用 `HookMatcher(matcher="Bash", hooks=[bash_security_hook])`｜每個 Bash 指令執行前先過允許清單。
- 沙箱與權限設定｜`client.py` 寫出 `.claude_settings.json`｜`sandbox.enabled`、`permissions.defaultMode = "acceptEdits"`、檔案操作限制在 `./**`。
- `max_turns=1000`｜`client.py`｜單一 session 內最多 1000 輪。
- 預設模型｜`autonomous_agent_demo.py` 的 `DEFAULT_MODEL`｜`claude-sonnet-4-5-20250929`，可用 `--model` 改。
- 系統提示｜`client.py`｜兩種角色共用同一句：`You are an expert full-stack developer building a production-quality web application.`

## 七、怎麼啟動（原始做法）

README 的步驟如下。原始做法需要 `ANTHROPIC_API_KEY`（程式在 `autonomous_agent_demo.py` 與 `client.py` 各檢查一次，沒設就不跑）；本教材演練不設定，也沒有執行這些指令。

```bash
npm install -g @anthropic-ai/claude-code
pip install -r requirements.txt

python autonomous_agent_demo.py --project-dir ./my_project
python autonomous_agent_demo.py --project-dir ./my_project --max-iterations 3
```

| 參數 | 說明 | 預設 |
| --- | --- | --- |
| `--project-dir` | 專案資料夾；相對路徑會自動放到 `generations/` 底下 | `./autonomous_demo_project` |
| `--max-iterations` | 最多跑幾個 session | 不限 |
| `--model` | 使用的模型 | `claude-sonnet-4-5-20250929` |

想縮短示範時間，README 建議改 `prompts/initializer_prompt.md` 裡的功能數（例如 20～50 項）；想換一個應用程式就改 `prompts/app_spec.txt`。

## 八、常見陷阱

1. **沒有「全部通過就停」的判斷。** 外層迴圈的離開條件只有 `--max-iterations`。不加這個參數就一直開新 session，直到手動 `Ctrl+C`。程式印的訊息寫「will run until completion」，但程式碼裡沒有檢查完成的地方。
2. **清單不可刪改的規則只靠提示詞。** harness 不會比對 `feature_list.json` 前後版本。代理如果刪掉難做的項目，通過率會變好看，程式不會發現。要嚴格就得自己在 harness 加檢查（演練練習 2 會做）。
3. **第一個 session 看起來像當掉是正常的。** 初始化代理在寫 200 筆測試案例；README 請使用者看有沒有 `[Tool: ...]` 輸出來確認它還在動。
4. **出錯的處理很簡單。** `run_agent_session` 把任何例外都轉成 `"error"`，外層等 3 秒就用新 session 重試，沒有重試次數上限，也沒有退避。
5. **允許清單很窄，常用指令會被擋。** `test_security.py` 列出會被擋的包含 `curl`、`wget`、`python app.py`、`touch`、`echo`、`kill`、`rm`。代理要靠 SDK 的 `Write`／`Edit` 工具寫檔，而不是靠 shell。
6. **判斷第一次與否只看檔案存不存在。** 初始化代理如果寫到一半中斷，留下一份不完整的 `feature_list.json`，下一次啟動會被當成「接續既有專案」，直接交給寫程式代理。這種情況 harness 會不會自己修復，從程式看不出來。
7. **規格裡有金鑰相關的安排。** 內建的 `app_spec.txt` 寫測試用金鑰放在 `/tmp/api-key`，而且代理「不被允許讀取」這個檔，只能在程式碼裡引用它的路徑。這個限制實際由哪一層設定強制，從這個資料夾的程式看不出來。
8. **README 的授權說明和 repo 不一致。** 這個資料夾的 README 最後寫「Internal Anthropic use.」，但 repo 根目錄的 LICENSE 是 MIT。

## 九、重點回顧

- 長時間任務的關鍵不在讓一個 session 撐更久，而在讓每個 session 都能從檔案把狀態撿回來。
- 兩種角色：初始化代理把規格展開成可驗證的清單，寫程式代理每次只做一項並交接。它們是同一支 harness 輪流送兩份提示詞，不是同時運作的兩個代理。
- 三種交接媒介各有用途：`feature_list.json` 回答「還剩什麼」，`claude-progress.txt` 回答「上一棒做了什麼、建議接著做什麼」，git 提交紀錄是可以回復的存檔點。
- 每個 session 開場先重測已通過的功能，是因為上一棒可能把東西弄壞而自己不知道。
- harness 的外層迴圈只有幾十行：新建 client、選提示詞、跑 session、印進度、等 3 秒。智慧在提示詞與檔案約定裡。
- 安全靠三層：作業系統層沙箱、檔案權限限制在專案資料夾、Bash 指令允許清單。
- 這是示範用的最小實作：沒有完成判斷、沒有清單防竄改、沒有重試上限，正式使用前要自己補。
