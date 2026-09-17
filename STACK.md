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
- Genie Conversation API (databricks-sdk) for chat interfaces

Data Access:
- Notebooks and DLT: spark.table() for all reads
- Databricks Apps: databricks-sdk WorkspaceClient + Statement Execution API (no Spark session in Apps runtime)
- Databricks Apps (alternative): databricks-sql-connector for direct SQL warehouse access via databricks.sql.connect()
- Unity Catalog three-part table names: catalog.schema.table in both runtimes
- Gold layer tables only in UI-facing apps
- Delta Lake as the table format

Chat / Conversational Analytics:
- Genie Agent wrapper via databricks-sdk Conversation API (standard approach)
- `w.genie.start_conversation_and_wait()` and `w.genie.create_message_and_wait()` for all chat
- Genie Space ID in app.yaml env vars, no serving-endpoint resource needed
- App service principal needs CAN_RUN on the Genie Space (grant via application_id UUID)

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
- databricks-sdk, databricks-sql-connector, dash, dash-bootstrap-components, plotly, pandas, requests
