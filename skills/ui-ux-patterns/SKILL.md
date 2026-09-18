---
name: ui-ux-patterns
description: >
  Complete UX/UI design system + Plotly chart layer for all Databricks Apps at Alpura.
  Load when building, reviewing, or debugging any app UI — dashboards, ui.py, app.py,
  Plotly charts, KPI cards, filter panels, data tables, dark-theme layouts, or any
  visual component. Also @mention when the user asks about colors, theme, design tokens,
  chart styling, typography, shadows, layout order, or "making the app look right".
  Covers: dark and light color tokens, shadow/elevation system, typography scale, Plotly themes,
  KPI cards, app header, filter bar, chart patterns with hover templates, Dash and
  Streamlit full shell patterns, and number formatting utilities.
---

# UI/UX Patterns — Alpura Design System + Plotly Chart Layer

Apply to every `ui.py` and `app.py` file generated or reviewed.

---

## Theme contract

Every generated UI must support both `alpura-dark` and `alpura-light`. Use semantic token
names in components; never embed a mode-specific hex value in business UI code. The default
is `alpura-dark`, and the user may switch modes without changing chart meaning or data colors.

These tokens adhere to the **60-30-10 rule**:
- **60% Dominant (Neutral Backgrounds)**: `Background`, `Surface`, `Card`. Keeping borders matching widget backgrounds reduces visual clutter.
- **30% Secondary**: `Text primary`, `Text secondary`, and Chart Color Sequences.
- **10% Accent**: `Accent cyan` for interactive elements like filters, tabs, and buttons.

| Token | `alpura-dark` | `alpura-light` | Use |
|---|---:|---:|---|
| Background | `#080d14` | `#f4f7fb` | App canvas |
| Surface | `#0d1117` | `#ffffff` | Page and section areas |
| Card | `#111820` | `#ffffff` | Panels and chart containers |
| Card hover | `#161d27` | `#edf4fa` | Hover / active surface |
| Elevated | `#1a2332` | `#ffffff` | Dropdowns, modals, tooltips |
| Border subtle | `#1e2a3a` | `#d7e0ea` | Dividers |
| Border default | `#253040` | `#c2ceda` | Card and input edges |
| Border active | `#00bcd4` | `#007a8a` | Focused and selected elements |
| Text primary | `#e8edf4` | `#0d1b2a` | Headlines and KPI values |
| Text secondary | `#8b96a8` | `#40566f` | Labels, axes, subtitles |
| Text muted | `#657287` | `#61758a` | Placeholders and disabled text |
| Accent cyan | `#00bcd4` | `#007a8a` | Primary CTA, active state, links |
| Accent cyan dim | `#008fa3` | `#006675` | Accent hover |
| Accent purple | `#7c4dff` | `#5b32d6` | Secondary metrics |
| Positive | `#22c55e` | `#157a3d` | Positive deltas and success |
| Negative | `#f43f5e` | `#c32645` | Negative deltas and errors |
| Warning | `#f59e0b` | `#9a5b00` | Warnings |
| Alpura navy | `#003087` | `#003087` | Brand header/accent |

Normal text must meet WCAG AA contrast (4.5:1). Never communicate status by color alone:
pair positive/negative/warning colors with a label or icon. Focus rings must remain visible,
and motion must respect `prefers-reduced-motion`.

### CSS semantic tokens

```css
:root, [data-theme="alpura-light"] {
  --bg: #f4f7fb; --surface: #ffffff; --card: #ffffff; --card-hover: #edf4fa;
  --elevated: #ffffff; --border-subtle: #d7e0ea; --border: #c2ceda;
  --border-active: #007a8a; --text-primary: #0d1b2a; --text-secondary: #40566f;
  --text-muted: #61758a; --accent: #007a8a; --accent-hover: #006675;
  --purple: #5b32d6; --positive: #157a3d; --negative: #c32645; --warning: #9a5b00;
  color-scheme: light;
}

[data-theme="alpura-dark"] {
  --bg: #080d14; --surface: #0d1117; --card: #111820; --card-hover: #161d27;
  --elevated: #1a2332; --border-subtle: #1e2a3a; --border: #253040;
  --border-active: #00bcd4; --text-primary: #e8edf4; --text-secondary: #8b96a8;
  --text-muted: #657287; --accent: #00bcd4; --accent-hover: #008fa3;
  --purple: #7c4dff; --positive: #22c55e; --negative: #f43f5e; --warning: #f59e0b;
  color-scheme: dark;
}
```

