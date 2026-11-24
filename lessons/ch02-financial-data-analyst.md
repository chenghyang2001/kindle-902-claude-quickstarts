# 第 2 章　financial-data-analyst：讓 Claude 用工具輸出圖表資料的財務分析聊天

> 來源：`~/workspace/claude-quickstarts/financial-data-analyst`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

這是一個 Next.js 網頁應用：左邊聊天、右邊圖表。使用者上傳財務資料（文字檔、CSV、PDF 或圖片）並提問，Claude 一邊用文字說明，一邊呼叫名為 `generate_graph_data` 的工具，把要畫的圖表以結構化資料交出來，前端再用 Recharts 畫成圖。README 列出六種圖：折線、長條、多組長條、面積、堆疊面積、圓餅。

本章的學習重點是「把工具當成結構化輸出的出口」。這個工具在伺服器上沒有任何執行邏輯，也不會把結果回傳給模型；它存在的目的只是讓模型照 `input_schema` 填出一份圖表資料。這和「模型呼叫工具、程式執行、結果回給模型再繼續」的工具迴圈是兩回事。

README 也提到這套做法不限財務，環境數據、運動表現、社群分析、學習進度、健康紀錄都能套用，甚至可以上傳一張圖片，請它用圓餅圖統計畫面裡最常出現的東西。

## 二、架構與資料流

```text
┌───────────────────────────────┐
│ app/finance/page.tsx（瀏覽器）  │
│ 選檔 → utils/fileHandling.ts   │
│  圖片：readFileAsBase64        │
│  PDF ：readFileAsPDFText       │
│  其他：readFileAsText          │
└──────────────┬────────────────┘
               │ 文字檔內容直接併進訊息：
               │ "File contents of <檔名>:\n\n<內容>\n\n<問題>"
               │ 圖片變成 image 區塊 + text 區塊
               │ POST /api/finance  { messages, model }
               ▼
┌───────────────────────────────┐
│ app/api/finance/route.ts      │
│ runtime = "edge"              │
│ client.messages.create        │
│  tools: [generate_graph_data] │
│  tool_choice: { type: "auto" }│
│  max_tokens: 4096             │
└──────────────┬────────────────┘
               │ 回覆裡找 text 區塊與 tool_use 區塊
               ▼
┌───────────────────────────────┐
│ processToolResponse()         │
│ 檢查 chartType、data           │
│ pie：改成 segment／value       │
│ 每個數列配色 hsl(var(--chart-N))│
└──────────────┬────────────────┘
               │ { content, hasToolUse, toolUse, chartData }
               ▼
┌───────────────────────────────┐
│ components/ChartRenderer.tsx  │
│ switch (data.chartType) 畫圖   │
└───────────────────────────────┘
```

每個問題只呼叫模型一次。工具結果沒有再送回模型。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `app/api/finance/route.ts` | 460 | 工具定義、系統提示、呼叫 Claude、整理圖表資料、錯誤處理 |
| `app/finance/page.tsx` | 744 | 聊天與圖表版面、檔案上傳、把檔案內容組進訊息、送出請求 |
| `components/ChartRenderer.tsx` | 408 | 五個圖表元件與 `ChartRenderer` 的 `switch`（堆疊面積共用面積元件） |
| `utils/fileHandling.ts` | 100 | 讀文字、讀 base64、用 PDF.js 抽 PDF 文字，以及 `FileUpload` 型別 |
| `types/chart.ts` | 25 | `ChartConfig` 與 `ChartData` 型別，和工具的 `input_schema` 對應 |
| `components/FilePreview.tsx` | 92 | 上傳檔案的預覽（細節本章不展開） |
| `app/page.tsx` | 9 | 首頁直接顯示 `FinancePage` |

## 四、關鍵程式片段

**片段 1：看工具的輸入結構（`route.ts`，節錄）**

```ts
name: "generate_graph_data",
input_schema: {
  type: "object" as const,
  properties: {
    chartType: { type: "string" as const,
      enum: ["bar", "multiBar", "line", "pie", "area", "stackedArea"] as const },
    config: { /* title、description 必填；trend、footer、totalLabel、xAxisKey 選填 */ },
    data: { type: "array" as const,
      items: { type: "object" as const, additionalProperties: true } },
    chartConfig: { /* 每個鍵對應 { label 必填, stacked 選填 } */ },
  },
  required: ["chartType", "config", "data", "chartConfig"],
},
```

四個頂層欄位都必填。`data` 的每一筆允許任意欄位，所以「x 軸用哪個欄位、數值欄位叫什麼」沒有被 schema 管住，要靠系統提示的範例與 `config.xAxisKey`、`chartConfig` 的鍵名來對齊。`config.trend` 若出現，`percentage` 與 `direction`（`up` 或 `down`）都要有。

**片段 2：看怎麼呼叫模型（`route.ts`）**

```ts
const response = await client.messages.create({
  model,
  max_tokens: 4096,
  tools: tools,
  tool_choice: { type: "auto" },
  messages: anthropicMessages,
  system: `You are a financial data visualization expert. ...`,
});
```

`tool_choice` 是 `auto`，要不要畫圖由模型決定，所以純聊天的問題可以只回文字。系統提示很長：先列六種圖各自適合的情境，再給時間序列、多組比較、圓餅三組資料結構範例，最後列「一定要」與「絕對不要」，其中一條是不要對使用者說自己在用這個工具。

