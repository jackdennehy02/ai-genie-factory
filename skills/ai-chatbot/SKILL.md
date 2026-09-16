---
name: ai-chatbot
description: >
  Patterns for building LLM-powered chat interfaces in Databricks Apps (Dash or Streamlit).
  Covers intent routing (conversation vs SQL), text-to-SQL with guardrails, Foundation Model
  API integration, two-phase Dash callbacks, writeback with auto-refresh, Plotly Scattergeo
  maps with route lines, fuzzy ID resolution, and chat bubble rendering. Load when building
  any app with a natural-language chat, text-to-SQL, or LLM integration. Always pair with
  data-access and databricks-app.
---

# AI Chatbot Skill

Apply when building a Databricks App with an LLM-powered chat interface.
The always-on module (`modules/ai_chatbot.md`) defines the guardrails;
this skill provides the implementation patterns.

## Intent routing

Never force SQL generation for every user message. The first LLM call must classify intent
and return structured JSON. The system prompt must offer two response formats:

```python
system_prompt = """
You are a fleet operations AI assistant. Return strict JSON only.
Choose ONE format:

1. Data questions: {"type": "sql", "sql": "<SELECT query>", "explanation": "<intent>"}
2. Conversation:   {"type": "conversation", "response": "<friendly reply>"}

Formatting rules (ALL responses):
- Never use emojis, emoji characters, or unicode symbols
- Use plain text only

SQL rules (only when type is "sql"):
- Single SELECT only, full table name, respect provided schema
- Never UPDATE/DELETE/INSERT/DROP/ALTER/TRUNCATE/MERGE/CREATE
"""
```

In the orchestrator, branch on the response:

```python
sql_text, explanation, notes = generate_sql_from_question(question, ids)
if sql_text is None:  # conversation
    return {"answer": explanation, "sql": None, "rows": [], ...}
# else: execute SQL, summarise, return full result
```

## Fuzzy ID resolution

Users type "truck 5" or "shipment 61" instead of "TRK-005" or "SHP-0061".
Resolve before sending to the LLM:

```python
def resolve_id(candidate, available_ids):
    candidate_upper = candidate.upper().replace(" ", "").replace("_", "-")
    exact_map = {v.upper(): v for v in available_ids}
    if candidate_upper in exact_map:
        return exact_map[candidate_upper]
    digits = re.sub(r"\D", "", candidate_upper)
    if digits:
        normalized = str(int(digits))
        matches = [v for v in available_ids if re.sub(r"\D", "", v) == normalized]
        if len(matches) == 1:
            return matches[0]
    return None

def resolve_identifier_mentions(question, shipment_ids, truck_ids):
    resolved, notes = question, []
    for pattern, id_list, label in [
        (r"\b(?:shipment|shp)[\s\-#:]*([0-9]+)\b", shipment_ids, "shipment"),
        (r"\b(?:truck|trk)[\s\-#:]*([0-9]+)\b", truck_ids, "truck"),
    ]:
        for match in re.finditer(pattern, question, flags=re.IGNORECASE):
            replacement = resolve_id(match.group(0), id_list) or resolve_id(match.group(1), id_list)
            if replacement:
                resolved = resolved.replace(match.group(0), replacement)
                notes.append(f"Resolved {match.group(0)} to {replacement}")
    return resolved, notes
```

## Two-phase Dash callback pattern

Dash callbacks are synchronous. To show instant feedback while the LLM processes:

**Phase 1 (instant):** User sends message. Append user bubble to history, show typing
indicator, clear input, set `pending-question` store.

**Phase 2 (async):** Triggered by `pending-question` store change. Runs full LLM pipeline,
replaces typing indicator with response, clears `pending-question`.

