defmodule PlausibleWeb.DebugController do
  use PlausibleWeb, :controller
  use Plausible.IngestRepo
  use Plausible

  import Ecto.Query

  plug(PlausibleWeb.RequireAccountPlug)
  plug(PlausibleWeb.SuperAdminOnlyPlug)

  def clickhouse(conn, params) do
    cluster? = Plausible.IngestRepo.clustered_table?("events_v2")
    on_cluster = if(cluster?, do: "ON CLUSTER '{cluster}'", else: "")

    # Ensure last logs are flushed
    IngestRepo.query("SYSTEM FLUSH LOGS #{on_cluster}")

    queries =
      from(
        l in from_query_log(cluster?),
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
        where: l.type > 1 and fragment("event_time > now() - toIntervalMinute(15)"),
        order_by: [desc: l.event_time]
      )
      |> filter_by_params(conn, params)
      |> IngestRepo.all()
      |> Enum.map(fn data ->
        Jason.decode!(data.log_comment)
        |> Map.merge(data)
        |> Map.delete(:log_comment)
      end)

    conn
    |> render("clickhouse.html",
      queries: queries
    )
  end

  defp from_query_log(cluster?) do
    case cluster? do
      true -> from(l in fragment("clusterAllReplicas('{cluster}', system.query_log)"))
      false -> from(l in fragment("system.query_log"))
    end
  end

  defp filter_by_params(q, _conn, %{"user_id" => user_id}),
    do: where(q, [l], fragment("JSONExtractInt(?, \'user_id\') = ?", l.log_comment, ^user_id))

  defp filter_by_params(q, _conn, %{"site_id" => site_id}),
    do: where(q, [l], fragment("JSONExtractInt(?, \'site_id\') = ?", l.log_comment, ^site_id))

  defp filter_by_params(q, _conn, %{"site_domain" => site_domain}),
    do:
      where(
        q,
        [l],
        fragment("JSONExtractInt(?, \'site_domain\') = ?", l.log_comment, ^site_domain)
      )

  defp filter_by_params(q, conn, _),
    do: filter_by_params(q, conn, %{"user_id" => conn.assigns.current_user.id})
end
