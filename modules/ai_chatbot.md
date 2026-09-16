AI CHATBOT

All applications with an LLM-powered chat interface must follow these guardrails.
Code patterns and implementation details are in @ai-chatbot skill.

Rules:
- Every LLM system prompt must include: "Never use emojis, emoji characters, or unicode symbols. Use plain text only."
- Every text-to-SQL flow must route intent first — classify as conversation vs data question before generating SQL
- Generated SQL must pass through enforce_select_only before execution (SELECT/WITH only, single statement, table validation, auto-LIMIT)
- All string interpolation into SQL must use sql_literal() escaping — never raw f-strings with user input
- LLM responses must never surface raw tracebacks — catch at the call boundary, log, show user-friendly error
- Foundation Model endpoints must be tested before hardcoding — deprecated endpoints fail silently with 400
- LLM call timeouts must be explicit (90s recommended)
- Writeback (UPDATE/INSERT) must be separated from the chat LLM flow with its own guardrails
- Never allow the chat LLM to generate UPDATE/INSERT — only dedicated writeback functions