---

## Shadow & Elevation System

Every surface has depth. Never use flat unshadowed cards.

```python
SHADOW = {
    "card":       "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.6)",
    "raised":     "0 4px 12px rgba(0,0,0,0.5), 0 8px 32px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.5)",
    "header":     "0 2px 0px rgba(0,188,212,0.15), 0 8px 32px rgba(0,48,135,0.4), 0 1px 0 rgba(0,188,212,0.2)",
    "kpi_active": "0 0 0 1px rgba(0,188,212,0.4), 0 4px 20px rgba(0,188,212,0.15), 0 8px 32px rgba(0,0,0,0.4)",
    "focus":      "0 0 0 3px rgba(0,188,212,0.12)",
}
```

---

## Typography Scale

Inter is for body text, and DM Sans for titles. Always load via Google Fonts or system fallback.

```python
TYPE = {
    "font":      "Inter, -apple-system, BlinkMacSystemFont, system-ui, sans-serif",
    "mono":      "'JetBrains Mono', 'Fira Code', monospace",
    # Sizes with weight + spacing
    "display":   {"fontFamily": "DM Sans, sans-serif", "fontSize": "22px", "fontWeight": "700", "letterSpacing": "-0.3px",  "lineHeight": "1.2"},
    "heading":   {"fontFamily": "DM Sans, sans-serif", "fontSize": "14px", "fontWeight": "600", "letterSpacing": "0.02em"},
    "kpi_value": {"fontSize": "36px", "fontWeight": "700", "letterSpacing": "-0.5px",  "lineHeight": "1"},
    "kpi_label": {"fontSize": "11px", "fontWeight": "500", "letterSpacing": "0.08em",  "textTransform": "uppercase"},
    "body":      {"fontSize": "13px", "fontWeight": "400", "lineHeight": "1.5"},
    "caption":   {"fontSize": "11px", "fontWeight": "400", "letterSpacing": "0.01em"},
}
```

---

## Plotly Theme — Apply to Every Figure

```python
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd

PLOTLY_THEME = {
    "dark": {"template": "plotly_dark", "card": "#111820", "text": "#8b96a8",
             "title": "#e8edf4", "muted": "#657287", "grid": "rgba(37,48,64,0.8)",
             "line": "rgba(37,48,64,0.6)", "tooltip": "#1a2332"},
    "light": {"template": "plotly_white", "card": "#ffffff", "text": "#40566f",
              "title": "#0d1b2a", "muted": "#61758a", "grid": "rgba(194,206,218,0.65)",
              "line": "rgba(194,206,218,0.9)", "tooltip": "#ffffff"},
}

def base_layout(mode: str = "dark") -> dict:
    t = PLOTLY_THEME[mode]
    return dict(
    template=t["template"],
    paper_bgcolor=t["card"],
    plot_bgcolor=t["card"],
    font=dict(family="Inter, -apple-system, system-ui, sans-serif", color=t["text"], size=11),
    title_font=dict(family="DM Sans, system-ui, sans-serif", size=13, color=t["title"]),
    margin=dict(l=48, r=24, t=44, b=44),
    xaxis=dict(gridcolor=t["grid"], linecolor=t["line"],
               tickfont=dict(size=10, color=t["muted"]), zeroline=False),
    yaxis=dict(gridcolor=t["grid"], linecolor=t["line"],
               tickfont=dict(size=10, color=t["muted"]), zeroline=False),
    legend=dict(bgcolor="rgba(0,0,0,0)", bordercolor=t["line"], borderwidth=1,
                font=dict(size=11, color=t["text"])),
    hoverlabel=dict(bgcolor=t["tooltip"], bordercolor="rgba(0,122,138,0.35)",
                    font=dict(family="Inter, system-ui", size=12, color=t["title"])),
    modebar=dict(bgcolor="rgba(0,0,0,0)", color=t["muted"], activecolor="#007a8a"),
    )

def apply_base_layout(fig, mode: str = "dark") -> go.Figure:
    fig.update_layout(**base_layout(mode))
    return fig
```

---

## Chart Color Sequences

