# 第 1 章　customer-support-agent：用知識庫檢索加結構化 JSON 回覆做客服聊天

> 來源：`~/workspace/claude-quickstarts/customer-support-agent`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

這是一個 Next.js 做的客服聊天網頁。使用者在聊天框問問題，後端先到 Amazon Bedrock Knowledge Bases 找相關文件片段，再把片段塞進系統提示交給 Claude 回答。README 列的特色有六項：Claude 聊天、Bedrock 知識檢索、即時顯示思考與除錯資訊、顯示知識來源、偵測使用者情緒並轉接真人、用 shadcn/ui 做可自訂的介面。

這個專案最值得學的不是畫面，而是「回覆契約」：Claude 每次都必須回一個固定欄位的 JSON 物件，裡面除了給使用者看的 `response`，還有 `thinking`、`user_mood`、`suggested_questions`、`debug.context_used`、`matched_categories`、`redirect_to_agent`。前端的三個區塊（聊天區、左側欄、右側欄）各自取用其中幾個欄位。也就是說，一次模型呼叫同時完成回答、情緒判斷、問題分類、建議追問、是否轉真人五件事。

README 的附錄明講這是原型，不適合直接上線。

## 二、架構與資料流

```text
┌──────────────────────────┐
│ ChatArea.tsx（瀏覽器）     │
│ 選模型、選知識庫、送出問題  │
└────────────┬─────────────┘
             │ POST /api/chat  { messages, model, knowledgeBaseId }
             ▼
┌──────────────────────────┐      ┌──────────────────────────────┐
│ app/api/chat/route.ts    │ ───▶ │ app/lib/utils.ts              │
│ 取最後一則訊息當查詢       │      │ retrieveContext()             │
│                          │ ◀─── │ Bedrock RetrieveCommand，n=3  │
└────────────┬─────────────┘      └──────────────────────────────┘
             │ 系統提示 = 角色 + 檢索片段 + 分類清單 + JSON 格式與兩個範例
             │ 訊息最後補一則 assistant「{」
             ▼
┌──────────────────────────┐
│ client.messages.create   │  max_tokens: 1000
└────────────┬─────────────┘
             │ "{" + 文字 → sanitizeAndParseJSON → responseSchema.parse
             ▼
┌──────────────────────────┐
│ Response：JSON 本文        │
│ 標頭 x-rag-sources、       │
│ X-Debug-Data              │
└────────────┬─────────────┘
             ▼
┌──────────────────────────────────────────────────────────┐
│ ChatArea.tsx 發出瀏覽器事件                                 │
│ updateSidebar（思考、情緒、分類）→ 左側欄                    │
│ updateRagSources（來源片段）→ 右側欄                        │
│ agentRedirectRequested（should_redirect 為 true 時）       │
└──────────────────────────────────────────────────────────┘
```

整條路沒有串流，也沒有工具呼叫：一次檢索、一次模型呼叫、一次回傳。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `app/api/chat/route.ts` | 303 | 後端主流程：檢索、組系統提示、呼叫 Claude、解析與驗證 JSON、回傳 |
| `app/lib/utils.ts` | 95 | `retrieveContext()`：呼叫 Bedrock 知識庫，整理出 `context` 與 `ragSources` |
| `components/ChatArea.tsx` | 724 | 聊天畫面、模型與知識庫下拉選單、送出請求、發事件給側欄 |
| `app/lib/customer_support_categories.json` | 90 | 8 個客服分類（`id`、`name`、`keywords`） |
| `config.ts` | 11 | 讀兩個 `NEXT_PUBLIC_` 環境變數，決定左右側欄要不要顯示 |
| `components/LeftSidebar.tsx` | 193 | 接 `updateSidebar` 事件顯示思考與除錯資訊（細節本章不展開） |
| `components/RightSidebar.tsx` | 210 | 接 `updateRagSources` 事件顯示知識來源（細節本章不展開） |
| `package.json` | 53 | `dev`、`dev:left`、`dev:right`、`dev:chat` 等指令 |

## 四、關鍵程式片段

**片段 1：看回覆契約長什麼樣（`route.ts`）**

```ts
const responseSchema = z.object({
  response: z.string(),
  thinking: z.string(),
  user_mood: z.enum([
    "positive",
    "neutral",
    "negative",
    "curious",
    "frustrated",
    "confused",
  ]),
  suggested_questions: z.array(z.string()),
  debug: z.object({
    context_used: z.boolean(),
  }),
  matched_categories: z.array(z.string()).optional(),
  redirect_to_agent: z
    .object({
      should_redirect: z.boolean(),
      reason: z.string().optional(),
    })
    .optional(),
});
```

前五個欄位必填，後兩個可省略。`user_mood` 只能是六個值之一。`matched_categories` 只驗「字串陣列」，沒有驗內容是不是真的在分類表裡。模型回的 JSON 只要少一個必填欄位，`responseSchema.parse` 就丟例外，整個請求回 500。

**片段 2：看怎麼逼模型只回 JSON（`route.ts`）**

```ts
anthropicMessages.push({
  role: "assistant",
  content: "{",
});

const response = await client.messages.create({
  model: model,
  max_tokens: 1000,
  messages: anthropicMessages,
  system: systemPrompt,
});

const textContent = "{" + response.content
  .filter((block): block is Anthropic.TextBlock => block.type === "text")
  .map((block) => block.text)
  .join(" ");
```

做法是在訊息最後自己加一則 assistant 訊息，內容只有一個左大括號，讓模型接著寫下去；拿到回覆後再把左大括號補回前面。這裡沒有用工具或其他結構化輸出機制，純粹靠系統提示的格式說明、兩個範例與這個開頭字元。

**片段 3：看檢索回來的東西怎麼整理（`utils.ts`）**

