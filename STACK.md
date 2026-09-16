STACK

Runtime:
- Databricks (unified platform for all workloads)
- Databricks Apps for web application deployment
- Delta Live Tables (DLT) for pipeline workloads

Language:
- Python

App Frameworks:
- Dash (dash + dash-bootstrap-components) for interactive web apps
- Plotly (plotly.express, plotly.graph_objects) for all charts and visualizations
- sqlparse for SQL formatting in chat interfaces

Data Access:
- Notebooks and DLT: spark.table() for all reads
- Databricks Apps: databricks-sdk WorkspaceClient + Statement Execution API (no Spark session in Apps runtime)
- Databricks Apps (alternative): databricks-sql-connector for direct SQL warehouse access via databricks.sql.connect()
- Unity Catalog three-part table names: catalog.schema.table in both runtimes
- Gold layer tables only in UI-facing apps
- Delta Lake as the table format

LLM Integration:
- Foundation Model API via requests.post to /serving-endpoints/{endpoint}/invocations
- Auth: databricks-sdk Config().authenticate() for headers (OAuth in Apps runtime)
- Endpoint naming: use environment variables, never hardcode — endpoints deprecate without warning
- SQL generation: always route intent first (conversation vs data), enforce SELECT-only guardrails

Data Architecture:
- Medallion: Bronze (raw ingestion) → Silver (validated, SCD Type 2) → Gold (aggregated, app-ready)
- Gold tables are materialized views or Photon-optimized Delta tables with star schema
- Semantic layer via dbxs metrics registered in Unity Catalog metrics store

Governance:
- Unity Catalog for lineage, access control, and discoverability
- RBAC with attribute-based policies
- Column-level lineage and impact analysis via Unity Catalog

Libraries:
- ai-dev-kit: https://github.com/databricks/ai-dev-kit
- databricks-sdk, databricks-sql-connector, dash, dash-bootstrap-components, plotly, pandas, requests, sqlparse
