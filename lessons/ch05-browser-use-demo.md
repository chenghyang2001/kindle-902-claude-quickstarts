# 第 5 章　browser-use-demo：用元素參照（ref）而不是像素座標操作網頁

> 來源：`~/workspace/claude-quickstarts/browser-use-demo`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

這是一個「讓 Claude 操作瀏覽器」的最小參考實作。整個東西包在一個 Docker 容器裡：Streamlit 聊天介面收使用者的話，代理迴圈呼叫 Claude，Claude 透過一個名叫 `browser` 的自訂工具下指令，工具再用 Playwright 驅動容器內的 Chromium；畫面由 Xvfb 虛擬顯示器輸出，使用者可以從 noVNC 看到瀏覽器實際在做什麼。

它和第 7 章 computer-use-demo 最大的差別在「怎麼指到畫面上的東西」。桌面操作只能看截圖、回報像素座標；這個專案多了一條路：先用 `read_page` 把頁面轉成一棵帶編號的元素樹（`ref_1`、`ref_2`……），之後點擊、填表、捲動都可以直接給 `ref`。README 把好處講得很直接：元素參照不受視窗大小與版面影響，像素座標一換解析度就失準。

另一個重點是工具的宣告方式。這裡沒有用 Anthropic 定義好的工具型別，而是自己寫 `name`、`description`、`input_schema` 三個欄位的一般自訂工具，一個工具用 `action` 參數分出 23 種動作。README 說這份 schema 可以直接拿去當自己專案的起點。

## 二、架構與資料流

```text
┌──────────────┐  文字  ┌─────────────────────────────┐
│ 使用者        │──────▶│ streamlit.py  run_agent()    │
│ (localhost:   │       │ 把 BrowserTool 存在           │
│  8080)        │◀──────│ session_state，跨輪重用       │
└──────────────┘ 繪製   └──────────────┬──────────────┘
                                       │ messages
                                       ▼
                        ┌─────────────────────────────┐
                        │ loop.py  sampling_loop()     │
                        │ while True:                  │
                        │  1 呼叫 Claude（system 加     │
                        │    cache_control）           │
                        │  2 ResponseProcessor 拆出     │
                        │    text 與 tool_use          │
                        │  3 有 tool_use → 執行工具     │
                        │    沒有 → return messages    │
                        └──────────────┬──────────────┘
                                       │ tool(**input)
                                       ▼
                        ┌─────────────────────────────┐
                        │ tools/browser.py BrowserTool │
                        │ __call__ 依 action 分派       │
                        └───────┬─────────────┬───────┘
                 Playwright API │             │ page.evaluate()
                                ▼             ▼
                   ┌────────────────┐  ┌──────────────────────┐
                   │ Chromium        │  │ browser_tool_utils/   │
                   │ (Xvfb :1)       │  │ *.js 產生／查詢 ref    │
                   └───────┬────────┘  └──────────────────────┘
                           ▼
                   ┌────────────────┐
                   │ x11vnc / noVNC  │──▶ 使用者從 6080 看畫面
                   └────────────────┘
```

