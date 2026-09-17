---
name: databricks-app
description: >
  Architecture and deployment rules for Alpura Databricks Apps built with Dash or Streamlit.
  Load for app.py, app.yaml, requirements, service-principal permissions, startup, deployment,
  debugging, and data/logic/UI boundaries. Always pair with data-access and ui-ux-patterns.
---

# Databricks App Architecture — Alpura

Apply to every Databricks App. The workspace instructions are authoritative if another
example conflicts with this skill.

## Required architecture

```text
my-app/
├── app.py              # orchestration, configuration, layout wiring, callbacks
├── data.py             # WorkspaceClient Statement Execution reads only
├── logic.py            # pandas transformations and business rules only
├── ui.py               # Plotly figures and Dash/Streamlit components only
├── _logger.py          # shared structured logger
├── app.yaml            # command and resource-backed environment variables
├── requirements.txt
└── APP.md              # purpose, audience, Gold tables, filters, KPIs, acceptance criteria
```

## Rules

- No Spark session exists in Databricks Apps.
- `data.py` uses `WorkspaceClient().statement_execution` and follows `@data-access`.
- `logic.py` has no SQL and no UI imports.
- `ui.py` has no SQL, remote access, KPI definitions, or aggregations.
- `app.py` owns validated configuration and orchestration; it contains no SQL.
- UI-facing reads are Gold-only and use three-part Unity Catalog names.
- Reuse centrally defined semantic KPIs; never recalculate them in an app.
- Import `get_logger` from `_logger.py` in every Python module; never use `print()`.
- Catch and translate exceptions at every layer boundary. Never show raw tracebacks.
- Every visual UI supports `alpura-dark` and `alpura-light` from `@ui-ux-patterns`.

## Configuration pattern

All values vary by environment and must come from app resources or environment variables.
Validate them during startup without opening a remote connection.

```python
"""Application entry point and orchestration."""
import os

from _logger import get_logger

logger = get_logger(__name__)

CONFIG = {
    "table_name": os.environ["UC_TABLE_NAME"],
    "warehouse_id": os.environ["DATABRICKS_WAREHOUSE_ID"],
    "row_limit": int(os.environ["APP_ROW_LIMIT"]),
}

logger.info("Config loaded")
```

Do not log secrets, tokens, connection headers, query results, or customer data.

## Startup contract

- Importing `app.py` must not execute a query or wait for a warehouse.
- Construct the page shell immediately.
- Load remote data from a callback/request boundary.
- Show a loading state while the warehouse starts.
- Retry only transient failures with bounded exponential backoff.
- Do not silently replace production data with a local CSV. A demo fallback must be explicitly
  enabled, visibly labeled, and disabled in production.

## app.yaml

Prefer Databricks App resources so the warehouse ID and Gold table name are supplied by
deployment rather than embedded in source code. Add the resources in the Databricks Apps UI
with least privilege (`Can use` for the warehouse and `Select` for the table), and assign the
resource keys referenced below. Databricks exposes each resource through `valueFrom`.

```yaml
command: ["python", "app.py"]

env:
  - name: UC_TABLE_NAME
    valueFrom: gold-table
  - name: DATABRICKS_WAREHOUSE_ID
    valueFrom: sql-warehouse
  - name: APP_ROW_LIMIT
    value: "${APP_ROW_LIMIT}"
```

Never place OAuth secrets or personal access tokens in `app.yaml`. The App runtime supplies
its identity to the Databricks SDK.

## requirements.txt

```text
dash
plotly
pandas
databricks-sdk
```

Add only libraries actually imported. Do not add `pyspark` or `databricks-connect`.

## Layer error contracts

```python
# logic.py
from _logger import get_logger
from data import LogicError

logger = get_logger(__name__)


def build_summary(frame):
    logger.info("Running: build_summary")
    try:
        result = frame.groupby("region", as_index=False)["amount"].sum()
        logger.debug(f"Result: {len(result)} rows")
        return result
    except Exception as e:
        logger.error(f"Transformation failed: {e}")
        raise LogicError("Unable to prepare the requested summary") from e
```

```python
# app.py callback boundary
try:
    raw = load_orders(CONFIG, start_date, end_date)
    summary = build_summary(raw)
    return build_chart(summary, theme_mode)
except Exception as e:
    logger.error(f"Dashboard update failed: {e}")
    return error_figure("Data is temporarily unavailable", theme_mode)
```

## App identity permissions

Grant only what the app needs to its service principal. The following is illustrative; replace
identifiers from controlled deployment configuration, not source constants.