```python
# Phase 1 — instant feedback
@app.callback(
    Output("chat-store", "data", allow_duplicate=True),
    Output("chat-thread", "children", allow_duplicate=True),
    Output("chat-input", "value"),
    Output("pending-question", "data"),
    Input("chat-submit", "n_clicks"),
    State("chat-input", "value"),
    State("chat-store", "data"),
    prevent_initial_call=True,
)
def send_message(n_clicks, question, history):
    # append user bubble, show typing_bubble(), return

# Phase 2 — LLM call
@app.callback(
    Output("chat-store", "data"),
    Output("chat-thread", "children"),
    Output("pending-question", "data", allow_duplicate=True),
    Input("pending-question", "data"),
    State("chat-store", "data"),
    prevent_initial_call=True,
)
def process_question(question, history):
    # call LLM, append assistant message, render full history
```

Critical: `chat-store` must be `State` (not `Input`) on the tab-rendering callback.
If it's `Input`, every message appended to the store re-renders the entire tab,
overwriting the chat thread.

## Dynamic component proxy pattern

Buttons created inside dynamically-rendered content (e.g. inside `tab-content`) cannot be
`Input` on callbacks that fire at initial page load — the component doesn't exist yet.

Solution: use a proxy through an existing `dcc.Store`:

```python
# The table-refresh-btn lives inside the Operations tab (dynamic)
# It can't be Input on the filter callback. Instead:
@app.callback(
    Output("status-refresh", "data", allow_duplicate=True),
    Input("table-refresh-btn", "n_clicks"),
    State("status-refresh", "data"),
    prevent_initial_call=True,  # never fires at page load
)
def handle_table_refresh(n_clicks, counter):
    if not n_clicks:
        return no_update
    return (counter or 0) + 1
```

The existing filter/tab callbacks already listen to `status-refresh` as Input,
so they re-fire automatically.

## Writeback with auto-refresh

For UPDATE operations (e.g. changing shipment status):

```python
@app.callback(
    Output("writeback-message", "children"),
    Output("status-refresh", "data"),      # triggers table reload
    Input("submit-status-btn", "n_clicks"),
    State("writeback-shipment-id", "value"),
    State("writeback-status", "value"),
    State("writeback-delay-reason", "value"),
    State("status-refresh", "data"),
    prevent_initial_call=True,
)
def handle_status_update(n_clicks, shipment_id, new_status, delay_reason, counter):
    # validate inputs, run UPDATE, increment counter
    return dbc.Alert(result, color="success"), (counter or 0) + 1
```

Wrap the submit button in `dcc.Loading` for visual feedback:

```python
dcc.Loading(
    type="default",
    color=COLORS["interactive"],
    children=html.Div([
        dbc.Button("Update shipment", id="submit-status-btn"),
        html.Div(id="writeback-message"),
    ]),
)
```

Conditional fields (e.g. delay_reason only required when status is "Delayed"):

```python
safe_delay_reason = delay_reason if new_status == "Delayed" else None
query = f"UPDATE {TABLE} SET status = {sql_literal(new_status)}, "
        f"delay_reason = {sql_literal(safe_delay_reason)}, "
        f"updated_at = current_timestamp() "
        f"WHERE shipment_id = {sql_literal(shipment_id)}"
```

## Plotly Scattergeo map with route lines

For fleet/logistics apps, show both city markers and route lines between origin
and destination:

```python
def build_map(frame):
    fig = go.Figure()

    # Route lines first (so markers render on top)
    for _, row in frame.iterrows():
        o_lat, o_lon = COORDINATES.get(row["origin"], (None, None))
        d_lat, d_lon = COORDINATES.get(row["destination"], (None, None))
        if o_lat is None or d_lat is None:
            continue
        fig.add_trace(go.Scattergeo(
            lat=[o_lat, d_lat], lon=[o_lon, d_lon],
            mode="lines",
            line={"width": 1.2, "color": STATUS_COLORS.get(row["status"], "#ccc")},
            opacity=0.4, showlegend=False, hoverinfo="skip",
        ))

    # City markers by status
    for status in STATUS_OPTIONS:
        subset = frame[frame["status"] == status]
        if subset.empty:
            continue
        fig.add_trace(go.Scattergeo(
            lat=subset["lat"], lon=subset["lon"],
            mode="markers",
            marker={"size": 12, "color": STATUS_COLORS[status]},
            name=status,
            text=[f"Route: {o} > {d}<br>Status: {s}" for o, d, s in
                  zip(subset["origin"], subset["destination"], subset["status"])],
            hoverinfo="text",
        ))

    fig.update_geos(scope="africa", showcountries=True)
    fig.update_layout(height=620, margin={"l": 0, "r": 0, "t": 50, "b": 0})
    return fig
```

