---
name: ai-chatbot
description: >
  Genie Agent wrapper for chat interfaces in Databricks Apps (Dash or Streamlit).
  Wraps Databricks Genie Conversation API via the Python SDK to embed a curated
  data agent directly in the app. Covers: checking for / creating a Genie Agent,
  data.py wrapper functions, two-phase Dash callbacks, chat bubble rendering, and
  service principal permissions. Load when building any app with a chat tab or
  conversational analytics. Always pair with data-access and databricks-app.
---

# AI Chatbot Skill — Genie Agent Wrapper

The standard chat pattern for Databricks Apps is to wrap a **Genie Agent** using
the Python SDK Conversation API. The Genie Agent handles SQL generation, query
execution, analysis, and conversation context — the app only renders the results.

Do NOT build custom LLM chat pipelines (system prompts, text-to-SQL, intent
routing, Foundation Model API calls). A Genie Agent provides all of this out of
the box with curated tables, instructions, and governed access.

## Prerequisites

1. A **Genie Agent** (Genie Space) configured over the app's data tables
2. The app's **service principal** granted `CAN_RUN` on the Genie Space
3. A **SQL warehouse** attached to the Genie Agent

If the user already has a Genie Agent, get its Space ID. If not, create one
(see "Creating a Genie Agent" below).

## Creating a Genie Agent (if one doesn't exist)

Before building the chat tab, check whether the user already has a Genie Agent
over their data. Search with:

```python
from databricks.sdk import WorkspaceClient
w = WorkspaceClient()
spaces = w.genie.list_spaces()
for s in (spaces.spaces or []):
    print(f"{s.space_id}: {s.title}")
```

If no agent exists, create one using the CLI. See the `@databricks-genie-agents`
skill for full details — summary below:

```bash
# Discover the schema first
databricks experimental aitools tools discover-schema catalog.schema.gold_table

# Create parent directory
databricks workspace mkdirs /Workspace/Users/user@company.com/genie_spaces

# Create the Genie Agent
databricks genie create-space --json "{
  \"warehouse_id\": \"WAREHOUSE_ID\",
  \"title\": \"My Analytics Agent\",
  \"description\": \"Natural language analytics over ...\",
  \"parent_path\": \"/Workspace/Users/user@company.com/genie_spaces\",
  \"serialized_space\": $(cat genie_agent.json | jq -c '.' | jq -Rs '.')
}"
```

The `genie_agent.json` file follows the serialized_space format documented in
`@databricks-genie-agents`. Include `sample_questions`, `data_sources.tables`,
and `text_instructions` for best results.

## Service principal permissions

The app's service principal needs `CAN_RUN` on the Genie Space. **This must be
granted as part of the automated deploy flow** — never left as a manual post-deploy
step for the user. The Permissions API requires the SP's `application_id` (UUID),
not its display name.

### Why it must be in the deploy notebook

- Agent safety guardrails **will block** `executeCode`, `runDatabricksCli`, and
  any other chat-time tool that mutates permissions. This is not a bug — it is a
  hard constraint of the environment.
- A standalone `setup_permissions.py` script is a band-aid — it still requires
  the user to manually run something after deploy, which defeats the purpose.
- The deploy notebook (`deploy_<app_name>.py`) is a single "Run All" artifact
  that creates the app, attaches resources, grants permissions, deploys, and
  verifies — all in one go under the user's identity.
- See `@databricks-app` skill → "Deployment workflow" for the full deploy
  notebook template with all cells.

### Permission grant code (goes in the deploy notebook)

```python
import requests
from databricks.sdk import WorkspaceClient

w = WorkspaceClient()
host = w.config.host.rstrip("/")
headers = {**w.config.authenticate(), "Content-Type": "application/json"}

app = w.apps.get(APP_NAME)
sp_name = app.service_principal_name
sps = list(w.service_principals.list(filter=f'displayName eq "{sp_name}"'))
app_id = sps[0].application_id  # UUID like "0b9286a5-..."

resp = requests.patch(
    f"{host}/api/2.0/permissions/genie/{GENIE_SPACE_ID}",
    headers=headers,
    json={"access_control_list": [{
        "service_principal_name": app_id,
        "permission_level": "CAN_RUN",
    }]},
)
assert resp.status_code == 200, f"Permission grant failed: {resp.text}"
print(f"Granted CAN_RUN to {sp_name} ({app_id})")
```

Valid Genie permission levels: `CAN_READ`, `CAN_RUN`, `CAN_EDIT`, `CAN_MANAGE`.
Use `CAN_RUN` for app service principals (allows asking questions).

### What the agent must do

