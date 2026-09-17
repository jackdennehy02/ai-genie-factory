THEMING

All applications must use the centralised Snap Analytics brand tokens.
Never define per-app color palettes. Full Python dicts are in @ui-ux-patterns skill.

Brand: Snap Analytics
Design language: Minimal, high contrast, generous whitespace, rounded corners.
Default mode: snap-dark. Light variant: snap-light (for content-heavy views).

Primary accent: #4A90D9 (blue). Secondary: #E8871E (orange), #E84C88 (pink).
Dark background: #0D0D0D. Dark surface: #1A1A1A. Light background: #F0F0F0.
Chart palette order: blue, orange, pink, green, amber, purple, teal.
Font: Inter (system fallback). Headings 700, body 400 at 0.93rem.
Radius: cards 16px, buttons 8px, chat bubbles 18px, pills 24px.

Logo (brand/ folder in repo root):
- snap-dark: brand/logo-full-colour-whitetext.png (coloured icon + white text)
- snap-light: brand/logo-full-colour.png (coloured icon + black text)
- solid backgrounds: brand/logo-full-white.png (all-white)
Always use PNG — SVG files are large and slow to write to workspace assets.
SVG originals exist alongside each PNG for print/export use only.
Copy to app /assets/logo.png at build time (use shutil.copy2 or direct file copy, never editAsset for binary files).
Dash: html.Img(src="/assets/logo.png", alt="Snap Analytics", style={"height": "32px"})
Placement: top-left header, max 32px, alt="Snap Analytics"

Rules:
- Default to snap-dark unless APP.md specifies snap-light
- Chart traces use CHART_PALETTE in order — never Plotly defaults
- Plotly template: plotly_dark (snap-dark) or plotly_white (snap-light)
- Plotly figure backgrounds must match COLORS["background"]
- Never invent colours outside the token set — use semantic names from @ui-ux-patterns
- Status colours (success/warning/danger/info) are functional — do not swap with brand colours
