defmodule PlausibleWeb.DebugController do
  use PlausibleWeb, :controller
  use Plausible.IngestRepo
  use Plausible

  import Ecto.Query

  plug(PlausibleWeb.RequireAccountPlug)
  plug(PlausibleWeb.SuperAdminOnlyPlug)

  def clickhouse(conn, params) do
    user_id = Map.get(params, "user_id", conn.assigns.current_user.id)

    # Ensure last logs are flushed
    IngestRepo.query("SYSTEM FLUSH LOGS")

    queries =
      from(
        l in "query_log",
        prefix: "system",
        select: %{
          query: fragment("formatQuery(?)", l.query),
          log_comment: l.log_comment,
          type: l.type,
          event_time: l.event_time,
          query_duration_ms: l.query_duration_ms,
          query_id: l.query_id,
          memory_usage: fragment("formatReadableSize(?)", l.memory_usage),
          read_bytes: fragment("formatReadableSize(?)", l.read_bytes),
          result_bytes: fragment("formatReadableSize(?)", l.result_bytes),
          result_rows: l.result_rows
        },
        where:
          l.type > 1 and
            fragment("JSONExtractInt(?, \'user_id\') = ?", l.log_comment, ^user_id) and
            fragment("event_time > now() - toIntervalMinute(15)"),
        order_by: [desc: l.event_time]
      )
      |> IngestRepo.all()
      |> Enum.map(fn data ->
        Jason.decode!(data.log_comment)
        |> Map.merge(data)
        |> Map.delete(:log_comment)
      end)
      |> IO.inspect()

    conn
    |> render("clickhouse.html",
      queries: queries,
      user_id: user_id,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end
end
