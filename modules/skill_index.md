SKILL INDEX

Genie Code Agent Mode auto-loads a skill when a request matches its description below —
@mention is only needed to force-load a skill when the wording is ambiguous. This index
exists so routing to the right skill stays reliable even without an explicit @mention.

- @data-access — reading Unity Catalog tables, data.py, query failures, DataAccessError
- @ui-ux-patterns — Databricks App UI (ui.py/app.py), Plotly charts, colors, KPI cards
- @databricks-app — app.py/app.yaml, service principal, App architecture, debugging an App
- @databricks-dashboard — building or editing a native AI/BI Lakeview Dashboard
- @databricks-dashboard-colors — dashboard theme, dark/light mode, Lakeview color palette
- @dlt-pipeline — Bronze/Silver/Gold, DLT, Auto Loader, CDC, streaming pipelines
- @testing-scaffold — writing or reviewing tests for an App
- @ai-chatbot — LLM chat interface, text-to-SQL, intent routing, Foundation Model API, SQL guardrails, maps with route lines, writeback with auto-refresh, chat UX patterns

Dashboards always need both @databricks-dashboard and @databricks-dashboard-colors together —
one without the other produces a Lakeview dashboard with an unstyled or inconsistent theme.

Chatbot apps always need @ai-chatbot paired with @databricks-app and @data-access —
the chatbot skill handles LLM integration and chat UX; the app skill handles architecture;
the data-access skill handles Unity Catalog reads.
