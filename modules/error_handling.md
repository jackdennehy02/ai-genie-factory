ERROR HANDLING

All applications must handle errors at layer boundaries and surface them clearly.

Rules:
- Wrap all data access calls in try/except in the data layer (spark.table() in Notebooks; WorkspaceClient in Apps)
- Wrap all aggregation logic in try/except in the logic layer
- Never let raw tracebacks reach the UI — display user-friendly messages
- Always catch Exception as e — never use bare except:
- Define DataAccessError and LogicError as custom exceptions in data.py

Custom exceptions (define at top of data.py):
class DataAccessError(Exception):
    pass

class LogicError(Exception):
    pass

Data layer pattern (Notebooks — spark.table()):
try:
    df = spark.table("catalog.schema.table")
except Exception as e:
    raise DataAccessError(f"Table unavailable: catalog.schema.table") from e

Data layer pattern (Databricks Apps — WorkspaceClient, NO spark):
try:
    w = WorkspaceClient()
    result = w.statement_execution.execute_statement(
        warehouse_id=warehouse_id,
        statement="SELECT * FROM catalog.schema.table",
        wait_timeout="30s",
    )
    if result.status.state.value != "SUCCEEDED":
        raise DataAccessError(f"Query failed: {result.status.error.message}")
    cols = [c.name for c in result.manifest.schema.columns]
    df = pd.DataFrame(result.result.data_array or [], columns=cols)
except DataAccessError:
    raise
except Exception as e:
    raise DataAccessError(f"Table unavailable: catalog.schema.table") from e

Logic layer pattern:
try:
    result = df.groupBy("date").agg(sum("value").alias("total"))
except Exception as e:
    raise LogicError(f"Transformation failed: {str(e)}") from e

UI layer pattern (Databricks Apps / Dash):
try:
    fig = build_chart(df_pandas)
except Exception as e:
    fig = go.Figure()
    fig.add_annotation(text=f"Error: {str(e)}", showarrow=False, font_size=14)
