# 第 7 章　computer-use-demo：看截圖、回座標，操作一整台 Linux 桌面

> 來源：`~/workspace/claude-quickstarts/computer-use-demo`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

這是 Anthropic 的 computer use 參考實作：一個 Docker 容器裡跑著 Ubuntu 桌面（Xvfb 虛擬顯示器、mutter 視窗管理員、tint2 工作列、Firefox、LibreOffice 等），Claude 透過三個工具操作它——`computer`（滑鼠、鍵盤、截圖）、`bash`（殼層指令）、`str_replace_based_edit_tool`（看檔與改檔）。使用者在 Streamlit 介面下指令，同時從 noVNC 看桌面。

和第 5 章不同，這裡沒有 DOM 可以問。模型只看得到截圖，所有指向都是像素座標；工具用 `xdotool` 把座標變成真的滑鼠與鍵盤事件，再截一張圖回給模型。所以這一章的重點有三個：截圖與座標怎麼縮放、同一套工具的五個日期版本怎麼選、以及三家供應商（Claude API、Bedrock、Vertex）在迴圈裡的差別。

README 一開頭就強調這是刻意精簡的示範，而且代理迴圈就跑在被操作的那個容器裡，一次只能服務一個工作階段，換工作階段時必要的話得重啟或重設。想看更完整的做法（圖片大小控制、伺服器端壓縮、批次工具呼叫、軌跡錄製），README 指向同一個 repo 的 `computer-use-best-practices` 專案。

系統提示也透露了實務經驗：開 GUI 程式要在 bash 裡指定 `DISPLAY=:1` 並放進子殼層；輸出很長的指令先導到暫存檔再查；讀 PDF 不要一頁頁截圖，改用 `curl` 下載後轉成文字檔。

## 二、架構與資料流

```text
┌────────────┐      ┌──────────────────────────────────────┐
│ 使用者      │─────▶│ streamlit.py                          │
│ :8080/:8501 │◀─────│ 側欄：provider、model、Tool Versions、 │
└────────────┘      │ 只送最近 N 張圖、thinking 模式          │
                    └──────────────────┬───────────────────┘
                                       ▼
        ┌──────────────────────────────────────────────────┐
        │ loop.py  sampling_loop()                          │
        │ TOOL_GROUPS_BY_VERSION[tool_version] → 建工具      │
        │ while True:                                       │
        │  1 依 provider 建 client、決定 betas               │
        │  2 Anthropic：_inject_prompt_caching，不裁圖       │
        │    其他：_maybe_filter_to_n_most_recent_images     │
        │  3 client.beta.messages.with_raw_response.create  │
        │  4 逐一執行 tool_use → 組 tool_result              │
        │  5 沒有 tool_result → return messages             │
        └──────────────────┬───────────────────────────────┘
                           ▼
        ┌──────────────────────────────────────────────────┐
        │ tools/collection.py  ToolCollection.run()         │
        │ 有 toolset_name → toolset_map；否則 → tool_map     │
        └──────┬──────────────────┬───────────────┬────────┘
               ▼                  ▼               ▼
     ┌──────────────────┐ ┌──────────────┐ ┌──────────────┐
     │ computer.py       │ │ bash.py       │ │ edit.py       │
     │ 座標放大 → xdotool │ │ 常駐 bash     │ │ 看檔／取代     │
     │ 截圖 → convert 縮小│ │ 工作階段      │ │               │
     └────────┬─────────┘ └──────────────┘ └──────────────┘
              ▼
     ┌──────────────────┐
     │ Xvfb :1 桌面       │──▶ x11vnc → noVNC（:6080）
     └──────────────────┘
```

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `computer_use_demo/loop.py` | 390 | `sampling_loop`、`SYSTEM_PROMPT`、prompt caching、裁圖、thinking 參數、toolset 的失敗即停規則 |
| `computer_use_demo/tools/groups.py` | 70 | `ToolVersion`、`TOOL_GROUPS`：每個版本用哪些工具類別、哪個 beta 旗標 |
| `computer_use_demo/tools/computer.py` | 635 | 四個 computer 工具類別、動作清單、`scale_coordinates`、截圖與 `zoom` |
| `computer_use_demo/tools/collection.py` | 60 | `ToolCollection`：依工具名或 `toolset_name` 分派，把 `ToolError` 轉成 `ToolFailure` |
| `computer_use_demo/tools/bash.py`、`edit.py`、`run.py` | 150／280／40 | 殼層工作階段、文字編輯工具、帶逾時與截斷的指令執行 |
| `computer_use_demo/streamlit.py` | 670 | `MODEL_TO_MODEL_CONF`（模型對應工具版本與 thinking 模式）、側欄設定、訊息繪製 |
| `Dockerfile`、`image/` | — | Ubuntu 22.04、桌面套件、Python 3.14.9、預設 `WIDTH=1024`、`HEIGHT=768` |
| `tests/loop_test.py`、`tests/tools/computer_test.py` | 250／330 | 迴圈、縮放、toolset 行為的測試 |

