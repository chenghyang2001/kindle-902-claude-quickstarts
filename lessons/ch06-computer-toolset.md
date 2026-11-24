# 第 6 章　computer-toolset：用 VNC 寫一個最小的電腦操作工具組驅動程式

> 來源：`~/workspace/claude-quickstarts/computer-toolset`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

README 的定位是：Claude 電腦操作工具組（`computer_toolset_20260801`）的「最小 VNC 範例」，Python 與 TypeScript 各一份。和第 4 章同一個模式：在 `tools` 裡宣告一個工具組項目，模型把每個桌面動作（`screenshot`、`left_click`、`type` 等）當成獨立工具來呼叫，由驅動程式在真的桌面上執行。

驅動程式 `VncComputer` 不用任何 VNC 函式庫，直接用 socket 與 `struct` 講 RFB 協定（VNC 的底層協定），控制一個桌面，實作工具組裡的十個工具：`screenshot`、`left_click`、`right_click`、`double_click`、`triple_click`、`mouse_move`、`scroll`、`type`、`key`、`wait`。其餘工具（`zoom`、`left_click_drag`、`left_mouse_down`、`left_mouse_up`、`middle_click`、`hold_key`、`cursor_position`）沒有實作，由 SDK 回報為停用並拒絕。

和第 4 章最大的差別有兩個：模型靠「截圖」看環境，而不是文字清單；`run.py` 在每個會改變桌面的動作前，都先問終端機前的人要不要放行。

## 二、架構與資料流

```text
┌──────────────┐  task（整個命令列）
│  run.py      │──────────────────────────────┐
└──────┬───────┘                              ▼
       │ tools=[computer]          ┌─────────────────────┐
       │                           │ SDK tool runner     │
       │                           │ client.beta.messages│
       │                           │ .tool_runner(...)   │
       │                           └───┬─────────────▲───┘
       │                      tool_use │             │ tool_result
       ▼                               ▼             │（PNG 圖片或 is_error）
┌───────────────────────────────────────────────────┴───┐
│ SDK 抽象類別 BetaAbstractComputerToolset20260801       │
│ ・產生工具 schema  ・拒絕未實作工具  ・呼叫 confirm    │
└───────────┬──────────────────────────┬────────────────┘
            │ confirm=ask              │ 放行後呼叫子類別方法
            ▼                          ▼
┌────────────────────┐   ┌─────────────────────────────────┐
│ 終端機前的人 y/N   │   │ VncComputer（vnc_computer.py）   │
│ （screenshot 免問）│   │ _handshake / _move / _keys /    │
└────────────────────┘   │ _click / screenshot             │
                         └───────────────┬─────────────────┘
                                         │ RFB 訊息（TCP 5900）
                                         ▼
                         ┌─────────────────────────────────┐
                         │ VNC 伺服器（無密碼，例：Xvnc）   │
                         │ 一個桌面，最大 1920×1200        │
                         └─────────────────────────────────┘
```

`exercise.py` 走同一條路，只是把模型換成手寫的 `tool_use`，並把 `confirm` 換成一律放行的 `lambda context: True`。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `python/vnc_computer.py` | 217 | 範例驅動程式：RFB 握手、鍵碼表 `KEYSYMS`、滑鼠與鍵盤事件、截圖轉 PNG、十個工具方法 |
| `python/run.py` | 68 | 入口：建立驅動程式與確認函式 `ask`，交給 tool runner，逐則印出模型訊息 |
| `python/exercise.py` | 127 | 不用模型、不用金鑰的冒煙檢查：對 VNC 伺服器送八種呼叫並用 `assert` 檢查 |
| `python/requirements.txt` | 4 | `anthropic>=2.0.0,<3`、`pillow>=10`、`typing_extensions>=4.14` |
| `typescript/vnc-computer.ts`、`run.ts`、`exercise.ts` | 325／71／122 | 同一套做法的 TypeScript 版（類別同名 `VncComputer`，迴圈用 `client.beta.messages.toolRunner`） |
| `README.md` | 96 | 安裝、VNC 伺服器指令、執行、實作了什麼與沒做什麼 |

## 四、關鍵程式片段

**片段 1：看一次滑鼠事件長什麼樣子**（`_move`）

```python
def _move(self, x: int, y: int, buttons: int = 0) -> None:
    if not (0 <= x < self.width and 0 <= y < self.height):
        raise ToolError(f"({x}, {y}) is outside the {self.width}x{self.height} screen")
    self._socket.sendall(struct.pack(">BBHH", 5, buttons, x, y))
    self._cursor = (x, y)
```

RFB 的 PointerEvent 只有六個位元組：訊息型別 5、按鍵遮罩、x、y。超出螢幕的座標是「拒絕」而不是「夾回邊界」，docstring 寫明原因：要讓模型看到自己的錯。`self._cursor` 記住最後位置，因為 VNC 沒辦法回報游標在哪。

**片段 2：看點擊、雙擊、捲動怎麼共用同一個函式**（`_click`）

```python
x, y = coordinate or self._cursor
self._move(x, y)
held = [keysym(name) for name in modifiers.split("+")] if modifiers else []
self._keys(held, True)
for _ in range(times):
    self._move(x, y, button)
    self._move(x, y)
    time.sleep(0.01)
self._keys(held, False)
```

一次點擊就是「帶按鍵遮罩送一次、不帶遮罩再送一次」。`double_click`、`triple_click` 只是 `times=2`、`times=3`；`scroll` 則把滾輪當成四顆按鍵（`WHEEL = {"up": 8, "down": 16, "left": 32, "right": 64}`），捲幾格就按幾次。沒給座標時用上次的游標位置，`text` 裡的修飾鍵在點擊期間按住。