```python
SEQ        = ["#00bcd4","#00a8c0","#0094a8","#008090","#006c78"]  # single metric — cyan ramp
CATEGORICAL = ["#00bcd4","#7c4dff","#22c55e","#f59e0b","#f43f5e"] # multi-series
DIVERGING   = ["#f43f5e","#f59e0b","#22c55e"]                      # neg → neutral → pos
BLUES       = ["#003087","#004db3","#0070e0","#00a8c0","#00bcd4"]  # Alpura brand ramp
EXTENDED_PALETTE = [
    "#00bcd4", "#00a8c0", "#0070e0", "#004db3", "#003087",         # Cyan to Navy
    "#4a148c", "#651fff", "#7c4dff", "#b388ff", "#e040fb"          # Deep purples to bright purples
] # Use for bar/line charts with many sections
FILL_CYAN   = "rgba(0,188,212,0.08)"   # area fill under line charts
FILL_PURPLE = "rgba(124,77,255,0.08)"
```

Never use default Plotly blue `#636efa`.

---

## Chart Type Rules

| Data shape | Chart | Key options |
|---|---|---|
| Trend over time | `px.line` | `fill="tozeroy"`, `FILL_CYAN` |
| Category comparison | `px.bar` horizontal | `orientation="h"`, sorted ascending |
| Part of whole | `px.treemap` | `color_continuous_scale=BLUES` |
| Distribution | `px.histogram` | `nbins=30`, cyan bars |
| Two metrics dual-axis | `make_subplots(secondary_y=True)` | shared x |
| Correlation / scatter | `px.scatter` | `opacity=0.75` |
| Heatmap | `go.Heatmap` | `colorscale=[[0,"#111820"],[1,"#00bcd4"]]` |

Never `px.pie`. Never 3D. Never vertical bars for labels > 8 chars.

---

## App Layout Order

Always this sequence — never reorder. Follow the **Z-pattern** layout logic, starting top-left with titles and filters, cutting diagonally down, and landing bottom-right on detailed visualizations and tables:

```
1. App header     — branded bar: Alpura navy bg, title, data source caption
2. Filter bar     — horizontal row, card surface, date range + dropdowns
3. KPI row        — 3–4 metric cards, equal-width flex, full page width
4. Chart row(s)   — max 2 charts per row, equal flex, card surface
5. Data table     — optional, always last, full width
```

Spacing: `24px` page padding · `12px` gap between cards · `20px` inner card padding.

---

## KPI Card

```python
def kpi_card(label: str, value: str, delta: str = None, positive: bool = True) -> html.Div:
    delta_color  = "#22c55e" if positive else "#f43f5e"
    delta_bg     = "rgba(34,197,94,0.08)" if positive else "rgba(244,63,94,0.08)"
    delta_symbol = "▲" if positive else "▼"
    children = [
        html.Div(label, style={
            "color": "#8b96a8", "fontSize": "11px", "fontWeight": "500",
            "letterSpacing": "0.08em", "textTransform": "uppercase", "marginBottom": "10px",
        }),
        html.Div(value, style={
            "color": "#e8edf4", "fontSize": "36px", "fontWeight": "700",
            "letterSpacing": "-0.5px", "lineHeight": "1", "fontFamily": "Inter, system-ui, sans-serif",
        }),
    ]
    if delta:
        children.append(html.Div([
            html.Span(delta_symbol + " ", style={"fontSize": "10px"}),
            html.Span(delta),
        ], style={
            "color": delta_color, "background": delta_bg, "fontSize": "11px",
            "fontWeight": "500", "marginTop": "10px", "padding": "3px 8px",
            "borderRadius": "4px", "display": "inline-block",
        }))
    return html.Div(children, style={
        "background":   "linear-gradient(145deg, #111820 0%, #0f1a26 100%)",
        "border":       "1px solid #253040",
        "borderRadius": "10px",
        "padding":      "20px",
        "flex":         "1",
        "boxShadow":    "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3), 0 0 0 1px rgba(37,48,64,0.6)",
        "transition":   "box-shadow 0.2s ease, border-color 0.2s ease",
        "fontFamily":   "Inter, system-ui, sans-serif",
    })
```

---

## App Header