```ts
const input: RetrieveCommandInput = {
  knowledgeBaseId: knowledgeBaseId,
  retrievalQuery: { text: query },
  retrievalConfiguration: {
    vectorSearchConfiguration: { numberOfResults: n },
  },
};
```

`n` 預設是 3，所以最多拿 3 段。後面把所有段落的文字用兩個換行接起來當 `context`（給模型看），但 `ragSources`（給右側欄看）在 `.map()` 之後接了 `.slice(0, 1)`，只留第一筆。也就是模型看到 3 段、使用者在畫面上只看到 1 個來源。

**片段 4：看檢索失敗時怎麼處理（`route.ts` 系統提示的一行）**

```ts
${isRagWorking ? `${retrievedContext}` : "No information found for this query."}
```

`retrieveContext()` 沒拿到 `knowledgeBaseId` 或呼叫出錯時回傳 `isRagWorking: false`，不丟例外。系統提示接著要求模型只用給你的資訊回答，並說沒有資訊或資訊不相關時「可以」轉給真人（原文是 `you can redirect the user to a human agent`，不是強制）。所以知識庫壞掉時，提示引導的方向是轉真人，而不是模型自己憑記憶回答；實際會不會每題都轉，原始碼看不出來。

## 五、用到的 Claude 功能

- Messages API（非串流）｜`app/api/chat/route.ts`｜`client.messages.create`，每個問題呼叫一次。
- 系統提示帶入檢索內容｜`app/api/chat/route.ts`｜把知識庫片段、分類清單、JSON 格式與兩個範例放進 `system`。
- 預填 assistant 開頭｜`app/api/chat/route.ts`｜訊息最後補一則 `"{"`，引導模型直接輸出 JSON。
- 結構化輸出的驗證（應用程式端）｜`app/api/chat/route.ts`｜用 zod 的 `responseSchema` 驗欄位，這是程式做的，不是 API 功能。
- 模型切換｜`components/ChatArea.tsx`｜`models` 陣列有 `claude-haiku-4-5-20251001` 與 `claude-sonnet-4-6`，預設前者，隨請求送到後端。
- 沒有用到：工具呼叫、串流、延伸思考。JSON 裡的 `thinking` 是模型照格式寫出來的一般文字欄位。

## 六、怎麼啟動（原始做法）

以下照 README 整理，本教材沒有執行。

1. `npm install`（README 註明需要 Node.js 20 以上，使用 `@anthropic-ai/sdk` v1.x）。
2. 在專案根目錄建 `.env.local`，放三個變數：`ANTHROPIC_API_KEY`、`BAWS_ACCESS_KEY_ID`、`BAWS_SECRET_ACCESS_KEY`。原始做法需要 `ANTHROPIC_API_KEY`（本教材演練不設定，改走 `claude -p`）。
3. 在 AWS 建好 Bedrock 知識庫，把知識庫 ID 填進 `ChatArea.tsx` 的 `knowledgeBases` 陣列。
4. `npm run dev`，瀏覽器開 `http://localhost:3000`。
5. 只想看部分版面時用 `npm run dev:left`、`npm run dev:right`、`npm run dev:chat`。

README 另有一節教用 AWS Amplify 部署，並說明 AWS 變數前面多一個 B 是因為 Amplify 不允許變數名稱以 AWS 開頭。

## 七、常見陷阱

1. **知識庫 ID 是佔位字串**：`ChatArea.tsx` 的 `knowledgeBases` 與 `selectedKnowledgeBase` 預設都是 `"your-knowledge-base-id"`。沒改就啟動，檢索會失敗，系統提示變成 `No information found for this query.`。
2. **區域寫死**：`utils.ts` 的 `BedrockAgentRuntimeClient` 寫死 `region: "us-east-1"`，旁邊的註解提醒要和知識庫所在區域一致。
3. **提示範例的分類代號和分類表對不上**：系統提示的兩個範例用了 `account_management`、`technical_support`，但 `customer_support_categories.json` 的 `id` 是 `account`、`billing`、`feature`、`internal`、`legal`、`other`、`technical`、`usage`。程式沒有檢查模型回的代號是否在表內。
4. **分類表的 `keywords` 沒有送給模型**：`route.ts` 只把各分類的 `id` 用逗號接起來放進提示，`name` 與 `keywords` 在這支路由沒有用到。
5. **錯誤回覆少欄位**：例外時回傳的物件沒有 `suggested_questions`，狀態碼是 500；前端看到非 2xx 直接丟錯，只寫 console，畫面上的佔位訊息不會被換掉。
6. **讀了後端沒送的標頭**：`ChatArea.tsx` 會讀 `x-suggested-questions` 標頭，但 `route.ts` 只設定 `x-rag-sources` 與 `X-Debug-Data`。另外 README 的 Amplify 設定與 `amplify.yml` 都寫了 `KNOWLEDGE_BASE_ID`，程式裡知識庫 ID 其實來自請求本文；搜尋整個專案，這個變數只出現在這兩處，沒有任何程式讀取它。

## 八、重點回顧

- 流程是「先檢索、再生成」：一次 Bedrock 檢索加一次 Claude 呼叫，沒有工具迴圈。
- 一個 JSON 回覆同時帶回答、情緒、分類、建議追問、是否轉真人，前端各區塊各取所需。
- 強制 JSON 的手法是系統提示寫格式與範例，加上預填 assistant 的 `"{"`，再由 zod 驗證。
- 檢索失敗不會讓請求失敗，而是由提示引導模型轉給真人（提示用的是「可以」，不是強制）。
- 模型看到最多 3 段內容，畫面只顯示 1 個來源，這是 `.slice(0, 1)` 造成的。
- 提示範例與分類表不一致這類小落差，要靠程式端驗證才抓得到。
