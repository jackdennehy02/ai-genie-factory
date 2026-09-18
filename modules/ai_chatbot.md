AI CHATBOT

All applications with a chat interface must use a **Genie Agent wrapper** — not a custom LLM pipeline.
Code patterns and implementation details are in @ai-chatbot skill.

Architecture:
- Wrap a Databricks Genie Agent via the Python SDK Conversation API (`start_conversation_and_wait`, `create_message_and_wait`)
- The Genie Agent handles SQL generation, query execution, analysis, and conversation context
- The app only renders the results in chat bubbles
- No system prompts, no text-to-SQL, no intent routing, no Foundation Model API calls

Prerequisites:
- A Genie Agent (Genie Space) must exist over the app's data tables. If one does not exist, create it — see @databricks-genie-agents skill.
- The app's service principal must have `CAN_RUN` on the Genie Space — **grant this automatically as part of the deploy flow**, never as a manual post-deploy step. Use the Permissions API with the SP's `application_id` UUID, not its display name.
- The factory pattern for chat-enabled apps is a companion notebook `deploy_app.ipynb` that runs under the user's identity and performs create app → attach resources → grant Genie permissions → deploy.
- The Genie Space ID goes in `app.yaml` as an env var (`GENIE_SPACE_ID`)
- No `serving-endpoint` resource needed — the Genie Agent uses its own warehouse

Data layer (data.py):
- `genie_start_conversation(space_id, question)` — starts a new conversation, returns `{conversation_id, text, sql, description}`
- `genie_follow_up(space_id, conversation_id, question)` — sends follow-up in existing conversation
- `_parse_genie_message(msg)` — extracts text/sql/description from GenieMessage attachments
- All wrapped in `try/except` raising `DataAccessError`

UI layer (ui.py):
- `chat_bubble(role, text, sql, mode)` — SMS-style bubbles, user right-aligned, Genie left-aligned
- `render_chat_history(messages, mode)` — converts message list to bubble components
- Use `dcc.Markdown` for Genie content, fenced SQL code blocks below analysis

App layer (app.py):
- Two-phase Dash callbacks for instant feedback while Genie processes
- Phase 1: append user bubble, show "Thinking...", clear input, set `pending-q` store
- Phase 2: triggered by `pending-q`, calls Genie API, renders response, clears `pending-q`
- `genie-conv-id` store tracks conversation continuity (first message → start_conversation, follow-ups → create_message)
- `chat-history` store holds flat list of `{role, text, sql}` dicts

UI rules:
- Chat thread container: max-width 800px, centered
- Chat thread height: calc(100vh - 320px)
- Typing indicator: simple "Thinking..." text (no fake multi-step progress)

Forbidden:
- Custom LLM chat pipelines (system prompts, text-to-SQL, intent routing, Foundation Model API)
- `serving-endpoint` resource in app.yaml for chat
- iframe or link cards to the Genie Space (must wrap via SDK)
- `chat-history` as `Input` (not `State`) on tab-rendering callbacks
- Deploy-and-check-logs patching loops — think through the full flow first
- Renaming store IDs or message format without auditing all references
- Attempting Genie Space permission grants from chat tools (executeCode, runDatabricksCli) — safety guardrails always block it
- Shipping a standalone `setup_permissions.py` instead of putting the grant in the deploy notebook
- Deploying a chat-enabled app without a `deploy_<app_name>.py` notebook that includes the Genie CAN_RUN grant
- Leaving Genie Space CAN_RUN as a manual post-deploy step for the user