工具結果（文字、base64 截圖、錯誤）由 `ResponseProcessor._build_tool_result` 包成 `tool_result` block，全部塞進同一則 user 訊息，再回到迴圈第 1 步。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `browser_use_demo/loop.py` | 210 | `sampling_loop`、`BROWSER_SYSTEM_PROMPT`、`APIProvider`、prompt caching 旗標、（沒被呼叫的）裁圖函式 |
| `browser_use_demo/message_handler.py` | 290 | `ResponseProcessor`（拆回應、執行工具、組 `tool_result`）與 `MessageBuilder` |
| `browser_use_demo/tools/browser.py` | 1,275 | `BROWSER_TOOL_INPUT_SCHEMA`、`BrowserTool` 與 23 個動作的 Playwright 實作 |
| `browser_use_demo/tools/coordinate_scaling.py` | 180 | `CoordinateScaler`：把模型看到的座標換算回 1920x1080 |
| `browser_use_demo/browser_tool_utils/browser_dom_script.js` | 450 | 產生無障礙樹與 `ref_N`，存進 `window.__claudeElementMap` |
| `browser_use_demo/browser_tool_utils/browser_element_script.js` | 90 | 用 `ref` 找回元素、捲到畫面中央、回傳中心座標 |
| `browser_use_demo/streamlit.py` | 740 | 聊天介面、模型清單、對話紀錄下載、事件迴圈重用 |
| `browser_use_demo/display_constants.py` | 15 | 寫死的 1920x1080 與 `DISPLAY_NUM = 1` |
| `Dockerfile`、`docker-compose.yml`、`image/` | — | Ubuntu 22.04、Python 3.11.6、Playwright Chromium、Xvfb／noVNC 啟動腳本 |
| `tests/test_sampling_loop.py` | 540 | 用 mock 驗證「文字與工具呼叫要一起保留」等行為 |

## 四、關鍵程式片段

**片段 1：看 ref 是怎麼發出來的**（`browser_dom_script.js`）

```javascript
if (!ref) {
  ref = "ref_" + ++window.__claudeRefCounter;
  window.__claudeElementMap[ref] = new WeakRef(element);
}
var yaml = indent + "- " + role;
// ...
yaml += " [ref=" + ref + "]";
```

每個被收進樹裡的元素拿到一個流水號，對照表掛在頁面的 `window` 上，值是 `WeakRef`。輸出是一行一個元素的縮排文字，例如 `- textbox "Search" [ref=ref_3]`。因為對照表活在頁面裡，元素被移除後再用舊 ref，`browser_element_script.js` 會回 `No element found with reference`。

**片段 2：看 ref 點擊其實還是變成座標**（`browser.py` 的 `_click`）

```python
element_info = await self._execute_js_from_file(
    "browser_element_script.js", ref
)
if not element_info.get("success", False):
    raise ToolError(element_info.get("message", "Failed to find element"))
click_x, click_y = element_info["coordinates"]
await self._page.mouse.move(click_x, click_y)
await self._page.mouse.click(click_x, click_y, button=button, click_count=click_count)
```

ref 並不是呼叫 DOM 的 `click()`，而是「當下」向頁面問這個元素的中心點，再用真的滑鼠事件點下去。差別在座標是程式即時量的，不是模型從截圖估的，所以不必經過座標換算。

**片段 3：看迴圈怎麼結束**（`loop.py`）

```python
builder.add_assistant_message(messages, processed.assistant_content)
if processed.tool_uses:
    tool_results = await processor.execute_tools(
        processed.tool_uses, tool_collection, tool_output_callback
    )
    builder.add_tool_results(messages, tool_results)
else:
    return messages
```

結束條件只有一個：這次回應裡沒有 `tool_use`。助理訊息是把文字與工具呼叫原樣一起存回去，測試檔 `test_sampling_loop_preserves_text_with_tools` 專門驗這件事。迴圈本身沒有步數上限。

**片段 4：看給介面的摘要怎麼被剝掉**（`message_handler.py`）

```python
if "__PAGE_EXTRACTED__" in output_text or "__TEXT_EXTRACTED__" in output_text:
    if "__FULL_CONTENT__" in output_text:
        marker_pos = output_text.index("__FULL_CONTENT__")
        output_text = output_text[marker_pos + len("__FULL_CONTENT__") + 1:]
```

`read_page` 與 `get_page_text` 的輸出前面夾了一段給介面顯示的摘要（估算 token 數用「字元數除以 3.5」）。送回給模型之前，這段摘要與標記會被切掉，模型只收到完整內容。

## 五、用到的 Claude 功能