## 四、關鍵程式片段

**片段 1：看版本表**（`tools/groups.py`）

```python
ToolGroup(
    version="computer_use_20251124",
    tools=[ComputerTool20251124, EditTool20250728, BashTool20250124],
    beta_flag="computer-use-2025-11-24",
),
ToolGroup(
    version="computer_toolset_20260801",
    tools=[ComputerToolset20260801, EditTool20250728, BashTool20250124],
    beta_flag=None,
),
```

「工具版本」其實是一組設定：用哪個 computer 類別、哪個 bash 類別、要送哪個 beta 標頭。五個版本裡，前四個各有 beta 旗標，最新的 toolset 沒有。動作數也跟著版本增加：`Action_20241022` 有 10 個，`Action_20250124` 多 6 個（含 `scroll`、`wait`、`triple_click`），`Action_20251124` 再多一個 `zoom`。

**片段 2：看座標怎麼縮放**（`tools/computer.py`）

```python
x_scaling_factor = target_dimension["width"] / self.width
y_scaling_factor = target_dimension["height"] / self.height
if source == ScalingSource.API:
    if x > self.width or y > self.height:
        raise ToolError(f"Coordinates {x}, {y} are out of bounds")
    # scale up
    return round(x / x_scaling_factor), round(y / y_scaling_factor)
# scale down
return round(x * x_scaling_factor), round(y * y_scaling_factor)
```

實體螢幕若比 `MAX_SCALING_TARGETS`（XGA 1024x768、WXGA 1280x800、FWXGA 1366x768）裡長寬比相近的目標大，截圖就先用 `convert -resize` 縮小再給模型；模型回的座標屬於縮小後的畫面，執行前再放大回實體座標。測試檔的例子：1920x1080 的螢幕，模型座標 (1366, 768) 會換成 (1920, 1080)。4096x2160 找不到相近比例，就完全不縮放。

**片段 3：看 Anthropic 供應商為什麼不裁圖**（`loop.py`）

```python
if enable_prompt_caching:
    betas.append(PROMPT_CACHING_BETA_FLAG)
    _inject_prompt_caching(messages)
    # Because cached reads are 10% of the price, we don't think it's
    # ever sensible to break the cache by truncating images
    only_n_most_recent_images = 0
```

走 Claude API 時會開 prompt caching，在最近三則 user 訊息與 system 上放快取斷點，並且把「只送最近 N 張圖」直接歸零。理由寫在註解裡：刪舊圖會讓前面的內容改變、快取失效，不划算。Bedrock 與 Vertex 沒開快取，才會真的裁圖，而且是「湊滿一批才刪」：要刪的張數會先減掉除以門檻的餘數。

**片段 4：看 toolset 的失敗即停**（`loop.py`）

```python
if toolset_name is not None and member_call_failed:
    result: ToolResult = ToolFailure(error=NOT_EXECUTED_ERROR)
else:
    result = await tool_collection.run(
        name=tool_use_block["name"],
        tool_input=cast(dict[str, Any], tool_use_block.get("input", {})),
        toolset_name=toolset_name,
    )
    if toolset_name is not None and result.error:
        member_call_failed = True
```

`computer_toolset_20260801` 把每個動作變成各自的成員工具，`tool_use.name` 就是 `left_click`、`screenshot` 這類名字，區塊另帶 `toolset_name: "computer"`。同一回合的多個成員呼叫依序執行，前面一個失敗，後面的不執行，直接回固定文字 `NOT_EXECUTED_ERROR`。回傳的 `tool_result` 也要帶同一個 `toolset_name`。

