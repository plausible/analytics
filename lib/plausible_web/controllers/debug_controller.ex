defmodule PlausibleWeb.DebugController do
  use PlausibleWeb, :controller
  use Plausible.IngestRepo
  use Plausible

  plug(PlausibleWeb.RequireAccountPlug)
  plug(PlausibleWeb.SuperAdminOnlyPlug)

  @columns [
    "query",
    "log_comment",
    "type",
    "event_time",
    "query_duration_ms",
    "query_id",
    "result_rows",
    "memory_usage",
    "read_bytes",
    "result_bytes"
  ]

  def clickhouse(conn, params) do
    user_id = Map.get(params, "user_id", conn.assigns.current_user.id)

    cluster? = Plausible.MigrationUtils.clustered_table?("events_v2")
    on_cluster = if(cluster?, do: "ON CLUSTER '{cluster}'", else: "")

    # Ensure last logs are flushed
    IngestRepo.query("SYSTEM FLUSH LOGS #{on_cluster}")

    table_expression =
      if(cluster?,
        do: "clusterAllReplicas('{cluster}', system.query_log)",
        else: "system.query_log"
      )

    %Ch.Result{rows: rows} =
      IngestRepo.query!(
        """
          SELECT
            formatQuery(query) AS query,
            log_comment,
            type,
            event_time,
            query_duration_ms,
            query_id,
            result_rows,
            formatReadableSize(memory_usage) AS memory_usage,
            formatReadableSize(read_bytes) AS read_bytes,
            formatReadableSize(result_bytes) AS result_bytes
          FROM #{table_expression}
          WHERE type > 1
            AND JSONExtractString(log_comment, 'user_id') = {$0:String}
            AND event_time > now() - toIntervalMinute(15)
          ORDER BY event_time DESC
        """,
        [user_id]
      )

    queries =
      rows
      |> Enum.map(fn row ->
        data = Enum.zip(@columns, row) |> Enum.into(%{})

        data
        |> Map.merge(Jason.decode!(data["log_comment"]))
        |> Map.delete("log_comment")
      end)

    conn
    |> render("clickhouse.html",
      queries: queries,
      user_id: user_id,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end
end
