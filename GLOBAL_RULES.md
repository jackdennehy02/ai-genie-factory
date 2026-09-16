GLOBAL RULES

All applications must:

- Run on Databricks (Databricks Apps for web apps, Notebooks for exploratory, DLT for pipelines)
- Read only from Gold layer Unity Catalog tables in UI-facing apps
- Reference all tables using three-part naming: catalog.schema.table
- Separate data, logic, and UI into distinct layers — no layer may contain logic from another
- Use ai-dev-kit patterns and components (https://github.com/databricks/ai-dev-kit)
- Data access by runtime: Notebooks and DLT use spark.table(); Databricks Apps use databricks-sdk WorkspaceClient + Statement Execution API (no Spark session available in Apps runtime)
- Apply central KPI definitions from the semantic layer — never recalculate a KPI that exists in the platform
- Respect Unity Catalog RBAC/ACLs — never bypass access controls or use service principals to elevate permissions
- Use centralised Snap Analytics brand tokens from THEMING module — never define per-app colour palettes
- Include the brand logo from brand/ in every app header (copy to app /assets/ folder)

Architecture layers:

- Data layer: Unity Catalog three-part names, no transformation logic — spark.table() in Notebooks/DLT; WorkspaceClient Statement Execution API in Databricks Apps
- Logic layer: aggregations, transformations, business rules — no SQL, no UI dependencies
- UI layer: Plotly charts using approved patterns, pandas conversion happens here only, brand tokens from THEMING only

Forbidden:

- Business logic in UI layer
- SQL outside the data access module
- Hardcoded values (catalog names, table names, thresholds, colour hex codes)
- Reading from Bronze or Silver tables in UI-facing apps
- Redefining KPIs that exist in the semantic layer
- Creating custom components that duplicate ai-dev-kit patterns
- Bypassing Unity Catalog governance
- Per-app colour definitions — use centralised THEMING tokens only
- Apps without the Snap Analytics logo in the header