**片段 3：看截圖怎麼要、怎麼收**（`screenshot` 節錄）

```python
time.sleep(0.5)  # VNC has no signal that an action is done, so the desktop gets time to draw the last one.
self._socket.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, self.width, self.height))
while (kind := self._read(1)[0]) != 0:
    if kind == 3:
        self._read(struct.unpack(">3xI", self._read(7))[0])
    elif kind != 2:
        raise RuntimeError(f"unexpected message type {kind} from the VNC server")
```

先睡 0.5 秒讓桌面畫完上一個動作，再送 FramebufferUpdateRequest（型別 3）要整個螢幕，然後略過剪貼簿（3）與鈴聲（2）訊息，直到收到 FramebufferUpdate（0）。之後把 Raw 編碼的像素拼成整張畫面，用 Pillow 存成 PNG、轉 base64 放進 `BetaScreenshotResult`。畫面不縮放，所以連線時就拒絕超過 1920×1200 的螢幕。

**片段 4：看人工確認怎麼接上去**（`run.py` 的 `ask`）

```python
def ask(context: BetaComputerConfirmContext) -> bool:
    if context.member == "screenshot":
        return True
    call = json.dumps(context.input.model_dump(exclude_none=True))
    return input(f"Allow {context.member} {call}? [y/N] ").strip().lower() == "y"
```

`confirm` 是工具組的建構選項，回傳 `True` 才執行。截圖不改變桌面所以免問，其餘動作都把工具名稱與參數印給人看。用 `json.dumps` 的理由寫在註解裡：它會把看不見的字元跳脫出來。回答不是 `y` 時模型會收到什麼，從這個資料夾看不出來。

## 五、用到的 Claude 功能

- 電腦操作工具組（`computer_toolset_20260801`）｜`vnc_computer.py` 繼承 `BetaAbstractComputerToolset20260801`｜一個工具組項目展開成多個桌面工具；型別字串只出現在 README，程式裡只看得到類別名稱。
- Tool runner｜`run.py` 的 `client.beta.messages.tool_runner(...)`（`max_tokens=4096`）｜自動跑截圖→動作→再截圖的工具迴圈。
- `confirm` 選項｜`run.py` 的 `ask`、`exercise.py` 的 `lambda context: True`｜每個工具執行前的人工把關。
- 圖片型工具結果｜`screenshot` 回傳 `BetaScreenshotResult(data=...)`｜把 PNG 以 base64 交給模型看。
- `ToolError`｜`vnc_computer.py`｜座標出界、不認得的鍵名都變成 `is_error` 的工具結果。
- 是否需要額外的 beta 標頭：看不出來（程式沒有自己設定）。

## 六、怎麼啟動（原始做法）

以下照 README 抄錄，本教材沒有執行。原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）、Python 3.10+，以及一個沒有密碼、螢幕不超過 1920×1200 的 VNC 伺服器。

```bash
Xvnc :1 -geometry 1280x800 -depth 24 -SecurityTypes None -localhost -rfbport 5900 &
DISPLAY=:1 xterm -geometry 160x50 &

cd computer-toolset/python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python run.py "Open a terminal, run date, and tell me today's date and time zone"
python exercise.py        # 不需要金鑰，但仍需要 VNC 伺服器與 SDK
```

環境變數：`VNC_HOST`（預設 `127.0.0.1`）、`VNC_PORT`（預設 `5900`）、`MODEL`（預設 `claude-sonnet-5-5`）。

## 七、常見陷阱

1. **伺服器沒有密碼，一定要留在 localhost**。README 的警告：兩個啟動指令都帶 `-localhost`；從容器對外只能發布到主機的 loopback（`-p 127.0.0.1:5900:5900`）。
2. **畫面上的東西會牽著模型走，聚焦的終端機會執行它打的任何字**。README 要求只對拋棄式桌面、在沙箱裡執行。
3. **截圖可能是舊的**。VNC 沒有「動作做完了」的訊號，驅動程式只能先睡 0.5 秒；用 `x11vnc` 時更明顯，`exercise.py` 因此讓第二張截圖最多重試五次。
4. **`shift+a` 打出來是 `a`**。README 的 Left out：按住 shift 時字母不會變大寫。`type` 則是逐字送鍵碼，每個字之間睡 0.012 秒，避免終端機回顯與輸出交錯。
5. **`wait` 沒有上限**。和第 4 章的瀏覽器驅動程式不同，這裡直接 `time.sleep(input.duration)`，模型要求多久就睡多久。
6. **只支援 Raw 編碼與 RFB 3.7 以上**。每張截圖都是未壓縮的整個螢幕，1280×800 約 4 MB，在 localhost 沒問題、遠端會很慢；伺服器停止回應時截圖等 10 秒後失敗，之後每次都失敗，要重建驅動程式才能重連。

## 八、重點回顧

- 電腦操作的迴圈是「截圖 → 模型決定動作 → 執行 → 再截圖」，驅動程式只負責把動作翻成協定訊息。
- 整個驅動程式只用五種 RFB 用戶端訊息：SetPixelFormat（0）、SetEncodings（2）、FramebufferUpdateRequest（3）、KeyEvent（4）、PointerEvent（5）。
- 點擊、雙擊、三擊、捲動共用同一個 `_click`，差別只在按鍵遮罩與次數。
- 錯誤要讓模型看得到：座標出界是拒絕而不是修正，鍵名不認得會回報可用的寫法。
- `confirm` 是放在工具組上的人工把關點，截圖免問、其他動作逐一確認。
- 範例刻意不做縮放、密碼、拖曳、壓縮編碼與斷線復原，README 說正式的驅動程式大多需要這些。
