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

Design:
- Mode: [snap-dark or snap-light]
- [Any status colours or overrides to THEMING tokens]
- [Layout notes, e.g., "Tabs: Operations and Chat"]
[All other styling comes from THEMING in the repo.]

Constraints:
- [App-specific overrides only, e.g., "Serving endpoint via env var SERVING_ENDPOINT_NAME"]
[Write "None beyond GLOBAL_RULES" if nothing special.
Auth, SQL guardrails, error handling, logging, and chatbot rules are enforced by
GLOBAL_RULES, STACK, and the relevant skills (@databricks-app, @ai-chatbot, etc.)]
