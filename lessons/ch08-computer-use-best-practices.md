# 第 8 章　computer-use-best-practices：把 computer use 的每個細節攤開來看的教學實作

> 來源：`~/workspace/claude-quickstarts/computer-use-best-practices`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

這是一份「拿來讀、拿來改」的 computer use 參考實作，README 開頭就說它不是函式庫，也不是可上線的 SDK，而是搭配官方最佳實務文章一起讀的教材。它只支援 macOS：直接在本機（不用 Docker）用 `pyautogui` 操作真實的滑鼠、鍵盤與螢幕，另外用 Playwright 開一個無頭 Chromium 當瀏覽器工具。

README 第一段是警告：代理能完整控制你的電腦，沒有任何防護，強烈建議只在用完即丟的 macOS 虛擬機裡跑。

它要示範的重點有七件：

1. 工具全部明確定義：模型看到的每個工具名稱、說明、JSON schema 都寫在 `computer_use/tools/`。
2. 截圖尺寸要先縮好，點擊座標才不會漂移。
3. prompt caching 與「不破壞快取」的舊截圖裁剪。
4. 伺服器端 context 壓縮（compaction）。
5. 批次工具 `computer_batch`／`browser_batch`，一回合送多個動作。
6. 用 `sandbox-exec` 包起來的 `bash`／`python`。
7. 把整段軌跡寫到 `runs/` 供事後檢視；另有可選的 advisor 工具（預設關閉）。

## 二、架構與資料流

```text
┌──────────────┐  task   ┌─────────────────────────────────────────┐
│ __main__.py  │────────▶│ loop.py  sampling_loop()                 │
│ build_tools  │         │                                          │
│ Trajectory   │         │  每一回合送出前：                        │
└──────────────┘         │  ① _truncate_to_last_compaction         │
                         │  ② prune(messages)   舊截圖→[Image Omitted]│
                         │  ③ _set_trailing_cache_control          │
                         └───────────────┬──────────────────────────┘
                                         │ messages.stream
                                         ▼
                         ┌──────────────────────────────┐
                         │ Claude API                    │
                         │ （可選：compaction、advisor） │
                         └───────────────┬──────────────┘
                                         │ tool_use 區塊
                                         ▼
┌────────────────────────────────────────────────────────────────┐
│ ToolCollection.run                                              │
│  computer / computer_batch / open_application  → pyautogui      │
│  browser / browser_batch                       → Playwright     │
│  bash / python                                 → sandbox-exec   │
│  editor                                        → runs/<ts>/scratch │
└───────────────┬────────────────────────────────────────────────┘
                │ tool_result（文字＋縮好的 JPEG）
                ▼
        接回 messages ──▶ 下一回合；每一筆同時寫進
        runs/<時間戳>/transcript.jsonl 與 images/NNN.jpg
```

迴圈一直跑到模型不再呼叫工具（`end_turn`）或達到 `max_iters`（預設 200），互動模式下再等使用者輸入下一句。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `constants.py` | 430 | `Config` dataclass（所有可調參數）、模型清單、系統提示、`BATCH_REMINDER` 等常數 |
| `computer_use/__main__.py` | 105 | CLI 入口、`build_tools()`、`build_system_prompt()` |
| `computer_use/loop.py` | 565 | 串流取樣迴圈、重試、快取斷點、compaction 與 advisor 接線、批次提醒 |
| `computer_use/image.py` | 100 | `target_image_size()` 截圖縮放、JPEG 編碼、過小截圖檢查 |
| `computer_use/formatters.py` | 95 | 舊截圖裁剪：`StripOldestImages`、`StripImagesAtIntervals` |
| `computer_use/tools/computer.py` | 455 | `ComputerTool`：schema、座標換算、`zoom`、按鍵轉換 |
| `computer_use/tools/batch.py` | 105 | `_BatchTool`：依序執行、遇錯即停 |
| `computer_use/tools/shell.py` | 135 | 沙箱 `bash`／`python`：30 秒逾時、輸出上限 |
| `sandbox/default.sb` | 35 | `sandbox-exec` 設定檔：可讀、只能寫 scratch、禁網路 |
| `computer_use/trajectory.py` | 60 | 軌跡錄製與每次執行的 scratch 資料夾 |
| `computer_use/tools/base.py` | 125 | `Tool` 基底類別與 `ToolCollection` |