- 自訂工具（client tool）｜`tools/browser.py` 的 `to_params`｜用 `name`＋`description`＋`input_schema` 宣告單一 `browser` 工具。
- 工具呼叫迴圈｜`loop.py`、`message_handler.py`｜`tool_use` → 執行 → `tool_result`，直到沒有工具呼叫。
- 圖片輸入｜`message_handler.py` 的 `_build_tool_result`｜截圖以 base64 PNG 放進 `tool_result` 的 content。
- Prompt caching｜`loop.py`｜只有 `APIProvider.ANTHROPIC` 時，在 system 區塊加 `cache_control`，並送出 `PROMPT_CACHING_BETA_FLAG`（`prompt-caching-2024-07-31`）。
- 多供應商用戶端｜`loop.py`｜`Anthropic`、`AnthropicBedrock`、`AnthropicVertex` 三種；但介面的 provider 選單只有 Anthropic 且停用。
- 工具裡再呼叫一次模型｜`browser.py` 的 `_find`｜把無障礙樹交給 `claude-sonnet-5-5`（`max_tokens=800`）挑出符合的 ref。

## 六、怎麼啟動（原始做法）

README 的步驟如下，本教材沒有執行：

```bash
cd claude-quickstarts/browser-use-demo
cp .env.example .env        # 再編輯 .env
docker-compose up --build   # 開發時可加 --watch
```

原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。容器的 `entrypoint.sh` 會先跑 `validate_env.py` 檢查金鑰，再啟動 Xvfb、tint2、mutter、x11vnc、noVNC 與 Streamlit。README 列的入口是 `http://localhost:8080`（README 稱為 Streamlit 主介面；`entrypoint.sh` 裡 Streamlit 本身開在 8501，8080 是另一支 `http_server.py`）、`http://localhost:6080`（noVNC）與 `localhost:5900`（VNC）。

## 七、常見陷阱

1. **裁圖參數沒有作用。** `streamlit.py` 傳了 `only_n_most_recent_images=3`，`loop.py` 也定義了 `_maybe_filter_to_n_most_recent_images`，但整個專案沒有任何地方呼叫它；而且這個函式只數 user 訊息最上層的 image block，截圖實際上放在 `tool_result` 裡面。長對話的截圖會一直累積。
2. **「每輪開頭會收到截圖」在程式裡看不出來。** `BROWSER_SYSTEM_PROMPT` 這樣寫，但 `run_agent` 只把使用者的文字加進 messages，沒有看到自動附截圖的程式。
3. **點擊時座標優先於 ref，hover 則相反。** `_click` 先判斷 `coordinate` 再判斷 `ref`；`_hover` 先判斷 `ref`。兩個都給的話，行為不一樣。
4. **座標換算是經驗值。** `CoordinateScaler` 假設模型看到的是 1456x819，把座標乘上約 1.3187；超過 1456、819 各自的 1.2 倍就當成「已經是實際座標」不換算。`browser.py` 的註解自己說建議做法是用戶端先縮圖。
5. **`find` 會默默退回。** 它另外用環境變數的金鑰呼叫模型，任何例外都被 `except Exception: pass` 吃掉，退回只回報筆數、不給 ref 的文字比對。`CHANGELOG.md` 記錄了兩次因此而起的修正。
6. **Google 搜尋會遇到 CAPTCHA。** README 建議在提示詞裡直接指定網站，不要先上搜尋引擎。

## 八、重點回顧

- 這個專案用一個自訂工具加 `action` 參數包住 23 種瀏覽器動作，schema 完全自己掌控。
- `read_page` 把頁面轉成帶 `ref_N` 的文字樹，後續操作用 ref，比截圖估座標穩定。
- ref 點擊的本質是「即時向頁面問座標再用滑鼠點」，ref 失效時工具回錯誤、由模型重新 `read_page`。
- 讀內容用 `get_page_text`，截圖只拿來確認畫面；系統提示把這個順序寫得很明白。
- 迴圈的結束條件是「回應裡沒有工具呼叫」，沒有步數上限，也沒有實際生效的截圖裁剪。
- README 的安全提醒：隔離環境、不給帳密、網域白名單、有後果的動作要人確認，並留意網頁內容的提示詞注入。
