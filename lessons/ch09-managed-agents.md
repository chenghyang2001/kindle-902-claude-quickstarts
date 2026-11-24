# 第 9 章　managed-agents：把代理交給 Anthropic 代管的 12 個範例

> 來源：`~/workspace/claude-quickstarts/managed-agents`（官方 repo `anthropics/claude-quickstarts`，commit 4a4224b，MIT 授權）
> 演練類型：導讀＋小模擬

## 一、這個專案做什麼

`managed-agents` 不是單一專案，而是 12 個建在 Claude Managed Agents 上的子專案。總 README 對這個服務的定義是：由 Anthropic 替你執行的代理，提供伺服器端的 session、沙箱裡的工具，以及一條讓你的應用程式消費的事件串流。和前幾章最大的差別是「代理迴圈不在你的程式裡」：你的程式只負責建立資源、送訊息、讀事件、回答自訂工具。

共通的積木有六種：agent（模型、系統提示、工具）、environment（沙箱與網路白名單）、session（一次執行與它的事件紀錄）、vault（由 Anthropic 保管、在出口才注入的憑證）、memory store（跨 session 的檔案式記憶）、deployment（排程）。多數子專案把這些寫成檔案，用 `ant apply` 建立並把 ID 記在 `claude-lock.json`。

12 個子專案總表（模型名稱取自各子專案的設定檔）：

| 子專案 | 做什麼 | 代理類型 | 觸發方式 | 狀態存在哪裡 |
| --- | --- | --- | --- | --- |
| `assistant-ui` | 試算表分析師聊天，`bash` 每個指令都要按核准 | 單代理（`claude-opus-5`） | 瀏覽器聊天 | session 事件紀錄（重播還原對話） |
| `chat-sdk` | 研究分析師聊天（Vercel Chat SDK） | 單代理（預設 `claude-opus-4-8`） | 瀏覽器聊天 | session（對話 ID 就是 session ID） |
| `copilot-kit-ag-ui` | 個人理財助理，自訂工具畫互動圖表 | 單代理（`claude-fable-5`） | 瀏覽器聊天 | 每個聊天串對應一個 session |
| `daily-brief` | 每個工作日讀 Slack 與 GitHub PR，貼一則簡報 | 單代理（`claude-sonnet-5-5`） | cron 排程 | 兩個 memory store |
| `knowledge-wiki` | 把文件庫一次蒸餾成知識 wiki，之後從 wiki 回答 | 多代理（lead 加四種工作代理） | 手動跑 notebook | memory store（wiki 本身） |
| `linear` | Linear 上被 @ 或指派時回留言 | 單代理（`claude-opus-5`） | webhook | session `metadata` |
| `mcp-server-typescript` | 把 Sessions API 包成 9 個 MCP 工具 | 非代理（自己不建代理） | MCP 用戶端呼叫 | 無 |
| `roadtrip-planner` | 國家公園公路旅行規劃 | 多代理（coordinator `claude-sonnet-5`＋reviewer `claude-opus-5`） | 瀏覽器聊天 | session（README 寫沒有資料庫） |
| `self-hosted-sandboxes` | 在自己的硬體上跑 session 的沙箱（多個供應商版本） | 示範用單代理；`openshell-policy` 另有 `hello` 與 `reviewer` 兩份定義，兩者關係未細讀 | 工作佇列輪詢或 webhook | `docker-memory` 會掛載並回寫 memory store |
| `sentry` | 排程的 Sentry 問題分流報告 | 單代理（`claude-opus-5`） | cron 排程 | 看不出來（只讀了 README 摘要與排程設定） |
| `sentry-autofix` | Sentry 新錯誤→寫失敗測試→修→推分支，由主機開 PR | 單代理（`claude-opus-5`），每個 issue 一個 session | 簽章 webhook 或 `npm run fix` | session `metadata` 與事件紀錄 |
| `slack` | Slack 上被 @ 時回討論串 | 單代理（`claude-opus-5`） | webhook | session `metadata` |

本章深入三個和長時間運行最相關的：`daily-brief`、`sentry-autofix`、`knowledge-wiki`。

## 二、架構與資料流

以 `daily-brief` 為例（沒有任何常駐主機程式）：

```text
┌────────────────────┐   cron "32 7 * * 1-5"
│ deployment.md      │──────────────┐
│ 排程、預算、vault  │              ▼
└────────────────────┘      ┌───────────────┐
                            │ 全新 session   │  系統提示 = agent.md 的本文（8 個步驟）
                            └──────┬────────┘
       ┌───────────────────────────┼────────────────────────────┐
       ▼                           ▼                            ▼
┌──────────────────┐   ┌────────────────────────┐   ┌──────────────────────┐
│ /mnt/memory/     │   │ /mnt/memory/state      │   │ 沙箱（只能連         │
│ preferences      │   │ bookmarks.json         │   │ slack.com 與 MCP）   │
│ （唯讀）         │   │ ledger.md  notes.md    │   │ curl → Slack         │
│ preferences.md   │   │ runs/<date>.md（讀寫） │   │ MCP  → GitHub（唯讀）│
└──────────────────┘   └────────────────────────┘   └──────────┬───────────┘
                                   ▲                           │
                                   │ ⑧ 貼文確認成功後才記帳   ▼
                                   └────────────── ⑦ chat.postMessage
```

