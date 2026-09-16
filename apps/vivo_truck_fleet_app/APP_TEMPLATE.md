APP NAME: [Vivid Truck Fleet App]

Objective:

I want a truck fleet tracking app that allows operational business users to view key metrics/locatios of trucks. I want users to be able to update the status of trips and be able to chat to an AI chatbot to query the truck data with natural language and obtain agentic analysis.

Data:
- The underlying table is developers.truck_fleet_demo.dev_jack_dennehy_raw_shipments 


Schema notes:
  shipment_id STRING COLLATE UTF8_BINARY NOT NULL COMMENT 'Primary key - unique shipment identifier',
  truck_id STRING COLLATE UTF8_BINARY NOT NULL COMMENT 'Truck identifier (TRK-001 to TRK-020)',
  origin STRING COLLATE UTF8_BINARY NOT NULL COMMENT 'Origin city of the shipment',
  destination STRING COLLATE UTF8_BINARY NOT NULL COMMENT 'Destination city of the shipment',
  status STRING COLLATE UTF8_BINARY NOT NULL COMMENT 'Current shipment status: In Transit, Delayed, Delivered, Cancelled',
  scheduled_arrival TIMESTAMP COMMENT 'Scheduled arrival date and time',
  actual_arrival TIMESTAMP COMMENT 'Actual arrival date and time (NULL if not yet arrived)',
  delay_reason STRING COLLATE UTF8_BINARY COMMENT 'Reason for delay (NULL unless status is Delayed)',
  distance_km DOUBLE COMMENT 'Route distance in kilometers',
  estimated_hours DOUBLE COMMENT 'Estimated travel time in hours',
  weight_kg DOUBLE COMMENT 'Cargo weight in kilograms',
  created_at TIMESTAMP NOT NULL COMMENT 'Timestamp when shipment record was created',
  updated_at TIMESTAMP NOT NULL COMMENT 'Timestamp when shipment record was last updated' 

KPIs / Metrics:
[For each metric displayed in the app:]
    - Total shipments (count of rows)
    - Total trucks (distinct truck_id)
    - Total distance (km) (sum of distance km)
    - Avg weight (kg) (mean of weight_kg)
    - Delayed (count of rows where status = 'Delayed')
[If a metric exists in the semantic layer, reference it by name — do NOT recalculate it]


UI Components:
[List every visual component in render order:]
- [KPI cards for all KPIs]
- [A map with truck locations]
- [Table: show all columns from underlying data]
[If chart type not specified here, Genie Code will choose the most appropriate Plotly chart]

Filters:
Ensure filters work in combination - filtering by truck should narrow the scope of Shipment IDs and vice versa.
- [Filter 1  Truck]
- [Filter 2: Shipment Id]


Design:
- Page background: #FFFFFF
- Surface/separation: #F5F5F5 (chat bubbles, card backgrounds, table headers)
- Primary accent: #0B5D2E (headings, active tab, column headers)
- Interactive accent: #00BF40 (metric numbers, buttons, active filters)
- Body text: #1A1A1A
- Secondary text: #5A5A5A (labels, captions)
- Secondary fill: #9ECDE2 (map markers, selected chips)
- Borders: #E0E0E0
- Tabs for each section: KPI/Map/ Truck status writeback (underneath map) and a tab for the AI chat.

Constraints:

LLM Chatbot:
- Serving endpoint:
- Authenticate with WorkspaceClient from the databricks-sdk — it handles auth internally. Do not hand-roll auth by pulling a token and passing it to the openai client with a manually built base_url (that produced an empty key and connection error)
- Do not pass plain dicts as messages to w.serving_endpoints.query() — fails with "'dict' object has no attribute 'as_dict'". Either build SDK ChatMessage objects, or POST to /serving-endpoints/<endpoint>/invocations with raw JSON
- Surface actual error text in the app if the endpoint call fails
- Ensure the endpoint is not deprecated by testing the API - use at least Claude Sonnet 4.8 or above.
SQL generation guardrails:
- Give the LLM the full table schema (columns, types, descriptions) as fixed context — constrain it to only reference columns that exist
- Enforce SELECT-only in code: reject any statement containing UPDATE, DELETE, INSERT, DROP, ALTER, TRUNCATE, MERGE, or CREATE
- When a user says "today" or "this week", resolve against the current date and check the timezone of timestamp columns — do not assume UTC
- When a user names a shipment or truck (e.g. "shipment 002"), resolve against actual distinct IDs in the table (which may be zero-padded/prefixed like SHP-000002, TRK-005) rather than using the raw string in a WHERE clause
- Cap rows returned to the LLM and note in the chat if results were truncated
- If generated SQL fails to execute, show the actual error and let the user retry — never silently retry or fabricate
Map:
Hardcode city coordinates


  

