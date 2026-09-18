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
├── app.yaml            # command and resource-backed environment variables
├── requirements.txt
├── APP.md              # purpose, audience, Gold tables, filters, KPIs, acceptance criteria
└── deploy_app.py       # notebook — one-click deploy: assets, resources, permissions, deploy, verify
```

## Rules

- No Spark session exists in Databricks Apps.
- `data.py` uses `WorkspaceClient().statement_execution` and follows `@data-access`.
- `logic.py` has no SQL and no UI imports.
- `ui.py` has no SQL, remote access, KPI definitions, or aggregations.
- `app.py` owns validated configuration and orchestration; it contains no SQL.
- UI-facing reads are Gold-only and use three-part Unity Catalog names.
- Reuse centrally defined semantic KPIs; never recalculate them in an app.
- Catch and translate exceptions at every layer boundary. Never show raw tracebacks.
- Every visual UI supports `alpura-dark` and `alpura-light` from `@ui-ux-patterns`.

## Configuration pattern

All values vary by environment and must come from app resources or environment variables.
Validate them during startup without opening a remote connection.

```python
"""Application entry point and orchestration."""
import os

CONFIG = {
    "table_name": os.environ["UC_TABLE_NAME"],
    "warehouse_id": os.environ["DATABRICKS_WAREHOUSE_ID"],
    "row_limit": int(os.environ["APP_ROW_LIMIT"]),
}
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
from data import LogicError

def build_summary(frame):
    try:
        return frame.groupby("region", as_index=False)["amount"].sum()
    except Exception as e:
        raise LogicError("Unable to prepare the requested summary") from e
```

```python
# app.py callback boundary
try:
    raw = load_orders(CONFIG, start_date, end_date)
    summary = build_summary(raw)
    return build_chart(summary, theme_mode)
except Exception as e:
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

## Logo and Static Assets

The brand logo **must** be copied into the app's `assets/` directory at build time so it
is included in the deployment snapshot. Never rely on runtime file copy (`shutil.copy2`
from a workspace FUSE path) — the app's service principal cannot access arbitrary
workspace directories, and the FUSE mount may not be available.

```python
# CORRECT — copy at build time (before deploy), reference as static asset
import shutil
from pathlib import Path

LOGO_SOURCE = Path("/Workspace/Users/<user>/.assistant/brand/logo-full-colour-whitetext.png")
APP_ASSETS  = Path("/Workspace/Users/<user>/.assistant/apps/<app-name>/assets")
APP_ASSETS.mkdir(parents=True, exist_ok=True)
shutil.copy2(LOGO_SOURCE, APP_ASSETS / "logo.png")

# Then in app.py:
LOGO_SRC = "/assets/logo.png"   # Dash serves assets/ directory automatically
```

```python
# WRONG — runtime copy fails because the SP has no access to the brand folder
def _prepare_logo_asset() -> str:
    source = Path("/Workspace/Users/<user>/.assistant/brand/logo.png")
    shutil.copy2(source, destination)   # fails at runtime
```

## Deployment workflow

The agent **must not** rely on CLI or `executeCode` for permission grants — safety
guardrails block permission mutations from chat. Instead, scaffold a **deploy notebook**
(`deploy_<app_name>.py`) in the app source directory that does **everything** in
runnable cells under the user's identity. This notebook is the single deploy
artifact — the user runs it once and the app is live with full permissions.

### What the deploy notebook must do (in order)

1. **Copy static assets** (logo PNG) into the app's `assets/` directory
2. **Create the app** (or confirm it exists)
3. **Start compute** if stopped
4. **Add app resources** (SQL warehouse with CAN_USE)
5. **Grant permissions** (Genie Space CAN_RUN, UC table SELECT, etc.)
6. **Deploy the app** from the source code path
7. **Verify** app status is RUNNING and print the URL

### Deploy notebook template

```python
# Cell 1: Configuration
APP_NAME = "my-app-name"
SOURCE_PATH = "/Workspace/Users/<user>/.assistant/apps/<app-name>"
WAREHOUSE_ID = "<warehouse-id>"
GENIE_SPACE_ID = "<space-id>"  # omit if no chat tab
LOGO_SOURCE = "/Workspace/Users/<user>/.assistant/brand/logo-full-colour-whitetext.png"
```