```python
def app_header(title: str, subtitle: str) -> html.Div:
    return html.Div([
        html.Div(style={
            "width": "3px", "height": "32px",
            "background": "linear-gradient(180deg, #00bcd4 0%, #003087 100%)",
            "borderRadius": "2px", "marginRight": "14px", "flexShrink": "0",
        }),
        html.Div([
            html.Div(title, style={
                "color": "#e8edf4", "fontSize": "18px", "fontWeight": "700",
                "letterSpacing": "-0.2px", "lineHeight": "1.2", "fontFamily": "Inter, system-ui, sans-serif",
            }),
            html.Div(subtitle, style={
                "color": "#8b96a8", "fontSize": "11px", "marginTop": "2px", "letterSpacing": "0.01em",
            }),
        ]),
    ], style={
        "display": "flex", "alignItems": "center",
        "padding": "16px 24px",
        "background":   "linear-gradient(135deg, #0a1628 0%, #0d1117 60%, #080d14 100%)",
        "borderBottom": "1px solid #1e2a3a",
        "boxShadow":    "0 2px 0px rgba(0,188,212,0.15), 0 8px 32px rgba(0,48,135,0.4), 0 1px 0 rgba(0,188,212,0.2)",
        "marginBottom": "24px",
    })
```

---

## Reusable Style Dicts

```python
FILTER_BAR_STYLE = {
    "display": "flex", "gap": "16px", "alignItems": "flex-end",
    "padding": "14px 20px",
    "background":   "linear-gradient(135deg, #111820 0%, #0f1822 100%)",
    "border":       "1px solid #1e2a3a",
    "borderRadius": "10px",
    "boxShadow":    "0 4px 12px rgba(0,0,0,0.4), 0 1px 0 rgba(37,48,64,0.5)",
    "marginBottom": "20px",
}

CARD_STYLE = {
    "background":   "linear-gradient(145deg, #111820 0%, #0f1a26 100%)",
    "border":       "1px solid #253040",
    "borderRadius": "10px",
    "padding":      "20px",
    "boxShadow":    "0 1px 3px rgba(0,0,0,0.4), 0 4px 16px rgba(0,0,0,0.3)",
    "flex":         "1",
}

CHART_CARD_STYLE = {**CARD_STYLE, "padding": "16px", "transition": "box-shadow 0.2s ease"}
```

---

## Number Formatting

```python
def fmt_number(n: float) -> str:
    if n is None: return "—"
    if n >= 1_000_000_000: return f"{n/1_000_000_000:.1f}B"
    if n >= 1_000_000:     return f"{n/1_000_000:.1f}M"
    if n >= 1_000:         return f"{n/1_000:.1f}K"
    return f"{n:,.0f}"

def fmt_currency(n: float) -> str: return f"${fmt_number(n)}"
def fmt_pct(n: float) -> str:      return f"{n:.1f}%"

def fmt_delta(current: float, previous: float) -> tuple[str, bool]:
    if previous == 0: return "N/A", True
    pct = ((current - previous) / previous) * 100
    sign = "▲" if pct >= 0 else "▼"
    return f"{sign} {abs(pct):.1f}% vs prior period", pct >= 0
```

---

## Chart Functions

All chart functions: accept `pd.DataFrame`, return `go.Figure`. `toPandas()` conversion always happens in the caller — never inside these functions.

### Trend Line

```python
def build_trend_chart(df: pd.DataFrame, x: str, y: str, title: str) -> go.Figure:
    try:
        fig = px.line(df, x=x, y=y, title=title, color_discrete_sequence=SEQ)
        fig.update_traces(
            line=dict(width=2, color="#00bcd4"),
            fill="tozeroy", fillcolor=FILL_CYAN, mode="lines",
            hovertemplate=f"<b>%{{x}}</b><br>{y}: <b>%{{y:,.0f}}</b><extra></extra>",
        )
        fig.update_layout(hovermode="x unified")
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_trend_chart failed: {e}")
        return _error_figure(str(e))
```

### Horizontal Bar

```python
def build_category_chart(df: pd.DataFrame, x: str, y: str, title: str) -> go.Figure:
    try:
        df_sorted = df.sort_values(x, ascending=True)
        fig = px.bar(df_sorted, x=x, y=y, orientation="h", title=title, color_discrete_sequence=SEQ)
        fig.update_traces(
            marker=dict(color="#00bcd4", opacity=0.85, line=dict(width=0)),
            hovertemplate=f"<b>%{{y}}</b><br>{x}: <b>%{{x:,.0f}}</b><extra></extra>",
        )
        fig.update_layout(yaxis=dict(categoryorder="total ascending"), bargap=0.35)
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_category_chart failed: {e}")
        return _error_figure(str(e))
```

