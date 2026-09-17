You are operating under the AI Genie Factory constraints loaded in your instructions file.
Load all five skills in parallel before generating any code:
  @data-access @ui-ux-patterns @databricks-app @ai-chatbot @testing-scaffold

Apply constraints with this exact priority (highest = 1):

  1. GLOBAL_RULES              — never override
  2. STACK                     — never override
  3. ERROR_HANDLING            — never override
  4. @data-access               — WorkspaceClient Statement Execution; override only if
                                  APP spec requires a different data source type
  5. @ui-ux-patterns            — never override (chart library is always Plotly)
  6. @databricks-app            — app file layers, app.yaml, deployment
  7. @ai-chatbot                — Genie Agent wrapper for Chat tab (if app has chat)
  8. @dlt-pipeline              — applies only if APP spec requests a pipeline
  9. @testing-scaffold          — never override
 10. APP SPEC below             — app-specific configuration only

Databricks Apps have no Spark session. Notebooks and DLT pipelines do — do not mix the two
runtimes' data-access patterns in the same file.

---

DEFAULT INFRASTRUCTURE

Unless APP SPEC overrides, use these defaults:
  - Warehouse: snap-dbx-sandbox-sql-wh (ID: 0c209b50d58025d6)
  - Brand logo source: /Workspace/Users/<deployer>/.assistant/brand/logo-full-colour-whitetext.png
  - App row limit: 5000

---

OUTPUT REQUIREMENTS

Produce exactly these files:

  data.py           — data layer: WorkspaceClient Statement Execution reads + Genie wrapper
  logic.py          — logic layer: aggregations, transformations, business rules
  ui.py             — UI layer: Plotly figures, chat bubbles, theme tokens
  app.py            — entry point: imports from data/logic/ui, no inline logic
  app.yaml          — command + resource-backed env vars (warehouse ID, table name, Genie Space ID)
  requirements.txt  — dash, plotly, pandas, databricks-sdk, requests
  assets/logo.png   — copy from brand/ folder (shutil.copy2, never editAsset for binary files)
  tests/
    test_data.py    — unit test stubs for data.py (WorkspaceClient mocked)
    test_logic.py   — unit test stubs for logic.py

Each file must start with a module docstring identifying its layer:
  """Data layer — WorkspaceClient Statement Execution reads. No transformation logic."""

---

LAYER CONTRACTS

data.py:
  - ONLY WorkspaceClient().statement_execution reads, per @data-access
  - Genie wrapper functions (genie_start_conversation, genie_follow_up) for chat, per @ai-chatbot
  - Returns pandas.DataFrame directly — no Spark, no .toPandas()
  - NO aggregations, groupBy, or business logic
  - NO imports from logic.py or ui.py
  - All table references must be three-part: catalog.schema.table, Gold schema only
  - Bind user-provided values as Statement Execution parameters — never string-interpolate SQL
  - Wrap every call in try/except → raise DataAccessError

logic.py:
  - ONLY aggregations, groupby, business rules — pandas operations on the DataFrame data.py returned
  - NO SQL, NO WorkspaceClient, NO Spark
  - NO Plotly imports or UI code
  - NO imports from ui.py
  - Wrap operations in try/except → raise LogicError

ui.py:
  - ONLY Plotly figure construction from the pandas DataFrame logic.py returned
  - Chat bubble components (chat_bubble, render_chat_history) per @ai-chatbot
  - NO pandas conversion here — data.py already returns pandas, there is nothing to convert
  - NO SQL, NO WorkspaceClient, NO Spark
  - NO business logic
  - Chart functions must be pure: accept pandas DataFrame, return plotly.Figure
  - Catch exceptions → return an error figure/component, never a raw traceback

app.py:
  - Entry point only
  - Imports: from data import ...; from logic import ...; from ui import ...
  - No inline logic, no direct WorkspaceClient calls, no direct Plotly calls
  - No remote call at module import time — config validated, data loaded from a callback
  - Config dict at top of file reads from env vars (no hardcoded strings elsewhere)
  - Chat tab uses two-phase Dash callbacks per @ai-chatbot

---

FORBIDDEN (applies to all files)

  - Merging any two layers into one file
  - Any dependency not in STACK.md
  - spark, SparkSession, pyspark, or databricks-connect anywhere in a Databricks App
  - .toPandas() anywhere — Apps use pandas throughout; data.py returns it already
  - Redefining a KPI that exists in the semantic layer (read the Gold view instead)
  - Hardcoded catalog, schema, table, or warehouse IDs outside app.py config dict
  - Bare except: clauses (always catch Exception as e)
  - Reading from Bronze or Silver tables in UI-facing apps
  - A remote query running at module import time
  - Custom LLM chat pipelines (system prompts, text-to-SQL, Foundation Model API) — use Genie Agent
  - serving-endpoint resource in app.yaml for chat

---

DEPLOYMENT

After writing all source files, deploy the app automatically:

1. Create the Databricks App (if it doesn't exist):
   databricks apps create <app-name> --json '{"description": "..."}'

2. Check app status:
   databricks apps get <app-name> --output JSON
   If STOPPED → databricks apps start <app-name> --timeout 20m
   If RUNNING → proceed to deploy

3. Deploy:
   from databricks.sdk import WorkspaceClient
   from databricks.sdk.service.apps import AppDeployment
   from datetime import timedelta
   w = WorkspaceClient()
   result = w.apps.deploy(
       app_name="<app-name>",
       app_deployment=AppDeployment(source_code_path="<source-path>"),
   ).result(timeout=timedelta(minutes=10))

4. Grant Genie Space access (if chat tab exists):
   Use Permissions API with SP's application_id UUID, permission_level CAN_RUN

---

APP SPEC

[PASTE APP.md CONTENT HERE — everything below this line is app-specific]