`sentry-autofix` 則多一個主機程式：Sentry webhook → `src/app.ts` 驗簽 → `src/fixer.ts` 建立 session → 代理在沙箱裡重現並修好、推分支 → 呼叫自訂工具 `open_pull_request` → 主機用自己的 GitHub token 開 PR。

## 三、關鍵檔案

| 檔案 | 行數大約 | 負責什麼 |
| --- | --- | --- |
| `README.md` | 115 | 12 個子專案的總覽 |
| `daily-brief/agents/daily-brief/agent.md` | 60 | 模型與工具（frontmatter）＋ 8 個執行步驟（本文即系統提示） |
| `daily-brief/agents/daily-brief/deployment.md` | 30 | cron、時區、vault、兩個 memory store 的權限、每次執行預算 |
| `daily-brief/agents/daily-brief/environment.yaml` | 15 | 沙箱網路白名單 |
| `daily-brief/agents/setup.sh` | 80 | `ant apply`、把憑證加進 vault、暫停排程 |
| `sentry-autofix/src/fixer.ts` | 460 | 每個 issue 一個 session、事件迴圈 `drive()`、`open_pull_request` 處理 |
| `sentry-autofix/src/app.ts` | 50 | webhook 路由：驗簽、過濾、回 202 |
| `sentry-autofix/agents/issue-fixer/agent.yaml` | 110 | 修錯代理的系統提示、MCP 工具白名單、自訂工具 |
| `knowledge-wiki/prompts/lead_system.md` | 10 | lead 代理的規則與最後要回的 JSON 報告 |
| `knowledge-wiki/utilities.py` | 2,980 | notebook 用的函式：上傳、追蹤工作流、檢查、計價 |
| `knowledge-wiki/distill_documents_into_knowledge_wiki.ipynb` | 3,260 | 整個流程的 notebook（附錄製那次執行的輸出） |

## 四、關鍵程式片段

看什麼：`daily-brief` 的跨次記憶與花費上限是怎麼宣告的（`deployment.md` 的 frontmatter）。

```yaml
schedule:
  type: cron
  expression: "32 7 * * 1-5" # weekdays at 07:32
  timezone: America/New_York
resources:
  - path: ./memory_store_preferences.yaml
    access: read_only
  - path: ./memory_store_state.yaml
    access: read_write
budget:
  type: limit
  max_list_cost:
    amount: "500" # a string, in cents: "500" is $5.00 per run
```

每次排程都是全新的 session，連續性完全來自 `state` 這個 memory store。`preferences` 在檔案系統層級就是唯讀，代理改不了使用者的規則。把 `state` 改成 `read_only` 就變成演習：不貼文、不移動書籤。

看什麼：`agent.md` 的步驟怎麼寫出「沒人看著也要安全地失敗」（節錄步驟 3 與 8）。

```text
3. Read each source from ten minutes before its bookmark, and skip anything
   whose ID is already in the ledger with an unchanged state. ... never treat
   a source you could not read as a source with nothing in it.
8. Bookkeeping, only after the post is confirmed ... A bookmark never moves
   for a source that failed, and never if the post failed.
```

書籤取代「最近 24 小時」，晚跑或漏跑都不會掉資料；往前多讀十分鐘造成的重疊由帳本 `ledger.md` 擋掉；讀不到的來源要寫成「讀不到」而不是「沒事」；先確認 Slack 回 `"ok": true` 才記帳。

看什麼：`sentry-autofix` 主機重啟後怎麼接續（`src/fixer.ts` 的 `drive()`）。

```typescript
const stream = await client.beta.sessions.events.stream(run.sessionId);
const history = [];
for await (const event of client.beta.sessions.events.list(run.sessionId, { order: "asc" })) history.push(event);
for (const event of history) {
  if (event.type !== "user.custom_tool_result") continue;
  answered.add(event.custom_tool_use_id);
  ...
}
```

主機不存任何東西。每次連線都做同一件事：先開串流、把整份事件紀錄重播一遍、再接著讀串流。從歷史裡找出已經回答過的自訂工具呼叫放進 `answered`，就不會回答第二次。第一次連線、斷線重連、主機重啟是同一條程式路徑；找既有 session 則靠 `metadata.sentry_short_id`。

看什麼：同一個檔案裡的花費上限。

```typescript
budget: { type: "limit", max_list_cost: { amount: String(config.maxCents), currency: "USD" } },
```