**片段 3：看拿到工具呼叫後做什麼（`route.ts`）**

```ts
if (chartData.chartType === "pie") {
  chartData.data = chartData.data.map((item) => {
    const valueKey = Object.keys(chartData.chartConfig)[0];
    const segmentKey = chartData.config.xAxisKey || "segment";
    return {
      segment:
        item[segmentKey] || item.segment || item.category || item.name,
      value: item[valueKey] || item.value,
    };
  });
  chartData.config.xAxisKey = "segment";
}
```

圓餅圖元件固定用 `dataKey="value"`、`nameKey="segment"`，所以後端把模型給的資料統一改成這兩個鍵。這是「模型輸出不一定照你的欄位名，程式端補一層轉換」的實例。之後所有圖都會跑一段 `reduce`，替 `chartConfig` 的每個鍵依序加上 `color: hsl(var(--chart-1))`、`--chart-2`……。

**片段 4：看文字檔怎麼進到模型（`page.tsx`）**

```ts
if (msg.file.isText) {
  const decodedText = decodeURIComponent(atob(msg.file.base64));
  return {
    role: msg.role,
    content: `File contents of ${msg.file.fileName}:\n\n${decodedText}\n\n${msg.content}`,
  };
}
```

CSV、文字檔與 PDF 抽出來的文字，都是在瀏覽器端直接併進使用者訊息的字串裡，沒有用到檔案上傳類的 API。圖片則組成 `image` 區塊（base64）加一個 `text` 區塊。模型能分析 CSV，是因為整份內容就在提示裡。

## 五、用到的 Claude 功能

- Messages API（非串流）｜`app/api/finance/route.ts`｜`client.messages.create`，每個問題一次。
- 自訂工具（tool use）｜`app/api/finance/route.ts`｜`generate_graph_data` 的 `input_schema` 規定圖表資料結構，`tool_choice: { type: "auto" }`。
- 圖片輸入｜`app/finance/page.tsx`（組訊息）｜`type: "image"`、`source.type: "base64"` 的內容區塊。
- 系統提示帶資料結構範例｜`app/api/finance/route.ts`｜三組範例教模型各種圖的資料怎麼排。
- 模型切換｜`app/finance/page.tsx`｜`models` 陣列有 `claude-haiku-4-5-20251001` 與 `claude-sonnet-5-5`，預設後者。
- 沒有用到：`tool_result` 回傳、多輪工具迴圈、串流。

## 六、怎麼啟動（原始做法）

以下照 README 整理，本教材沒有執行。

1. 進到 `financial-data-analyst` 資料夾，`npm install`（README 註明需要 Node.js 20 以上）。
2. 在專案根目錄建 `.env.local`。原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。
3. `npm run dev`，瀏覽器開 `http://localhost:3000`。

README 的技術堆疊：Next.js 14、React、TailwindCSS、Shadcn/ui、Recharts、PDF.js；後端是 Next.js API Routes、Edge Runtime、`@anthropic-ai/sdk` v1.x。

## 七、常見陷阱

1. **後端的 `fileData` 分支，這個前端用不到**：`route.ts` 會從請求取 `fileData` 並處理，但 `page.tsx` 的 `requestBody` 只有 `messages` 與 `model`。檔案內容實際上是前端先併進訊息。那段分支是給誰用的，看不出來。
2. **兩邊的文字編碼方式不同**：前端用 `btoa(encodeURIComponent(text))` 編碼，後端 `fileData` 分支卻用 `decodeURIComponent(escape(atob(base64)))` 解碼。若有人照後端分支送資料，要先確認編碼一致。
3. **圓餅圖範例的鍵名對不上**：系統提示的圓餅範例，`data` 用 `segment`、`value`，`chartConfig` 的鍵卻是 `equities`、`bonds`。`processToolResponse` 取 `chartConfig` 第一個鍵當數值欄位，取不到才退回 `item.value`；而且用的是 `||`，數值剛好是 0 也會被當成沒有值。
4. **工具結果沒有回給模型**：下一輪對話的歷史只帶助理的文字（`data.content`），不含圖表資料。模型只呼叫工具、沒寫文字時 `content` 會是空字串；這在後續對話會不會出問題，看不出來。
5. **PDF 只支援有文字層的檔案**：README 註明掃描檔不支援。`readFileAsPDFText` 是在瀏覽器動態載入 cdnjs 上的 PDF.js 3.11.174，離線環境抽不到文字。
6. **模型名稱要自己確認**：README 寫「Claude Haiku 4.5 & Claude Sonnet 5.5」，程式裡的代號是 `claude-sonnet-5-5`。這個代號在實際 API 是否可用，從原始碼看不出來。

## 八、重點回顧

- 工具在這裡是結構化輸出的出口：模型填 `input_schema`，程式拿去畫圖，沒有執行、也沒有回傳。
- 一個問題只呼叫模型一次，回覆裡同時可能有 `text` 區塊與 `tool_use` 區塊。
- `data` 允許任意欄位，欄位名稱靠 `config.xAxisKey` 與 `chartConfig` 的鍵對齊，這是最容易出錯的地方。
- 後端在交給前端之前會補一層轉換：圓餅圖統一成 `segment`／`value`，並依序配上顏色變數。
- 檔案內容是在瀏覽器端併進提示的，圖片才用 `image` 內容區塊。
- `types/chart.ts`、工具 schema、`ChartRenderer` 的 `switch` 三處的六種 `chartType` 必須一致。
