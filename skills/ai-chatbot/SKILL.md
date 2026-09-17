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

## Unified system prompt (analyst + query generator)

One system prompt, one persona, one conversation. The LLM is an analyst who CAN
query data — not a query generator with a separate analyst bolted on. The JSON
format includes `analysis` for SQL results so intent classification and analytical
thinking happen in a single call.

```python
SYSTEM_PROMPT = f"""You are a sharp fleet operations analyst with access to a shipments database.
You can query data AND reason about it in a single response.

Return strict JSON in ONE of these formats:

1. When you need to query data:
{{{{
  "type": "sql",
  "sql": "<SELECT query>",
  "analysis": "<markdown analysis of what you expect to find and why>"
}}}}

2. When answering from conversation context, prior results, or general knowledge:
{{{{
  "type": "conversation",
  "response": "<markdown response>"
}}}}

You are an ANALYST, not a query generator. When results come back, you will be
asked to analyse them. Scrutinise every value. Flag anomalies, data quality issues,
entries that look like human commentary or don't fit the pattern. Be specific —
reference exact values. Use markdown: **bold headers**, bullet points, and a
**Recommended Actions** section when relevant.

Rules:
- Never use emojis or unicode symbols
- SQL: SELECT only, full table name: {{CONFIG['table_name']}}
- Never UPDATE/DELETE/INSERT/DROP/ALTER/TRUNCATE/MERGE/CREATE
- Always LIMIT 100 unless user asks for a specific count
- When the user asks a follow-up about data already shown, respond as conversation —
  do NOT re-run the same query

Schema:
{{SCHEMA_DESCRIPTION}}"""
```

In the orchestrator, branch on the response type:

```python
llm_response = _call_llm(messages)
if llm_response.get("type") == "sql":
    # execute SQL, feed results back for analysis (see below)
else:
    answer = llm_response.get("response", "")
    return {"answer": answer, "sql": None, "rows": [], "columns": []}
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

## Conversation history with data context

Every LLM call must include full conversation history. Assistant messages must include
actual SQL results (first 20 rows), not just "[returned N rows]". Without the data,
the LLM cannot answer follow-ups.

```python
def _build_history_messages(history: list[dict]) -> list[dict]:
    """Convert chat store into LLM messages with full data context."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for msg in history:
        if msg["role"] == "user":
            messages.append({"role": "user", "content": msg["content"]})
        else:
            parts = [msg.get("content", "")]
            if msg.get("sql"):
                parts.append(f"\nSQL executed:\n{msg['sql']}")
                rows = msg.get("rows", [])
                if rows:
                    preview = rows[:20]
                    cols = list(preview[0].keys()) if preview else []
                    lines = [" | ".join(cols)] + [
                        " | ".join(str(r.get(c, "")) for c in cols) for r in preview
                    ]
                    parts.append(f"\nResults ({len(rows)} rows):\n" + "\n".join(lines))
                    if len(rows) > 20:
                        parts.append(f"... and {len(rows) - 20} more rows")
            messages.append({"role": "assistant", "content": "\n".join(parts)})
    return messages
```

## Single-conversation analysis (feed results back)

After executing SQL, feed the results back into the SAME conversation and ask
the LLM to analyse them. This keeps one system prompt, one persona, one context.
The LLM knows WHY it queried and WHAT to look for because it's the same conversation.

```python
def _process_chat_question(question, df, history):
    messages = _build_history_messages(history)
    messages.append({"role": "user", "content": resolved_question})
    llm_response = _call_llm(messages)  # Single call — classifies + generates SQL

    if llm_response.get("type") == "sql":
        # Execute SQL
        safe_sql = _enforce_select_only(llm_response["sql"], table_name)
        result_df, cols = execute_chat_sql(CONFIG, safe_sql)
        rows = result_df.head(100).to_dict("records")

        # Feed results back into the SAME conversation
        # Show ALL rows up to 100 — never truncate small result sets
        preview_limit = min(len(result_df), 100)
        result_preview = result_df.head(preview_limit).to_string(index=False)
        messages.append({"role": "assistant", "content": json.dumps(llm_response)})
        messages.append({"role": "user", "content": (
            f"The query returned {len(result_df)} rows:\n\n{result_preview}\n\n"
            # No "...(and N more)" — the LLM will say "results were truncated"
            "Answer my original question directly based on these results. "
            "Be concise — lead with the answer, reference specific values. "
            "Only flag anomalies if something genuinely stands out; don't force it. "
            "Use markdown with **bold headers** and bullet points where helpful. "
            "Use markdown in your response field. "
            'Respond as: {"type": "conversation", "response": "<your markdown analysis>"}'
        )})
        analysis_response = _call_llm(messages)
        analysis = analysis_response.get("response", "") or analysis_response.get("analysis", "")
        if not analysis:
            analysis = llm_response.get("analysis", "Query executed successfully.")

        return {"answer": analysis, "sql": formatted_sql, "rows": rows, "columns": cols}
    else:
        return {"answer": llm_response.get("response", ""), "sql": None, "rows": [], "columns": []}
```

Why this works:
- The analyst persona is set ONCE in SYSTEM_PROMPT and applies to everything.
- Results are fed back as a user message in the same thread — no conflicting prompts.
- Follow-ups work naturally because the LLM has the full history including data.
- The analysis instruction says what to DO (examine values, flag anomalies) with formatting
  as a lightweight suffix — not the other way around.

## Claude content block format

Claude Sonnet 5+, Opus 4+ return `content` as a list of typed blocks, not a
plain string. This causes `AttributeError: 'list' object has no attribute 'strip'`
if not handled. Always extract text blocks:

```python
def _extract_text(content) -> str:
    """Extract text from Claude's content block format or plain string."""
    if isinstance(content, list):
        text_parts = [block["text"] for block in content if block.get("type") == "text"]
        return "\n".join(text_parts)
    return content