`AUTOFIX_MAX_USD` 預設 10 美元，換成整數的「分」再轉字串。另有 `AUTOFIX_MAX_ACTIVE`（預設 3）限制同時進行的修復數，避免一波 webhook 變成一波花費。

## 五、用到的 Claude 功能

- Managed Agents session 與事件串流｜`sentry-autofix/src/fixer.ts`｜`sessions.create`、`events.stream`、`events.list`、`events.send`。
- 排程 deployment｜`daily-brief/agents/daily-brief/deployment.md`、`sentry/deploy.py`｜cron 加時區，每次開新 session。
- Memory store｜`daily-brief` 的兩個 `memory_store_*.yaml`、`knowledge-wiki`｜掛在 `/mnt/memory/`，可設唯讀或讀寫，有版本紀錄。
- Vault 憑證｜`daily-brief/agents/setup.sh`、`sentry-autofix/src/sentry-login.ts`｜`environment_variable`、`static_bearer`、`mcp_oauth` 三種；沙箱只看到佔位字串。
- 每個 session 或每次執行的預算｜`deployment.md`、`fixer.ts`｜到上限會暫停而不是失敗。
- 權限政策｜各 `agent.md`／`agent.yaml`｜`always_allow` 與 `always_ask`；無人值守的代理必須是前者。
- 自訂工具由主機回答｜`sentry-autofix` 的 `open_pull_request`｜`agent.custom_tool_use` 與 `user.custom_tool_result`。
- 多代理｜`roadtrip-planner/agents/roadtrip-planner.md` 的 `multiagent: type: coordinator`、`knowledge-wiki` 的 dynamic workflow｜協調者把工作交給名單上的代理。
- MCP 伺服器｜GitHub、Sentry｜憑證以 URL 比對。

## 六、怎麼啟動（原始做法）

以下照各子專案 README 抄錄，本教材都沒有執行（需要 Managed Agents 雲端服務、`ant` CLI 與第三方帳號）。原始做法需要 `ANTHROPIC_API_KEY` 或 `ant auth login`（本教材演練不設定，改走 `claude -p`）。

```bash
# daily-brief
cp .env.example .env
agents/setup.sh
scripts/seed-preferences.sh preferences.md
scripts/run.sh

# sentry-autofix
./agents/setup.sh
npm run fix -- SHOP-1A
npm run dev

# knowledge-wiki
python3 fetch_data_room.py --tier=core
jupyter lab distill_documents_into_knowledge_wiki.ipynb
```

## 七、常見陷阱

1. 預算金額是「以分為單位的字串」：`"500"` 才是 5 美元。`daily-brief/CLAUDE.md` 列了寫錯時的錯誤訊息；到上限是暫停，從頻道看起來只是沒有簡報。
2. `web_search` 與 `web_fetch` 在 Anthropic 的伺服器上執行，不受 `environment.yaml` 的白名單限制，所以兩個無人值守的代理都把它們關掉，否則被注入的文字就有對外的出口。
3. MCP 工具組預設是 `always_ask`；無人值守時 session 會永遠停在等核准。`sentry-autofix` README 提醒，代理更新後要回 Console 確認權限沒有跑掉。
4. `sentry-autofix` 啟動時會檢查基底分支有沒有啟用中的 ruleset，沒有就直接結束；傳統的分支保護規則不算數，因為預設不擋管理員。
5. Slack 不論成功與否都回 HTTP 200，要看回應本文的 `"ok": true`；`agent.md` 把這條寫進步驟。
6. `knowledge-wiki` 的代理直接寫共用頁面，README 承認最忙的實體頁約有 5% 的行會互相覆蓋；單一檔案上限 100 KB。另外各子專案要求的 `ant` 版本不一致（`daily-brief` 寫 2.0 以上，`sentry-autofix` 寫 1.34 以上）。

## 八、重點回顧

- Managed Agents 把代理迴圈搬到伺服器端，你的程式變成「建立資源、送事件、讀事件」。
- 跨次執行的連續性有兩種來源：memory store（`daily-brief`、`knowledge-wiki`）與 session 自己的 `metadata` 加事件紀錄（`sentry-autofix`、`slack`、`linear`）。
- `daily-brief` 的重點是失敗時的行為：每個來源一個書籤、帳本防重複、讀不到要明說、確認貼文成功後才記帳。
- `sentry-autofix` 的主機不存狀態，靠重播事件紀錄接續；關鍵決定（哪個 repo、哪個分支、關聯哪個 issue）留在主機，不交給代理。
- `knowledge-wiki` 用一次 dynamic workflow 讓 lead 代理指揮 extractor、resolver、analyzer、organizer；README 記錄的那次執行花了 23 分鐘、約 16 美元。
- 無人值守的代理，安全靠外圍：網路白名單、沙箱拿不到的憑證、唯讀 token、花費上限，以及最後由人審的 PR。
