APP NAME: [Descriptive name]

Objective:
[One paragraph. What does it do, who uses it, what decisions does it enable?]

Data:
- [catalog.schema.table]

Schema notes:
[Non-obvious columns only. Format: column_name (type): description or enum values.]
[Write "None" if the schema is self-explanatory.]

KPIs:
- [Metric name: calculation, or "semantic layer: [metric_name]"]

Transformations:
- [Base filter, group by, aggregation descriptions]
[Write "None" if KPIs above are the only transformations.]

UI Components:
[Visual components in render order:]
- [Component: description]
[Genie Code picks chart types when not specified.]

Filters:
- [Filter: type + default, e.g., "Region dropdown, default: All"]
[Write "None" if no filters.]

Genie Agent:
- Space ID: [Genie Space ID, or "create new" if none exists]
- Name: [Agent name, e.g., "Sales Analytics"]
- Tables: [same as Data section above — the agent wraps these tables]
[Write "None" if the app has no chat tab.]

Design:
- Mode: [snap-dark or snap-light]
- [Any status colours or overrides to THEMING tokens]
- [Layout notes, e.g., "Tabs: Dashboard and Chat"]
[All other styling comes from THEMING in the repo.]

Deployment:
- App name: [kebab-case name for databricks apps create]
- Warehouse: [warehouse name or ID, default: snap-dbx-sandbox-sql-wh]
[Write "defaults" to use DEFAULT INFRASTRUCTURE from PROMPT_TEMPLATE.]

Constraints:
- [App-specific overrides only]
[Write "None beyond GLOBAL_RULES" if nothing special.
Error handling, chatbot, and deployment rules are enforced by
GLOBAL_RULES, STACK, and the relevant skills (@databricks-app, @ai-chatbot, etc.)]