Key learnings:
- Set explicit `height` (620+) — default Scattergeo is too small
- Route lines use `opacity=0.4` and `showlegend=False` to avoid clutter
- Use hardcoded `CITY_COORDINATES` dict when geocoding APIs aren't available
- Render lines before markers so markers sit on top

## Scrollable tables (never paginate)

Always use vertical scroll with fixed headers instead of pagination:

```python
dash_table.DataTable(
    columns=columns,
    data=data,
    sort_action="native",
    filter_action="native",
    fixed_rows={"headers": True},
    style_table={"overflowX": "auto", "overflowY": "auto", "maxHeight": "480px"},
    style_cell={"textAlign": "left", "padding": "10px", "minWidth": "100px"},
)
```

For tables inside chat bubbles, use a smaller `maxHeight` (260px).
Never use `page_size` — it creates pagination controls.

## Chat bubble rendering

SMS-style: user right-aligned (dark background), AI left-aligned (light surface).
Use `dcc.Markdown` for AI content (supports headers, lists, code blocks).
Format SQL with `sqlparse.format(reindent=True, keyword_case="upper")`.

```python
# AI bubble structure
parts = [
    html.Div("Fleet AI", style={"fontWeight": 700, "fontSize": "0.8rem"}),
    dcc.Markdown(content, dangerously_allow_html=False),
]
if sql:
    parts.append(dcc.Markdown(f"```sql\n{formatted_sql}\n```"))
if rows:
    parts.append(dash_table.DataTable(...))
```

Typing indicator: simple spinner + "Thinking..." label. Do not show multi-step
progress indicators that cannot actually advance (Dash callbacks are synchronous
— there is no way to update the UI mid-callback).

## Streaming limitation in Dash

Dash has no native SSE or WebSocket support. True token-level streaming requires:
- Background thread writing to a server-side buffer
- `dcc.Interval` polling every 250ms
- Re-rendering the entire chat thread on each poll

This works but introduces visible lag on every poll cycle. For production apps
requiring streaming, recommend FastAPI + React (AppKit) instead of Dash.
The two-phase pattern (instant typing bubble then full response) is the practical
ceiling for Dash.

## Foundation Model endpoint testing

Endpoints deprecate without warning. Test at app startup or in deployment:

```python
resp = requests.post(
    f"{host}/serving-endpoints/{endpoint}/invocations",
    headers=headers,
    json={"messages": [{"role": "user", "content": "test"}], "max_tokens": 5},
    timeout=10,
)
if resp.status_code != 200:
    logger.error(f"Endpoint {endpoint} returned {resp.status_code}")
```

## Cross-filtering pattern

For apps with multiple filter dropdowns that constrain each other:

```python
@app.callback(
    Output("truck-filter", "options"),
    Output("shipment-filter", "options"),
    Input("truck-filter", "value"),
    Input("shipment-filter", "value"),
    Input("refresh-button", "n_clicks"),
    Input("status-refresh", "data"),
)
def update_filter_options(selected_truck, selected_shipment, _r, _s):
    frame = load_data()
    truck_frame = frame if not selected_shipment else frame[frame["shipment_id"] == selected_shipment]
    shipment_frame = frame if not selected_truck else frame[frame["truck_id"] == selected_truck]
    return (
        [{"label": t, "value": t} for t in sorted(truck_frame["truck_id"].unique())],
        [{"label": s, "value": s} for s in sorted(shipment_frame["shipment_id"].unique())],
    )
```

## Forbidden

- Generating UPDATE/INSERT/DELETE from LLM chat output
- Showing fake progress steps that cannot advance in Dash's callback model
- Using `page_size` on DataTables (use scrolling)
- Raw f-string interpolation of user input into SQL
- Emojis or unicode symbols in any LLM system prompt
- Hardcoded serving endpoint names without startup validation
- `chat-store` as `Input` (not `State`) on tab-rendering callbacks
