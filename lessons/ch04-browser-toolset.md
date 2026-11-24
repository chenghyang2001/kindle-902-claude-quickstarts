# 第 4 章　browser-toolset：用 CDP 寫一個最小的瀏覽器工具組驅動程式

> 來源：`~/workspace/claude-quickstarts/browser-toolset`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

README 第一句就講明：這是 Claude 瀏覽器工具組（`browser_toolset_20260801`）的「最小 CDP 範例」，Python 與 TypeScript 各一份。使用方式是在 `tools` 裡只宣告一個工具組項目，模型會把每個瀏覽器動作（`navigate`、`read_page`、`left_click` 等）當成各自獨立的工具來呼叫，再由「驅動程式（driver）」在真的瀏覽器裡執行。

這個範例的驅動程式只有幾百行，不靠任何瀏覽器函式庫，直接用 WebSocket 講 Chrome DevTools Protocol（CDP），控制一個 Chromium 分頁，只實作工具組裡的五個工具：`navigate`、`read_page`、`left_click`、`get_page_text`、`wait`，外加回報分頁狀態的 `_browser_state`。README 與程式開頭都重複同一句話：它示範的是介面，不是可上線的程式。

工具的 schema、包住你的 URL 政策的網址檢查、拒絕驅動程式沒實作的工具、以及工具迴圈（tool runner），都由 SDK 提供；這些 SDK 內部怎麼做，從這個資料夾看不出來。

## 二、架構與資料流

```text
┌──────────────┐  task（整個命令列）
│  run.py      │─────────────────────────────┐
└──────┬───────┘                             ▼
       │ tools=[browser]          ┌─────────────────────┐
       │                          │ SDK tool runner     │
       │                          │ client.beta.messages│
       │                          │ .tool_runner(...)   │
       │                          └───┬─────────────▲───┘
       │                     tool_use │             │ tool_result
       ▼                              ▼             │（文字或 is_error）
┌──────────────────────────────────────────────────┴───┐
│ SDK 抽象類別 BetaAbstractBrowserToolset20260801       │
│ ・產生工具 schema  ・先跑 url_policy  ・拒絕未實作工具 │
└──────────────────────┬───────────────────────────────┘
                       │ 呼叫子類別方法
                       ▼
┌──────────────────────────────────────────────────────┐
│ CdpBrowser（cdp_browser.py）                          │
│ navigate / read_page / left_click / get_page_text /  │
│ wait / _browser_state                                 │
└──────────────────────┬───────────────────────────────┘
                       │ _send()：JSON 指令走 WebSocket
                       ▼
┌──────────────────────────────────────────────────────┐
│ Chromium（自己啟動，--remote-debugging-port=0，       │
│ 暫存 profile，一個分頁）                              │
└──────────────────────────────────────────────────────┘
```

`exercise.py` 走同一條路，只是把最上面的「模型＋tool runner」換成手寫的 `tool_use`，直接呼叫 `browser.tool_result(tool_use)`。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `python/cdp_browser.py` | 295 | 範例驅動程式：啟動 Chromium、連 CDP、實作五個工具與 `_browser_state`，檔尾是在頁面裡執行的四段 JavaScript 常數 |
| `python/run.py` | 93 | 入口：建立驅動程式與範例 URL 政策，交給 tool runner，逐則印出模型訊息 |
| `python/exercise.py` | 143 | 不用模型、不用金鑰的冒煙檢查：在 localhost 開一個小網頁，送六個呼叫並用 `assert` 檢查結果 |
| `python/requirements.txt` | 4 | `anthropic>=2.0.0,<3`、`websockets>=16.1`、`typing_extensions>=4.14` |
| `typescript/cdp-browser.ts`、`run.ts`、`exercise.ts` | 395／85／140 | 同一套做法的 TypeScript 版（類別同名 `CdpBrowser`，迴圈用 `client.beta.messages.toolRunner`） |
| `README.md` | 85 | 安裝、執行、環境變數、實作了什麼與沒做什麼 |

## 四、關鍵程式片段

**片段 1：看驅動程式怎麼找到 Chromium 的除錯端點**（`cdp_browser.py` 的 `_launch`）

```python
port_file = Path(self._profile_dir) / "DevToolsActivePort"
deadline = time.monotonic() + 20
while time.monotonic() < deadline:
    if port_file.exists():
        lines = port_file.read_text().split("\n")
        if len(lines) >= 2 and lines[0].strip().isdigit() and lines[1].startswith("/"):
            return f"ws://127.0.0.1:{lines[0].strip()}{lines[1].strip()}"
```

啟動參數是 `--remote-debugging-port=0`，也就是讓 Chromium 自己挑埠。Chromium 開始監聽後會把埠號與端點路徑寫進 profile 資料夾的 `DevToolsActivePort`，驅動程式最多等 20 秒去讀它。所以使用者不必事先開好一個帶除錯埠的瀏覽器，每次執行都是全新的暫存 profile。

**片段 2：看一個 CDP 指令怎麼送出去、怎麼等回應**（`_send`）

```python
command = {"id": message_id, "method": method, "params": params or {}}
if self._session_id and not method.startswith(("Target.", "Browser.")):
    command["sessionId"] = self._session_id
self._socket.send(json.dumps(command))
deadline = time.monotonic() + COMMAND_TIMEOUT_S
```

每個指令帶一個遞增的 `id`，之後一直收訊息直到看到同一個 `id`。`Target.` 與 `Browser.` 開頭的指令是送給瀏覽器本身，其餘要帶 `sessionId` 才會送到那個分頁。逾時（`COMMAND_TIMEOUT_S = 30`）或回應裡有 `error` 都轉成 `ToolError`，模型看到的就是一則錯誤的工具結果。