```

Call `_extract_text()` immediately after reading `response["choices"][0]["message"]["content"]`
in every LLM call function.

## LLM call pattern

The `_call_llm` function must accept a full messages list (not a single question
string). Never include `temperature` — Claude models reject it with 400.

```python
def _call_llm(messages: list[dict]) -> dict:
    """Call serving endpoint with conversation history. Returns parsed JSON."""
    try:
        _client = WorkspaceClient()
        host = _client.config.host
        endpoint = CONFIG["serving_endpoint"]
        url = f"{host}/serving-endpoints/{endpoint}/invocations"

        headers = {"Content-Type": "application/json"}
        headers.update(_client.config.authenticate())

        payload = {"messages": messages, "max_tokens": 2048}
        # Do NOT include temperature — Claude models reject it
        resp = requests.post(url, headers=headers, json=payload, timeout=90)
        resp.raise_for_status()
        content = _extract_text(resp.json()["choices"][0]["message"]["content"])

        content = content.strip()
        if content.startswith("```"):
            content = re.sub(r"^```[a-zA-Z]*\n?", "", content)
            content = re.sub(r"\n?```$", "", content)
        return json.loads(content)
    except json.JSONDecodeError:
        return {"type": "conversation", "response": content}
    except Exception as e:
        logger.error(f"LLM call failed: {e}")
        return {"type": "conversation", "response": "I encountered an error. Please try again."}
```

There is no separate `_call_llm_analysis` function. The single `_call_llm` handles both
JSON-parsed and free-text responses (free-text falls through the `JSONDecodeError` catch
and becomes `{"type": "conversation", "response": content}`).

## Foundation Model endpoint selection and testing

Preferred model: `databricks-claude-sonnet-5` (or the highest available non-deprecated
Claude Sonnet). Never default to Llama or Haiku for chat interfaces — they lack the
analytical depth users expect from a data assistant.

Endpoints deprecate without warning. Test at app startup or in deployment.
Test must verify both the status code AND the response content shape:

```python
resp = requests.post(
    f"{host}/serving-endpoints/{endpoint}/invocations",
    headers=headers,
    json={"messages": [{"role": "user", "content": "test"}], "max_tokens": 5},
    timeout=10,
)
if resp.status_code != 200:
    logger.error(f"Endpoint {endpoint} returned {resp.status_code}: {resp.text[:200]}")
else:
    # Verify response shape — Claude returns list, others return string
    content = resp.json()["choices"][0]["message"]["content"]
    if isinstance(content, list):
        logger.info(f"Endpoint {endpoint} returns content blocks (Claude format)")
    else:
        logger.info(f"Endpoint {endpoint} returns plain string")
```

Known model-specific constraints:
- Claude (all versions): does NOT support `temperature` parameter — omit entirely
- Claude Sonnet 5+, Opus 4+: returns content as list of typed blocks, not string
- Statement Execution API `wait_timeout`: must be 0 (disabled) or between 5s and 50s — values above 50s cause immediate 400

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

## Map loading state

Maps (dcc.Graph) must have an initial empty figure with dark background and
hidden axes to prevent a flash of default white axes while data loads:

```python
html.Div(
    dcc.Loading(
        dcc.Graph(
            id="fleet-map",
            config={"displayModeBar": False},
            figure={
                "data": [],
                "layout": {
                    "paper_bgcolor": COLORS["card"],
                    "plot_bgcolor": COLORS["card"],
                    "xaxis": {"visible": False},
                    "yaxis": {"visible": False},
                    "height": 620,
                },
            },
        ),
        type="dot",
        color=COLORS["accent"],
    ),
    style={**CARD_STYLE, "padding": "0", "overflow": "hidden"},
)
```

## Chat layout

Chat thread container must be capped at `maxWidth: 800px` with `margin: 0 auto`
for readability. Full-width chat is unreadable on wide screens.
Chat thread height should use `calc(100vh - 280px)` to fill available viewport.

## Forbidden

- Generating UPDATE/INSERT/DELETE from LLM chat output
- Showing fake progress steps that cannot advance in Dash's callback model
- Using `page_size` on DataTables (use scrolling)
- Raw f-string interpolation of user input into SQL
- Emojis or unicode symbols in any LLM system prompt
- Hardcoded serving endpoint names without startup validation
- `chat-store` as `Input` (not `State`) on tab-rendering callbacks
- Single-turn LLM calls without conversation history
- Returning bare SQL results without analysis
- Separate "JSON classifier" and "analyst" system prompts in the same pipeline
- A separate `_call_llm_analysis` function with its own system prompt
- Analysis prompts that are 90% formatting instructions and 10% analysis
- Conversation history that omits actual data rows ("returned N rows" instead of the data)
- Including `temperature` in Claude model requests
- Contradicting the system prompt's output format in any message (e.g. "Do not return JSON" when system says "Return strict JSON" — causes Claude to produce zero text blocks)
- Calling `.strip()` on LLM content without first checking if it is a list (Claude content blocks)
- Setting `wait_timeout` above 50s on Statement Execution API
- Map dcc.Graph without an initial empty dark figure (causes white axes flash)