## 四、關鍵程式片段

看什麼：截圖送出前怎麼判斷「不必縮」（`computer_use/image.py`）。

```python
def n_tokens_for_px(px: int, px_per_token: int = cfg.px_per_token) -> int:
    return (px - 1) // px_per_token + 1

    if (
        width <= max_edge_px
        and height <= max_edge_px
        and n_tokens_for_img(width, height, px_per_token) <= max_tokens
    ):
        return width, height
```

API 的視覺編碼器把圖切成 28×28 的格子，長邊上限 1568 px、格子總數上限 1568。超過任一條件，伺服器會再縮一次，模型回傳的座標就落在「你沒看過的那張圖」上；檔頭註解寫 16:10 的 MacBook 螢幕會漂移約 14%。所以程式先用二分搜尋找出同時滿足兩個條件的最大尺寸，並記住送出的寬高，再把模型座標換算回螢幕座標。

看什麼：為什麼「只留最後 N 張」會讓快取每回合都失效（`computer_use/formatters.py`）。

```python
slots = _image_slots(messages)
total = len(slots)
self._offset = max(0, min(self._offset, total))
keep = ((total - self._offset) % self.interval) + self.min_images
if total > keep:
    for container, i in slots[: total - keep]:
        container[i] = dict(_PLACEHOLDER)
```

保留張數從 `min_images` 一路爬到 `min_images + interval - 1` 再掉回來。在同一個週期內，被換成 `[Image Omitted]` 的永遠是同一批舊圖，請求的前綴位元組不變，prompt cache 才能持續命中。預設值是 `image_prune_min=3`、`image_prune_interval=40`，也就是每 40 張截圖才付一次快取重寫。

看什麼：批次工具遇錯即停（`computer_use/tools/batch.py`）。

```python
for i, step in enumerate(actions):
    label = f"{i}:{step.get('action', '?')}"
    try:
        res = self._inner.execute(**step)
    except Exception as e:
        res = ToolResult(error=f"{type(e).__name__}: {e}")
    done.append((label, res))
    if res.is_error:
        remaining = len(actions) - i - 1
        return _BatchResult(done, error=(...))
```

批次裡每個動作的形狀和單次 `computer` 呼叫完全一樣，外層只是一個迴圈。第一個動作失敗就停，錯誤訊息會寫出「完成幾個、跳過幾個」。批次內所有座標都以「批次之前那張截圖」為準，所以系統提示要求在可能改變畫面的批次最後加一個 `screenshot`。

看什麼：模型只送一個單獨動作時，迴圈怎麼提醒它（`computer_use/loop.py`）。

```python
nudge = _should_nudge_batch(tool_uses)
...
content = res.to_api_content()
if nudge and not res.is_error:
    content.append({"type": "text", "text": BATCH_REMINDER})
```

`_should_nudge_batch` 只在整回合只有一個 `tool_use`，而且動作屬於 `BATCH_REMINDER_ACTIONS`（點擊、輸入、按鍵、捲動、等待、`navigate` 等）時回傳 True；單獨截圖或已經用批次則不提醒。提醒文字是附在工具結果後面的 `<reminder>`，不是改系統提示。

## 五、用到的 Claude 功能