1. Scaffold all app source files as usual
2. Create the deploy notebook with the Genie permission cell included
3. Tell the user: "Run the deploy notebook to create, configure, and deploy the app"
4. **Never** attempt the permission grant from chat — it will be blocked
5. **Never** create a standalone permissions script — it is a dead-end workaround

## app.yaml — no serving endpoint needed

Unlike custom LLM chat, Genie wrapping does NOT require a `serving-endpoint`
resource. The Genie Agent uses its own warehouse. The app only needs:

```yaml
env:
  - name: UC_TABLE_NAME
    value: "catalog.schema.table"
  - name: DATABRICKS_WAREHOUSE_ID
    valueFrom: sql-warehouse
  - name: GENIE_SPACE_ID
    value: "01f1b273..."
resources:
  - name: sql-warehouse
    sql_warehouse:
      id: "0c209b50d58025d6"
      permission: CAN_USE
```

## Data layer — Genie wrapper functions (data.py)

Add these to `data.py` alongside existing data access functions.
The SDK handles auth, polling, and timeouts.

```python
from datetime import timedelta
from typing import Any
from databricks.sdk import WorkspaceClient


def genie_start_conversation(space_id: str, question: str) -> dict[str, Any]:
    """Start a Genie conversation and return the first response."""
    try:
        client = WorkspaceClient()
        msg = client.genie.start_conversation_and_wait(
            space_id=space_id,
            content=question,
            timeout=timedelta(seconds=120),
        )
        return _parse_genie_message(msg)
    except Exception as e:
        raise DataAccessError(f"Genie unavailable: {e}") from e


def genie_follow_up(space_id: str, conversation_id: str, question: str) -> dict[str, Any]:
    """Send a follow-up message in an existing Genie conversation."""
    try:
        client = WorkspaceClient()
        msg = client.genie.create_message_and_wait(
            space_id=space_id,
            conversation_id=conversation_id,
            content=question,
            timeout=timedelta(seconds=120),
        )
        return _parse_genie_message(msg)
    except Exception as e:
        raise DataAccessError(f"Genie unavailable: {e}") from e


def _parse_genie_message(msg: Any) -> dict[str, Any]:
    """Extract text, SQL, and description from a GenieMessage."""
    text, sql, description = "", "", ""
    for att in (msg.attachments or []):
        if hasattr(att, "text") and att.text:
            text = att.text.content or ""
        if hasattr(att, "query") and att.query:
            sql = att.query.query or ""
            description = att.query.description or ""
    return {
        "conversation_id": msg.conversation_id,
        "text": text,
        "sql": sql,
        "description": description,
    }
```

Key points:
- `start_conversation_and_wait` creates a new conversation + sends the first message
- `create_message_and_wait` sends follow-ups in the same conversation (Genie retains context)
- The SDK polls internally until `COMPLETED` or timeout
- Response includes `text` (natural language analysis), `sql` (generated query), and `description`

## UI layer — chat bubbles (ui.py)

SMS-style: user right-aligned (accent background), Genie left-aligned (surface background).
Use `dcc.Markdown` for Genie content (supports bold, lists, code).
Show generated SQL in a fenced code block below the analysis.

```python
def chat_bubble(role: str, text: str, sql: str = "", mode: str = "snap-dark") -> html.Div:
    """Render a single chat bubble (user or assistant)."""
    colors = _theme(mode)
    is_user = role == "user"
    bg = colors["accent"] if is_user else colors["surface"]
    fg = "#FFFFFF" if is_user else colors["text"]
    align = "flex-end" if is_user else "flex-start"
    children = []
    if not is_user:
        children.append(
            html.Div("Genie", style={"fontWeight": "700", "fontSize": "0.8rem", "marginBottom": "6px"})
        )
    children.append(dcc.Markdown(text, dangerously_allow_html=False, className="chat-markdown"))
    if sql:
        children.append(dcc.Markdown(f"```sql\n{sql}\n```", dangerously_allow_html=False))
    return html.Div(
        html.Div(children, style={
            "maxWidth": "720px", "padding": "14px 18px", "borderRadius": "18px",
            "background": bg, "color": fg,
            "border": "none" if is_user else f"1px solid {colors['border']}",
            "boxShadow": colors["shadow"],
        }),
        style={"display": "flex", "justifyContent": align, "marginBottom": "12px"},
    )


def render_chat_history(messages: list, mode: str = "snap-dark") -> list:
    """Convert message list to chat bubble components."""
    return [chat_bubble(m["role"], m["text"], m.get("sql", ""), mode) for m in messages]
```

## App layer — two-phase Dash callbacks (app.py)

Dash callbacks are synchronous. Use two phases to show instant feedback while
Genie processes the question.