```sql
GRANT USE CATALOG ON CATALOG my_catalog TO `<app-application-id>`;
GRANT USE SCHEMA ON SCHEMA my_catalog.gold TO `<app-application-id>`;
GRANT SELECT ON TABLE my_catalog.gold.my_table TO `<app-application-id>`;
```

Do not grant ownership, `ALL PRIVILEGES`, Bronze/Silver access, or unrelated tables.

## App resources (programmatic setup)

App resources (SQL warehouse, serving endpoints) can be added programmatically via the
Databricks SDK — do not rely on manual UI steps. This removes a manual step from deployment:

```python
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.apps import (
    App, AppResource,
    AppResourceSqlWarehouse, AppResourceSqlWarehouseSqlWarehousePermission,
    AppResourceServingEndpoint, AppResourceServingEndpointServingEndpointPermission,
)

w = WorkspaceClient()
w.apps.update(
    name="my-app",
    app=App(
        name="my-app",
        resources=[
            AppResource(
                name="sql-warehouse",
                sql_warehouse=AppResourceSqlWarehouse(
                    id="<warehouse-id>",
                    permission=AppResourceSqlWarehouseSqlWarehousePermission.CAN_USE,
                ),
            ),
            AppResource(
                name="serving-endpoint",
                serving_endpoint=AppResourceServingEndpoint(
                    name="databricks-claude-sonnet-5",
                    permission=AppResourceServingEndpointServingEndpointPermission.CAN_QUERY,
                ),
            ),
        ],
    ),
)
```

Note: `apps.update()` takes `name` and `app` (an `App` object) — not keyword arguments
for individual fields like `resources=`. The SDK signature is `update(name: str, app: App)`.

## Deployment workflow

```bash
databricks apps create my-app
databricks sync . /Workspace/Shared/apps/my-app
databricks apps deploy my-app --source-code-path /Workspace/Shared/apps/my-app
databricks apps get my-app
```

Use the workspace's approved profile and release process. Do not deploy from a personal branch
to production without the required review.

## Debug checklist

1. App fails immediately
   - Check imports and `requirements.txt`.
   - Confirm no query runs at module import time.
   - Confirm environment variables exist without logging their values if sensitive.
   - Check for SDK imports that don't exist in the app runtime SDK version (e.g. `Config` is
     not directly importable from `databricks.sdk` — use `WorkspaceClient().config` instead).
2. Query fails
   - Confirm warehouse `CAN_USE` and UC `USE CATALOG`, `USE SCHEMA`, `SELECT`.
   - Confirm a Gold three-part table name and the configured warehouse ID.
   - Inspect structured app logs; do not expose warehouse details in the UI.
   - Check `wait_timeout` is between 5s and 50s (not above 50s) — the Statement Execution
     API silently rejects values outside this range with a 400.
3. UI is blank
   - Confirm callback return types and the layer boundary.
   - Return an accessible error figure/component instead of propagating an exception.
4. Theme is inconsistent
   - Load `@ui-ux-patterns` and use semantic tokens in both dark and light modes.
   - When renaming COLORS dict keys, audit ALL references across all files first —
     a missing key causes a KeyError that crashes the entire app.
5. LLM chat fails with 400
   - Check if the model supports `temperature` (Claude does not).
   - Check response content format — Claude Sonnet 5+ returns a list of content blocks,
     not a string. See @ai-chatbot skill for `_extract_text()` helper.
   - Check the serving endpoint is not deprecated — test with a minimal payload first.

## Acceptance checklist

- [ ] Five Python layers/files are present and imports flow in one direction.
- [ ] `data.py` is the only module containing SQL or `WorkspaceClient`.
- [ ] Gold-only three-part names are driven by configuration.
- [ ] No remote call runs during module import.
- [ ] Exceptions are logged and translated at boundaries.
- [ ] App identity has least privilege.
- [ ] Dark and light modes meet contrast and focus requirements.
- [ ] Production deployment is reproducible and reviewed.

## Forbidden

- `spark`, `SparkSession`, `pyspark`, or `databricks-connect` in an App.
- SQL outside `data.py`.
- Hardcoded catalog, schema, table, warehouse IDs, thresholds, or credentials.
- Business logic or KPI calculations in `ui.py`.
- Remote queries at module import time.
- Raw tracebacks or credential details in the UI/logs.
- Bronze/Silver reads in UI-facing apps.
- `debug=True` in production.
- `from databricks.sdk import Config` — use `WorkspaceClient().config` instead.
- `wait_timeout` above 50s on Statement Execution API.
- SVG logos in app assets — use PNG (SVGs are large and slow to write to workspace).
- Deploying without testing serving endpoints first (status code AND response shape).
- Renaming COLORS dict keys without auditing all references across all files.