### Dual-Axis (Two Metrics)

```python
def build_dual_axis_chart(df: pd.DataFrame, x: str, y1: str, y2: str,
                           label1: str, label2: str, title: str) -> go.Figure:
    try:
        fig = make_subplots(specs=[[{"secondary_y": True}]])
        fig.add_trace(go.Scatter(
            x=df[x], y=df[y1], name=label1,
            line=dict(color="#00bcd4", width=2), fill="tozeroy", fillcolor=FILL_CYAN,
            hovertemplate=f"<b>%{{x}}</b><br>{label1}: <b>%{{y:,.0f}}</b><extra></extra>",
        ), secondary_y=False)
        fig.add_trace(go.Scatter(
            x=df[x], y=df[y2], name=label2,
            line=dict(color="#7c4dff", width=2), fill="tozeroy", fillcolor=FILL_PURPLE,
            hovertemplate=f"<b>%{{x}}</b><br>{label2}: <b>%{{y:,.0f}}</b><extra></extra>",
        ), secondary_y=True)
        fig.update_layout(
            title_text=title, hovermode="x unified",
            yaxis=dict(title=label1,  titlefont=dict(color="#00bcd4", size=11)),
            yaxis2=dict(title=label2, titlefont=dict(color="#7c4dff", size=11)),
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_dual_axis_chart failed: {e}")
        return _error_figure(str(e))
```

### Treemap (Part of Whole)

```python
def build_treemap(df: pd.DataFrame, path: list[str], values: str, title: str) -> go.Figure:
    try:
        fig = px.treemap(df, path=path, values=values, title=title,
                         color=values,
                         color_continuous_scale=[[0,"#0d1117"],[0.3,"#003087"],[0.7,"#0070e0"],[1.0,"#00bcd4"]])
        fig.update_traces(
            marker=dict(cornerradius=4, line=dict(width=1.5, color="#080d14")),
            hovertemplate="<b>%{label}</b><br>%{value:,.0f}<extra></extra>",
            textfont=dict(family="Inter, system-ui", size=12, color="#e8edf4"),
        )
        fig.update_layout(margin=dict(l=0, r=0, t=40, b=0))
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_treemap failed: {e}")
        return _error_figure(str(e))
```

### Histogram

```python
def build_histogram(df: pd.DataFrame, x: str, title: str, nbins: int = 30) -> go.Figure:
    try:
        fig = px.histogram(df, x=x, nbins=nbins, title=title, color_discrete_sequence=SEQ)
        fig.update_traces(
            marker=dict(color="#00bcd4", opacity=0.8, line=dict(width=0)),
            hovertemplate=f"Range: <b>%{{x}}</b><br>Count: <b>%{{y}}</b><extra></extra>",
        )
        fig.update_layout(bargap=0.05)
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_histogram failed: {e}")
        return _error_figure(str(e))
```

### Scatter

```python
def build_scatter(df: pd.DataFrame, x: str, y: str, size: str = None,
                  color: str = None, title: str = "") -> go.Figure:
    try:
        fig = px.scatter(df, x=x, y=y, size=size, color=color, title=title,
                         color_discrete_sequence=CATEGORICAL, opacity=0.75)
        fig.update_traces(
            marker=dict(line=dict(width=0.5, color="rgba(0,0,0,0.3)")),
            hovertemplate=f"<b>{x}:</b> %{{x:,.2f}}<br><b>{y}:</b> %{{y:,.2f}}<extra></extra>",
        )
        return apply_base_layout(fig)
    except Exception as e:
        logger.error(f"build_scatter failed: {e}")
        return _error_figure(str(e))
```

### Error Figure

```python
def _error_figure(message: str) -> go.Figure:
    fig = go.Figure()
    fig.add_annotation(text="⚠ Chart unavailable", showarrow=False,
                       font=dict(color="#f43f5e", size=14, family="Inter, system-ui"),
                       xref="paper", yref="paper", x=0.5, y=0.55)
    fig.add_annotation(text=message, showarrow=False,
                       font=dict(color="#4a5568", size=11, family="Inter, system-ui"),
                       xref="paper", yref="paper", x=0.5, y=0.42)
    return apply_base_layout(fig)
```

---

## Pandas Rule