**Phase 1 (instant):** Append user bubble, show "Thinking...", clear input, set pending question.
**Phase 2 (Genie call):** Triggered by pending-question store. Calls Genie API, renders response.

### Config

```python
GENIE_SPACE_ID = os.environ.get("GENIE_SPACE_ID", "")
```

### Stores and layout

```python
# In the Chat tab children:
dcc.Store(id="chat-history", data=[]),
dcc.Store(id="genie-conv-id", data=""),
dcc.Store(id="pending-q", data=None),
html.Div(id="chat-thread", style={
    "maxWidth": "800px", "margin": "0 auto",
    "height": "calc(100vh - 320px)", "overflowY": "auto",
    "padding": "16px 4px",
}),
html.Div([
    dcc.Textarea(id="chat-input", placeholder="Ask about your data...", style={...}),
    html.Button("Send", id="chat-send", n_clicks=0, style={...}),
], style={"maxWidth": "800px", "margin": "12px auto 0 auto"}),
```

### Callbacks

```python
from dash import Dash, Input, Output, State, no_update
from data import genie_start_conversation, genie_follow_up
from ui import render_chat_history


@app.callback(
    Output("chat-history", "data", allow_duplicate=True),
    Output("chat-thread", "children", allow_duplicate=True),
    Output("chat-input", "value"),
    Output("pending-q", "data"),
    Input("chat-send", "n_clicks"),
    State("chat-input", "value"),
    State("chat-history", "data"),
    prevent_initial_call=True,
)
def chat_send(n_clicks, question, history):
    if not n_clicks or not question or not question.strip():
        return no_update, no_update, no_update, no_update
    history = (history or []) + [{"role": "user", "text": question.strip()}]
    bubbles = render_chat_history(history, MODE) + [
        html.Div("Thinking...", style={"color": "#A0A0A0", "padding": "12px", "textAlign": "center"}),
    ]
    return history, bubbles, "", question.strip()


@app.callback(
    Output("chat-history", "data"),
    Output("chat-thread", "children"),
    Output("genie-conv-id", "data"),
    Output("pending-q", "data", allow_duplicate=True),
    Input("pending-q", "data"),
    State("chat-history", "data"),
    State("genie-conv-id", "data"),
    prevent_initial_call=True,
)
def chat_process(question, history, conv_id):
    if not question:
        return no_update, no_update, no_update, no_update
    try:
        if conv_id:
            result = genie_follow_up(GENIE_SPACE_ID, conv_id, question)
        else:
            result = genie_start_conversation(GENIE_SPACE_ID, question)
        assistant_msg = {"role": "assistant", "text": result["text"], "sql": result.get("sql", "")}
        new_conv_id = result["conversation_id"]
    except Exception:
        assistant_msg = {"role": "assistant", "text": "The Genie Agent is temporarily unavailable. Please try again."}
        new_conv_id = conv_id or ""
    history = (history or []) + [assistant_msg]
    return history, render_chat_history(history, MODE), new_conv_id, None
```

Key points:
- `genie-conv-id` store tracks conversation continuity across messages
- First message uses `genie_start_conversation`, follow-ups use `genie_follow_up`
- Genie handles conversation context, SQL generation, and analysis internally
- No system prompt, no intent routing, no SQL guardrails needed — Genie does it all

## Chat layout rules

- Chat thread container: `maxWidth: 800px`, centered. Full-width is unreadable.
- Chat thread height: `calc(100vh - 320px)` to fill viewport.
- Typing indicator: simple "Thinking..." text. Do NOT show multi-step progress
  (Dash callbacks are synchronous — no mid-callback UI updates).

## Message format

The `chat-history` store holds a flat list of dicts:

```python
[
    {"role": "user", "text": "What are top countries by revenue?"},
    {"role": "assistant", "text": "The top 3 countries...", "sql": "SELECT ..."},
]
```

## Forbidden

- Building custom LLM chat pipelines (system prompts, text-to-SQL, intent routing)
- Foundation Model API calls for chat — use Genie Agent instead
- Separate "JSON classifier" and "analyst" system prompts
- `chat-history` as `Input` (not `State`) on tab-rendering callbacks
- iframe or link cards to the Genie Space (wraps via SDK, not navigation)
- Showing fake multi-step progress indicators in Dash
- Raw f-string interpolation of user input into SQL
- `serving-endpoint` resource in app.yaml for chat (not needed with Genie)
- Leaving Genie Space `CAN_RUN` permission as a manual post-deploy step — automate it in `deploy_app.ipynb`
- Deploying a chat-enabled app without first verifying the SP has `CAN_RUN` on the Genie Space
- Shipping a chat-enabled app without scaffolding `deploy_app.ipynb`
