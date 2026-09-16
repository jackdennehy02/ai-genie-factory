THEMING

All applications must use the centralised Snap Analytics brand tokens.
Never define per-app color palettes. Full Python dicts are in @ui-ux-patterns skill.

Brand: Snap Analytics
Design language: Minimal, high contrast, generous whitespace, rounded corners.
Default mode: snap-dark. Light variant: snap-light (for content-heavy views).

Primary accent: #E8871E (orange). Secondary: #4A90D9 (blue), #E84C88 (pink).
Dark background: #0D0D0D. Dark surface: #1A1A1A. Light background: #F0F0F0.
Chart palette order: orange, blue, pink, green, amber, purple, teal.
Font: Inter (system fallback). Headings 700, body 400 at 0.93rem.
Radius: cards 16px, buttons 8px, chat bubbles 18px, pills 24px.

Logo:
- Place logo.svg in /assets/ folder inside app directory
- Dash: html.Img(src=app.get_asset_url("logo.svg"), style={"height": "32px"})
- Header: top-left, max height 32px, vertically centred, alt text required

Rules:
- Default to snap-dark unless APP.md specifies snap-light
- Chart traces use CHART_PALETTE in order — never Plotly defaults
- Plotly template: plotly_dark (snap-dark) or plotly_white (snap-light)
- Plotly figure backgrounds must match COLORS["background"]
- Never invent colours outside the token set — use semantic names from @ui-ux-patterns
- Status colours (success/warning/danger/info) are functional — do not swap with brand colours