Databricks Apps have no Spark session — `data.py` returns `pandas.DataFrame` directly.
All chart functions accept `pd.DataFrame`. No `.toPandas()` conversion needed or allowed.

```python
# CORRECT: data.py already returns pandas
df = load_table(catalog, schema, table)          # returns pd.DataFrame
fig = build_trend_chart(df, x="date", y="amount", title="Trend")

# WRONG: no Spark in Apps
return df.groupBy(...).agg(...).toPandas()       # AttributeError — no Spark
```

---

## Hover Template Quick Reference

```python
hovertemplate="<b>%{x}</b><br>Revenue: <b>$%{y:,.0f}</b><extra></extra>"   # currency
hovertemplate="<b>%{x}</b><br>Rate: <b>%{y:.1f}%</b><extra></extra>"       # percentage
hovertemplate="<b>%{label}</b><br>Count: <b>%{value:,}</b><extra></extra>"  # treemap
```

Always `<extra></extra>` to suppress trace name box. Always `<b>` the value.

---

## Chart Type Selection

| User asks for | Function | Never |
|---|---|---|
| Trend, over time, history | `build_trend_chart` | `px.bar` for time |
| Compare, ranking, top N | `build_category_chart` | Vertical bars for long labels |
| Share, breakdown, composition | `build_treemap` | `px.pie` anywhere |
| Distribution, spread | `build_histogram` | — |
| Two metrics over time | `build_dual_axis_chart` | Two separate charts |
| Correlation, two continuous vars | `build_scatter` | — |

---

## Plotly Layout Rules

`base_layout()` returns a **plain dict** — never a `go.Figure` or `go.Layout` object.
Always use `fig.update_layout(**base_layout(mode))` to apply the theme.

**Never** create a temporary `go.Figure()` and unpack its `.layout` property:
```python
# WRONG — .layout is a Layout object, not a dict; ** unpacking throws TypeError
fig.update_layout(**_base_figure("Title").layout)

# WRONG — duplicate keyword when overriding a key already in base_layout
fig.update_layout(**base_layout(mode), margin={"l": 8, "r": 8, "t": 48, "b": 8})

# CORRECT — always unpack a dict
fig.update_layout(**base_layout(mode))

# CORRECT — override a key by mutating the dict first
layout = base_layout(mode)
layout["margin"] = {"l": 8, "r": 8, "t": 48, "b": 8}
fig.update_layout(**layout)
```

---

## Forbidden

- Hardcoded mode-specific colors inside components; consume semantic tokens instead
- Shipping only one color mode; every UI must support `alpura-dark` and `alpura-light`
- `px.pie` — always `px.treemap`
- Default Plotly blue `#636efa` — always `#00bcd4`
- Flat unshadowed cards — every surface must have `boxShadow`
- Per-app invented colors outside the token set
- `.toPandas()` — Apps use pandas throughout; `data.py` returns pandas already
- `font-family` other than Inter or the mono fallback
- Vertical bar charts for category labels > 8 characters
- Hovertemplates left as Plotly default — always set explicitly
- `**figure.layout` unpacking — `.layout` is a `go.Layout` object, not a dict; use `**base_layout()` instead
- Passing duplicate keyword arguments to `update_layout()` (e.g. `margin` in both `**base_layout()` and as a kwarg) — mutate the dict first
- `import dash_table` — use `from dash import dash_table` (the standalone import is deprecated)

---

## Dash App Shell

### Imports

```python
import dash
from dash import html, dcc, Input, Output, dash_table
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger
from data import load_<entity>
from logic import transform_<entity>
from ui import kpi_card, app_header, apply_base_layout, fmt_number, fmt_currency, fmt_delta
from ui import CARD_STYLE, CHART_CARD_STYLE, FILTER_BAR_STYLE
from ui import build_trend_chart, build_category_chart, _error_figure

logger = get_logger(__name__)
```

### CSS Variables Injection