- 明確定義的 client 端工具｜`computer_use/tools/*.py`｜每個工具自帶 `name`、`description`、`input_schema`，由 `ToolCollection.to_params()` 組成 `tools`。
- 託管的 computer 工具組 `computer_toolset_20260801`｜`constants.py`、`loop.py`｜`use_hosted_computer_tool=True` 時改用伺服器端宣告，換取 computer use 專屬的安全分類器；Vertex／Bedrock 退回 `computer_20250124` 加 beta 標頭 `computer-use-2025-01-24`。
- 串流｜`loop.py` 的 `_stream_and_render`｜邊收邊印 thinking、文字與工具呼叫。
- Prompt caching｜`loop.py`｜系統提示一個 `cache_control` 斷點，訊息本體最後幾個 `tool_result`／`compaction` 區塊最多再放 3 個。
- 伺服器端 compaction `compact_20260112`｜`loop.py` 的 `_autocompaction_edit`｜輸入超過 `autocompaction_trigger_tokens`（預設 150,000）時由伺服器摘要舊內容；beta 標頭 `compact-2026-01-12`。
- Advisor 工具 `advisor_20260301`｜`loop.py` 的 `_advisor_tool_param`｜執行模型中途請教較強的模型（預設 `claude-opus-4-6`）；完全在伺服器端執行，預設關閉。
- 推理強度 `output_config.effort`｜`loop.py` 的 `_effort_kwargs`｜`off` 時送 `thinking={"type": "disabled"}`。
- 多供應商 client｜`loop.py` 的 `_make_client`｜`anthropic`、`vertex`、`bedrock` 三選一。

## 六、怎麼啟動（原始做法）

以下照 README 抄錄，本教材沒有執行（需要 macOS、螢幕錄製與輔助使用權限，而且會動到真實滑鼠鍵盤）。原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。

```bash
python -m pip install -r requirements.txt && python -m playwright install chromium
python -m computer_use "open TextEdit and type hello world"
```

只用瀏覽器、不碰桌面的版本：

```bash
CU_ENABLE_COMPUTER_USE_TOOLS=false python -m computer_use "..."
```

其他入口：`python -m streamlit run dev_ui/trajectory_viewer/app.py`（看軌跡）、`python -m uvicorn dev_ui.tool_panel.server:app --reload`（手動測工具）、`python -m pytest`（測試）。需要 Python 3.11 以上。

## 七、常見陷阱

1. 截圖沒先縮就送：伺服器會再縮一次，座標系對不上。`browser_viewport` 預設 `(1456, 819)` 就是為了讓瀏覽器截圖剛好不必縮。
2. 用 `"simple"` 策略裁舊圖：超過上限後每回合換掉的圖都不同，快取每回合失效。README 還提醒，短任務最省的做法其實是完全不裁（`"none"`）。
3. 明確 schema 不會觸發 computer use 專屬安全分類器（含截圖內容的提示注入偵測），要自己負責防護，或改用託管宣告。
4. compaction 與 advisor 只有第一方 API 支援；`provider` 不是 `anthropic` 又開著，`Config.__post_init__` 會直接丟 `ValueError`。compaction 也只對 `AUTOCOMPACTION_SUPPORTED_MODELS` 生效，`claude-haiku-4-5` 會被靜默略過。
5. 文件與程式有兩處不一致：`constants.py` 開頭註解提到 CLI 的 `--config` 與 `--set`，但 `__main__.py` 的 argparse 沒有這兩個參數；README 說訊息本體只放一個快取斷點，`loop.py` 實際最多放 3 個。以程式為準。
6. 沙箱是「可讀大部分檔案、只能寫 scratch、禁網路」，並另外擋掉 `~/.ssh`、`~/.aws`、`.env` 等路徑；它不是完整隔離，README 仍要求在虛擬機裡跑。

## 八、重點回顧

- 這個專案的價值在「看得到」：工具定義、截圖尺寸、快取斷點全部寫在程式裡，沒有藏在伺服器預設值後面。
- 座標正確的前提是模型看到的圖就是你送的圖，所以要自己先縮到 28 px 格子與 1568 上限以內。
- 控制 context 有三層：快取（便宜地重送）、裁舊截圖（刪圖不刪字）、compaction（整段摘要，最貴但保留最多資訊）。
- 批次工具把「可預測的連續動作」併成一回合，省延遲也省費用；遇錯即停，最後補一張截圖驗證。
- 它只處理單一 session 內的 context 壓力；跨 session 接續的機制在程式裡沒有看到。
- 軌跡（`transcript.jsonl` 加圖片）是除錯與教學的主要材料，圖片存檔案路徑而不是 base64。