## 五、用到的 Claude 功能

- Anthropic 定義的工具（computer、bash、text editor）｜`tools/computer.py`、`bash.py`、`edit.py` 的 `to_params`｜只送 `type`（與名稱、螢幕尺寸），參數格式由 Anthropic 定義。
- Computer toolset｜`ComputerToolset20260801`、`collection.py`｜無名稱的工具項目，一個動作一個成員工具，不需要 beta 標頭。
- Beta 標頭｜`groups.py`、`loop.py`｜依工具版本送 `computer-use-…`，另可勾選 `token-efficient-tools-2025-02-19`。
- Prompt caching｜`loop.py` 的 `_inject_prompt_caching`｜只在 Anthropic 供應商啟用。
- Thinking｜`loop.py`、`streamlit.py`｜`adaptive`（搭配 `output_config` 的 effort）、`extended`（`budget_tokens`）、`off` 三種，依模型決定可選項。
- 圖片輸入｜`_make_api_tool_result`｜截圖以 base64 PNG 放在 `tool_result` 裡。
- 多供應商｜`loop.py`｜`Anthropic`、`AnthropicBedrock`、`AnthropicVertex`。

## 六、怎麼啟動（原始做法）

README 的做法是直接跑官方映像檔，本教材沒有執行：

```bash
docker run \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -v $HOME/.anthropic:/home/computeruse/.anthropic \
    -p 5900:5900 -p 8501:8501 -p 6080:6080 -p 8080:8080 \
    -it ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest
```

原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。Bedrock 改帶 `API_PROVIDER=bedrock` 與 AWS 憑證，Vertex 改帶 `API_PROVIDER=vertex`、`CLOUD_ML_REGION`、`ANTHROPIC_VERTEX_PROJECT_ID`。啟動後開 `http://localhost:8080`。螢幕大小用 `WIDTH`、`HEIGHT` 環境變數調整。

## 七、常見陷阱

1. **「只送最近 N 張圖」在 Claude API 下不生效。** 介面預設值是 3，但 Anthropic 供應商會被迴圈歸零；只有 Bedrock、Vertex 會裁圖。
2. **最新的 toolset 不會被自動選到。** README 說側欄會預設成符合模型的版本，但 `MODEL_TO_MODEL_CONF` 沒有任何模型對應到 `computer_toolset_20260801`，預設模型 `claude-opus-4-8` 對應的是 `computer_use_20251124`，要手動切。
3. **版本名與實際類別不是一對一。** `computer_use_20250429` 用的是 `ComputerTool20250124` 與 `computer-use-2025-01-24` 旗標；`BashTool20241022` 的 `api_type` 也是 `bash_20250124`。
4. **README 的模型清單前後不一致。** 開頭說預設 Claude Opus 4.8，下面的條列還寫到 Claude 3.7／3.5 Sonnet；Bedrock 與 Vertex 的預設模型字串仍是 3.5 Sonnet，不在對照表裡，會落到 `DEFAULT_MODEL_CONF`。這些舊模型現在能不能用，從程式看不出來。
5. **解析度不要開太高。** README 建議不要超過 XGA／WXGA，並說靠 API 自動縮圖會比自己在工具裡縮放更不準、更慢。
6. **多數動作後會等 2 秒再截圖。** `_screenshot_delay = 2.0`，所以系統提示才要模型盡量把多個動作放在同一次回應。

## 八、重點回顧

- 桌面操作只有截圖與像素座標；工具負責「截圖縮小、座標放大」這一來一回。
- 工具版本是一組設定（工具類別＋beta 旗標），由 `TOOL_GROUPS` 集中管理，模型與版本要配對。
- 最新的 toolset 把每個動作變成獨立成員工具，同回合依序執行、失敗即停。
- 供應商不同，迴圈行為就不同：Anthropic 開快取不裁圖，Bedrock／Vertex 不開快取才裁圖。
- API 錯誤時這個迴圈是通知介面後直接回傳 messages，不往外丟例外。
- README 的安全提醒與第 5 章相同：專用容器、不給敏感資料、限制可連網域、有後果的動作要人確認。