```python
app = dash.Dash(__name__, title="App Name — Alpura", suppress_callback_exceptions=True)
CONFIG = {"catalog": "prod", "schema": "gold", "table": "your_table_name"}

app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
        <style>
            @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");
            :root {
                --bg-deep:         #080d14;
                --bg-surface:      #0d1117;
                --bg-card:         #111820;
                --bg-elevated:     #1a2332;
                --border-subtle:   #1e2a3a;
                --border:          #253040;
                --border-active:   #00bcd4;
                --text-primary:    #e8edf4;
                --text-secondary:  #8b96a8;
                --text-muted:      #4a5568;
                --accent-cyan:     #00bcd4;
                --accent-purple:   #7c4dff;
                --positive:        #22c55e;
                --negative:        #f43f5e;
                --warning:         #f59e0b;
                --alpura-navy:     #003087;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                background: var(--bg-deep);
                color: var(--text-primary);
                font-family: Inter, -apple-system, system-ui, sans-serif;
                font-size: 13px;
                line-height: 1.5;
                -webkit-font-smoothing: antialiased;
            }
            ::-webkit-scrollbar { width: 6px; height: 6px; }
            ::-webkit-scrollbar-track { background: var(--bg-surface); }
            ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
            .Select-control { background: var(--bg-elevated) !important; border-color: var(--border) !important; border-radius: 6px !important; }
            .Select-menu-outer { background: var(--bg-elevated) !important; border-color: var(--border) !important; box-shadow: 0 8px 32px rgba(0,0,0,.5) !important; }
            .Select-option:hover { background: rgba(0,188,212,0.08) !important; }
            input[type="text"], input[type="date"] { background: var(--bg-elevated) !important; border: 1px solid var(--border) !important; color: var(--text-primary) !important; border-radius: 6px !important; padding: 6px 10px !important; }
            input:focus, .Select-control:focus-within { border-color: var(--border-active) !important; box-shadow: 0 0 0 3px rgba(0,188,212,0.12) !important; outline: none; }
        </style>
    </head>
    <body>{%app_entry%}<footer>{%config%}{%scripts%}{%renderer%}</footer></body>
</html>
'''
```

### Full Layout

```python
app.layout = html.Div([
    app_header("App Title", "Powered by prod.gold.table_name"),
    html.Div([
        html.Div([date_filter("main")], style=FILTER_BAR_STYLE),
        html.Div(id="kpi-row", style={"display":"flex","gap":"12px","marginBottom":"20px"}),
        html.Div([
            html.Div(dcc.Graph(id="chart-1", config={"displayModeBar":False}), style=CHART_CARD_STYLE),
            html.Div(dcc.Graph(id="chart-2", config={"displayModeBar":False}), style=CHART_CARD_STYLE),
        ], style={"display":"flex","gap":"12px","marginBottom":"20px"}),
        html.Div(id="data-table-container", style=CARD_STYLE),
    ], style={"padding":"0 24px 24px 24px"}),
], style={"background":"#080d14","minHeight":"100vh"})
```

### Callback Pattern

```python
@app.callback(
    Output("kpi-row","children"), Output("chart-1","figure"),
    Output("chart-2","figure"),   Output("data-table-container","children"),
    Input("main-date-range","start_date"), Input("main-date-range","end_date"),
)
def update_dashboard(start_date, end_date):
    try:
        df_raw    = load_entity(CONFIG)
        df_kpis   = compute_kpis(df_raw, start_date, end_date)
        df_trend  = compute_trend(df_raw, start_date, end_date)
        df_by_cat = compute_by_category(df_raw, start_date, end_date)
        delta_txt, is_pos = fmt_delta(df_kpis["revenue"], df_kpis["revenue_prior"])
        kpis = [
            kpi_card("Total Revenue", fmt_currency(df_kpis["revenue"]), delta_txt, is_pos),
            kpi_card("Orders",        fmt_number(df_kpis["orders"]),    "▲ 3.2% vs prior", True),
        ]
        return (kpis,
                build_trend_chart(df_trend,    "date",     "amount",   "Revenue Trend"),
                build_category_chart(df_by_cat, "amount",   "category", "By Category"),
                data_table(df_by_cat, "main-table"))
    except Exception as e:
        logger.error(f"Dashboard update failed: {e}")
        err = _error_figure(str(e))
        return [], err, err, html.Div(f"Data unavailable — {e}",
                                      style={"color":"#f43f5e","padding":"16px","fontSize":"13px"})

if __name__ == "__main__":
    app.run(debug=False)
```

---

## Streamlit App Shell

### CSS Injection

