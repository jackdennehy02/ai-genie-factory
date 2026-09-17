AI CHATBOT

All applications with an LLM-powered chat interface must follow these guardrails.
Code patterns and implementation details are in @ai-chatbot skill.

Process (read this first):
- Before writing any LLM integration code, trace the full message flow on paper: system prompt → user message → LLM response format → what happens with the response → what the user sees. Every message must be consistent with the system prompt's output format.
- Never patch a symptom. If something doesn't work, read the FULL file, understand the complete state, then make ONE considered change. A deploy-and-check-logs loop wastes hours.
- Before deploying, test the exact payload the app will send — from the app's service principal context, not the user's context. Test the full response shape, not just the status code.
- When changing any shared data structure (COLORS dict keys, chat-store schema, message format), audit ALL references across ALL files first.

Architecture:
- ONE system prompt that is both analyst AND query generator — never split into a "JSON classifier" and a separate "analyst". A split architecture produces disconnected conversations, conflicting instructions, and the LLM cannot reason about data it just queried.
- ONE continuous conversation — the LLM keeps full history (messages + data results). Follow-ups work naturally because the LLM has context of everything shown.
- When SQL is executed, feed the results BACK into the same conversation and ask the LLM to analyse them. This is still within one logical flow, not a disconnected second call with a different system prompt.
- The system prompt defines the LLM's ROLE (analyst who scrutinises data) with formatting as a lightweight suffix — never the other way around.

Model:
- Preferred: databricks-claude-sonnet-5 (or highest available non-deprecated Claude Sonnet).
- Never default to Llama or Haiku for chat — they lack the analytical depth users expect.
- Claude models do NOT support `temperature` — omit it entirely (causes invisible 400).
- Use only `messages` and `max_tokens` unless the model's docs confirm other params.
- Test endpoints before committing — status code AND response shape.

Claude specifics:
- Claude Sonnet 5+, Opus 4+ return `content` as a list of typed blocks, not a string. Always extract text blocks: `[b["text"] for b in content if b.get("type") == "text"]`.
- Extended thinking returns ONLY reasoning blocks (zero text) when it encounters contradictory instructions. The #1 cause: system prompt says "Return strict JSON" but a later message says "Do not return JSON." NEVER contradict the system prompt's output format. If the system prompt requires JSON, ALL messages must request JSON (e.g. 'Respond as: {"type": "conversation", "response": "<analysis>"}').
- Handle empty extraction explicitly — never let an empty string become the response.

Conversation history:
- Every LLM call must receive full conversation history. A chatbot without memory is not a chatbot.
- Assistant messages in history must include actual SQL results (first 20 rows as text), not just "[returned N rows]". Without data context, the LLM cannot answer follow-ups.
- When feeding SQL results back for analysis, send ALL rows up to 100 — never artificially truncate small result sets (e.g. head(30) of 34 rows). The LLM will report "results were truncated" instead of analysing the data.

SQL guardrails:
- Generated SQL must pass through enforce_select_only (SELECT/WITH only, single statement, table validation, auto-LIMIT).
- All string interpolation into SQL must use sql_literal() escaping — never raw f-strings.
- Never allow the chat LLM to generate UPDATE/INSERT — only dedicated writeback functions.
- Writeback must be separated from the chat flow with its own guardrails.

Analysis quality:
- The system prompt should make the LLM capable of spotting anomalies — but the analysis prompt must be contextual. For straightforward questions ("longest routes", "how many delayed"), just answer the question concisely. For analytical questions ("anything unusual?", "what patterns?"), do deep scrutiny. Never force anomaly detection on every response — it makes simple answers bloated and unnatural.
- Analysis prompts must prioritise answering the user's question. Lead with "answer my original question directly" not "examine every value". Anomaly flagging is "only if something genuinely stands out; don't force it."
- Use markdown with **bold headers**, bullet points, and **Recommended Actions**. Keep formatting instructions lightweight — one sentence, not six.

UI:
- Chat thread container: max-width 800px, centered. Full-width is unreadable.
- Chat bubble markdown: line-height 1.7+, letter-spacing 0.01em.
- Chat markdown CSS: `.chat-markdown strong` in accent colour, paragraph/list spacing.
- Map dcc.Graph: initial empty dark figure + dcc.Loading wrapper (prevents white axes flash).

Platform:
- LLM responses must never surface raw tracebacks — catch at boundary, log, show friendly error.
- LLM call timeouts must be explicit (90s recommended).
- Statement Execution API `wait_timeout`: 5s–50s (or 0). Above 50s → immediate 400.
- Foundation Model endpoint testing must verify full response shape, not just status code.

Forbidden:
- Separate "JSON classifier" and "analyst" system prompts in the same chat pipeline.
- Contradicting the system prompt's output format in any message ("Do not return JSON" when system says "Return strict JSON").
- Single-turn LLM calls without conversation history.
- Returning bare SQL results without analysis.
- Artificially truncating result previews (e.g. head(30) of 34 rows) — the LLM reports "results were truncated" instead of analysing.
- Forcing anomaly detection on every response regardless of the question.
- `temperature` parameter for Claude models.
- `.strip()` on LLM content without checking if it's a list first.
- `from databricks.sdk import Config` — use `WorkspaceClient().config` instead.
- `wait_timeout` above 50s.
- Analysis prompts that are 90% formatting instructions.
- Map dcc.Graph without an initial empty dark figure.
- Deploy-and-check-logs patching loops — think through the full flow first.
- Renaming COLORS dict keys or chat-store fields without auditing all references.