```python
# Cell 2: Copy static assets
import shutil
from pathlib import Path

assets_dir = Path(SOURCE_PATH) / "assets"
assets_dir.mkdir(parents=True, exist_ok=True)
shutil.copy2(LOGO_SOURCE, assets_dir / "logo.png")
print(f"Logo copied to {assets_dir / 'logo.png'}")
```

```python
# Cell 3: Create or confirm app, start compute, add resources
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.apps import (
    App, AppResource,
    AppResourceSqlWarehouse, AppResourceSqlWarehouseSqlWarehousePermission,
)

w = WorkspaceClient()

# Create (idempotent)
try:
    app = w.apps.get(APP_NAME)
    print(f"App exists: {app.name}")
except Exception:
    app = w.apps.create(name=APP_NAME)
    print(f"Created app: {app.name}")

# Add warehouse resource
w.apps.update(
    name=APP_NAME,
    app=App(
        name=APP_NAME,
        resources=[
            AppResource(
                name="sql-warehouse",
                sql_warehouse=AppResourceSqlWarehouse(
                    id=WAREHOUSE_ID,
                    permission=AppResourceSqlWarehouseSqlWarehousePermission.CAN_USE,
                ),
            ),
        ],
    ),
)
print("Warehouse resource attached")
```

```python
# Cell 4: Grant Genie Space CAN_RUN (only for chat-enabled apps)
import requests

host = w.config.host.rstrip("/")
headers = {**w.config.authenticate(), "Content-Type": "application/json"}

app = w.apps.get(APP_NAME)
sp_name = app.service_principal_name
sps = list(w.service_principals.list(filter=f'displayName eq "{sp_name}"'))
app_id = sps[0].application_id

resp = requests.patch(
    f"{host}/api/2.0/permissions/genie/{GENIE_SPACE_ID}",
    headers=headers,
    json={"access_control_list": [{
        "service_principal_name": app_id,
        "permission_level": "CAN_RUN",
    }]},
)
assert resp.status_code == 200, f"Permission grant failed: {resp.text}"
print(f"Granted CAN_RUN on Genie Space to {sp_name} ({app_id})")
```

```python
# Cell 5: Deploy
deployment = w.apps.deploy(
    app_name=APP_NAME,
    source_code_path=SOURCE_PATH,
)
print(f"Deployed: {deployment.deployment_id} — status: {deployment.status.state.value}")
```

```python
# Cell 6: Verify
import time
time.sleep(10)
app = w.apps.get(APP_NAME)
print(f"App status: {app.app_status.state.value}")
print(f"Compute:   {app.compute_status.state.value}")
print(f"URL:       {app.url}")
```

### Rules

- The deploy notebook is **not optional** for chat-enabled apps — it is a required deliverable.
- The agent creates and populates this notebook as part of the scaffold, not as a post-deploy fix.
- The agent must **tell the user to run the notebook** rather than attempting CLI/SDK
  permission grants from chat (which will be blocked by safety guardrails).
- For apps without a chat tab, the deploy notebook is still recommended but the Genie
  permission cell can be omitted.

```bash
# Legacy CLI workflow (for reference only — prefer the deploy notebook)
databricks apps create my-app
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

- [ ] Four app files (app.py, data.py, logic.py, ui.py) plus deploy_app.py notebook are present.
- [ ] `data.py` is the only module containing SQL or `WorkspaceClient`.
- [ ] Gold-only three-part names are driven by configuration.
- [ ] No remote call runs during module import.
- [ ] Exceptions are logged and translated at boundaries.
- [ ] App identity has least privilege.
- [ ] Dark and light modes meet contrast and focus requirements.
- [ ] Production deployment is reproducible and reviewed.
- [ ] `deploy_app.py` notebook handles assets, resources, permissions, and deploy under the user's identity.

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
- Runtime `shutil.copy2` for logo/assets — the app SP cannot access workspace FUSE paths outside the snapshot. Copy assets into the source `assets/` directory **before** deploy.
- Leaving logo or static file references to workspace FUSE paths (`/Workspace/Users/...`) — use `/assets/<filename>` served by Dash/Flask.
- Depending on chat-time permission mutation for required app setup — if the app needs permissions/resources, scaffold and run `deploy_app.ipynb` under the user's identity.