```python
st.markdown("""
<style>
    @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap");
    html, body, .stApp, [data-testid="stAppViewContainer"] {
        background: #080d14 !important;
        font-family: Inter, system-ui, sans-serif !important;
        -webkit-font-smoothing: antialiased;
    }
    [data-testid="stSidebar"] { background: #0d1117 !important; border-right: 1px solid #253040 !important; }
    h1 { color: #e8edf4 !important; font-size: 20px !important; font-weight: 700 !important; letter-spacing: -0.3px !important; }
    h2, h3 { color: #e8edf4 !important; font-weight: 600 !important; }
    p, label, .stMarkdown { color: #8b96a8 !important; font-size: 13px !important; }
    .stMetric { background: #111820; border: 1px solid #253040; border-radius: 10px; padding: 16px;
                box-shadow: 0 1px 3px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.3); }
    .stMetric label { color: #8b96a8 !important; font-size: 11px !important; text-transform: uppercase; letter-spacing: 0.06em; }
    .stMetric [data-testid="metric-container"] > div:nth-child(2) { color: #e8edf4 !important; font-size: 32px !important; font-weight: 700 !important; }
    .stDataFrame, .stTable { background: #111820 !important; border: 1px solid #253040 !important; border-radius: 10px !important; }
    .stSelectbox > div > div, .stDateInput > div > div { background: #1a2332 !important; border-color: #253040 !important; border-radius: 6px !important; }
    ::-webkit-scrollbar { width: 5px; } ::-webkit-scrollbar-thumb { background: #253040; border-radius: 3px; }
</style>
""", unsafe_allow_html=True)
```

### Full App Structure (Streamlit)

```python
import streamlit as st
from datetime import datetime, timedelta
import pandas as pd
from _logger import get_logger
from data import load_entity
from logic import compute_kpis, compute_trend, compute_by_category
from ui import fmt_currency, fmt_number, fmt_delta
from ui import build_trend_chart, build_category_chart

logger = get_logger(__name__)
st.set_page_config(page_title="App Name — Alpura", layout="wide", initial_sidebar_state="expanded")

# Inject CSS (full block above)
st.markdown("""<style>...</style>""", unsafe_allow_html=True)

# Header
st.markdown("""
<div style="display:flex;align-items:center;padding:0 0 20px;border-bottom:1px solid #1e2a3a;margin-bottom:24px">
    <div style="width:3px;height:28px;background:linear-gradient(180deg,#00bcd4,#003087);border-radius:2px;margin-right:12px"></div>
    <div>
        <div style="font-size:18px;font-weight:700;color:#e8edf4;letter-spacing:-0.2px">App Name</div>
        <div style="font-size:11px;color:#8b96a8;margin-top:2px">Powered by prod.gold.table_name</div>
    </div>
</div>
""", unsafe_allow_html=True)

# Filters
with st.sidebar:
    st.markdown("<p style='font-size:11px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:#8b96a8;padding:12px 0 8px'>Filters</p>", unsafe_allow_html=True)
    date_range = st.date_input("Date Range", value=(datetime.today().date() - timedelta(30), datetime.today().date()))

# Load
try:
    df_raw    = load_entity()
    df_kpis   = compute_kpis(df_raw, *date_range)
    df_trend  = compute_trend(df_raw, *date_range)
    df_by_cat = compute_by_category(df_raw, *date_range)
except Exception as e:
    logger.error(f"Load failed: {e}")
    st.error(f"Data unavailable: {e}")
    st.stop()

# KPI row
delta_txt, is_pos = fmt_delta(df_kpis["revenue"], df_kpis["revenue_prior"])
cols = st.columns(3)
with cols[0]: st.metric("Total Revenue", fmt_currency(df_kpis["revenue"]), delta_txt)
with cols[1]: st.metric("Orders",        fmt_number(df_kpis["orders"]),    "+3.2%")
with cols[2]: st.metric("Avg Order",     fmt_currency(df_kpis["avg_order"]))

# Charts
col1, col2 = st.columns(2)
with col1: st.plotly_chart(build_trend_chart(df_trend,    "date",     "amount",   "Revenue Trend"),    use_container_width=True, config={"displayModeBar":False})
with col2: st.plotly_chart(build_category_chart(df_by_cat,"amount",   "category", "By Category"),      use_container_width=True, config={"displayModeBar":False})

# Table
st.markdown("<div style='margin-top:8px'></div>", unsafe_allow_html=True)
st.dataframe(df_by_cat, use_container_width=True, hide_index=True)
```
