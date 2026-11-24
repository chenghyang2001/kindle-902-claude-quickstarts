# CLAUDE.md

K902「Claude Quickstarts 導讀與互動演練」教材 repo（見 README.md）。教材來源是官方 `anthropics/claude-quickstarts`，不是書。

- 這是學習用教材（kindle-drill 快速模式），不是正式專案。
- `lessons/chNN-<專案名>.md` 是講義，`prompts/chNN.md` 是演練重點；撰寫規格在 `doc/authoring-spec.md`，改任何一份前先讀它。
- 內容必須以 `~/workspace/claude-quickstarts`（commit 4a4224b）的實際程式碼為依據；看不出來就寫「看不出來」。
- 官方原始碼只讀：不修改、不整包複製進本 repo、不安裝它的依賴、不執行它的啟動指令。查看用 `practice/qs_source.py`。
- 呼叫模型一律走 `practice/llm_agent.py` 或 `practice/claude_cli_client.py`（`claude -p`，訂閱額度）；不可設定任何 API 金鑰，不 mock 模型；每個練習最多呼叫 2 次、整章最多 4 次（第 10 章練習 2 例外，呼叫 3 次）。
- `practice/chNN/interactive/` 是演練執行時的輸出，不進版控。
- 路徑一律寫 `~` 或 `Path.home()`，不寫死使用者資料夾；不寫個人資料。

## 架構

```text
lessons/    10 章講義
prompts/    10 章演練重點（演練備課工廠的輸入）
practice/   llm_agent.py、claude_cli_client.py、qs_source.py、README.md（演練類型分類表）
doc/        authoring-spec.md（撰寫規格）
```

## 本專案例外

本專案是學習用教材（kindle-drill 快速模式），豁免全域「程式碼三 agent 鐵律」：直接寫檔，不派 code-writer／code-qa／code-reviewer；不需詢問複雜度，也不需詢問是否使用快速模式。
`practice/` 底下三支共用工具改動後，要重跑各自的 `--selftest`，`claude_cli_client.py` 另跑一次 `--live`。