**片段 3：看 `left_click` 怎麼把 `ref_N` 變成座標**

```python
if input.target.type == "ref":
    point = self._evaluate(RESOLVE_REF % json.dumps(input.target.ref))
    if not point:
        raise ToolError(f"Unknown or stale ref: {input.target.ref}. Call read_page again for current refs.")
    x, y = point["x"], point["y"]
else:
    x, y = input.target.x, input.target.y
self._send("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})
```

`read_page` 在頁面裡替標題、連結、按鈕、表單控制項編號，存進 `window.__cdpBrowserRefs`。點擊時用 `RESOLVE_REF` 把元素捲進畫面、取中心點，再送 `mouseMoved`、`mousePressed`、`mouseReleased` 三個滑鼠事件。因為編號存在 `window` 上，一換頁就全部失效，錯誤訊息直接告訴模型「再呼叫一次 read_page」。

**片段 4：看範例 URL 政策**（`run.py` 的 `example_policy`）

```python
host = (parts.hostname or "").lower()
on_allowed_host = any(host == allowed or host.endswith("." + allowed) for allowed in hosts)
if parts.scheme not in ("http", "https") or not on_allowed_host:
    raise ToolError(f"blocked: {url} is not on an allowed host")
```

政策是一個函式：放行就什麼都不回傳，不放行就丟 `ToolError`。它只准 http(s)、主機在 `ALLOWED_DOMAINS` 裡（含子網域），另外放行 `about:blank`。README 強調這只是示範「政策放哪裡」，不是可上線的政策。

## 五、用到的 Claude 功能

- 瀏覽器工具組（`browser_toolset_20260801`）｜`cdp_browser.py` 繼承 `BetaAbstractBrowserToolset20260801`｜一個工具組項目展開成多個瀏覽器工具；型別字串只出現在 README，程式裡只看得到類別名稱。
- Tool runner｜`run.py` 的 `client.beta.messages.tool_runner(...)`｜自動跑「模型回 `tool_use` → 執行 → 回 `tool_result`」的迴圈，程式只需要 `for message in runner`。
- URL 政策（`url_policy`）｜`run.py`、`exercise.py`｜在驅動程式執行前先判斷模型要求的網址。
- `confirm` 選項｜只在 README 與類別 docstring 提到｜執行工具前先問人；這個範例沒有啟用任何需要它的工具。
- `ToolError`｜三個 Python 檔都有用｜把失敗變成 `is_error` 的工具結果，讓模型自己修正。
- 是否需要額外的 beta 標頭：看不出來（程式沒有自己設定）。

## 六、怎麼啟動（原始做法）

以下照 README 抄錄，本教材沒有執行。原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`），還需要 Python 3.10+ 與一個 Chromium 執行檔（`CHROME_PATH`，或 `PATH` 上的 `google-chrome`／`chromium`）。

```bash
cd browser-toolset/python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python run.py "Open example.com and tell me the heading"
python exercise.py        # 不需要金鑰，但仍需要 Chromium 與 SDK
```

環境變數：`ALLOWED_DOMAINS`（預設 `example.com,iana.org`）、`HEADLESS=0`（看得到瀏覽器）、`CHROME_PATH`、`MODEL`（`run.py` 的預設值是 `claude-sonnet-5-5`）。

## 七、常見陷阱

1. **URL 政策只管模型要求的網址**。驅動程式沒有攔截請求，README 明寫轉址、或放行頁面上的圖片與腳本，仍可能連到政策會拒絕的主機，要靠對外連線規則去擋。
2. **`localhost` 與 `127.0.0.1` 是兩個不同的來源**。`exercise.py` 的政策只放行 `http://localhost:<埠>`，同一頁改用 `127.0.0.1` 就被拒絕，而且是 SDK 在驅動程式執行前就擋下。
3. **`ref_N` 會過期**。編號存在 `window` 上，換頁就消失；點擊引發換頁後，下一次讀取可能失敗一次或讀到舊頁（README 的 Left out 清單）。
4. **對話框會卡死整個驅動程式**。頁面跳出 alert／confirm／prompt 後不再回應，README 說之後每個呼叫都要等 60 秒才失敗；程式裡的常數是 `COMMAND_TIMEOUT_S = 30`，60 秒是怎麼湊出來的，從這個資料夾看不出來。
5. **`wait` 的上限是驅動程式自己擋的**。註解寫明 SDK 沒有限制 `duration`，所以 `wait` 方法自己檢查 0～30 秒。
6. **Ubuntu 的 snap 版 Chromium 不能用**。README：它無法在 `/tmp` 底下開 profile，要改裝 Google Chrome 的 `.deb` 或用 `CHROME_PATH` 指到非 snap 的版本。

## 八、重點回顧

- 工具組是「宣告一個項目、模型看到多個工具」，驅動程式只要繼承抽象類別、實作想支援的方法。
- 這個驅動程式用九個 CDP 指令加一個生命週期事件，就做出導覽、讀頁、點擊、取文字四種能力。
- `read_page` 回傳的是帶 `ref_N` 的文字清單，不是截圖；這個範例完全沒有實作截圖。
- 失敗一律用 `ToolError` 回給模型，錯誤訊息要寫到模型知道下一步怎麼做。
- 安全靠三層：URL 政策、拋棄式 profile 加沙箱、對外連線管制；範例只示範第一層放在哪裡。
- `exercise.py` 示範了不花模型費用就能驗證驅動程式的方法：手寫 `tool_use`，直接呼叫 `tool_result`。
