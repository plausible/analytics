defimpl FunWithFlags.Actor, for: BitString do
  def id(str) do
    str
  end
end

defmodule PlausibleWeb.Api.ExternalController do
  use PlausibleWeb, :controller
  require Logger

  alias Plausible.Ingestion

  def event(conn, _params) do
    with {:ok, request} <- Ingestion.Request.build(conn),
         _ <- Sentry.Context.set_extra_context(%{request: request}) do
      case Ingestion.Event.build_and_buffer(request) do
        {:ok, %{dropped: [], buffered: _buffered}} ->
          conn
          |> put_status(202)
          |> text("ok")

        {:ok, %{dropped: dropped, buffered: _}} ->
          first_invalid_changeset = find_first_invalid_changeset(dropped)

          if first_invalid_changeset do
            conn
            |> put_resp_header("x-plausible-dropped", "#{Enum.count(dropped)}")
            |> put_status(400)
            |> json(%{
              errors: Plausible.ChangesetHelpers.traverse_errors(first_invalid_changeset)
            })
          else
            conn
            |> put_resp_header("x-plausible-dropped", "#{Enum.count(dropped)}")
            |> put_status(202)
            |> text("ok")
          end
      end
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(400)
        |> json(%{errors: Plausible.ChangesetHelpers.traverse_errors(changeset)})
    end
  end

  def error(conn, _params) do
    Sentry.capture_message("JS snippet error")
    send_resp(conn, 200, "")
  end

  def health(conn, _params) do
    postgres_health =
      case Ecto.Adapters.SQL.query(Plausible.Repo, "SELECT 1", []) do
        {:ok, _} -> "ok"
        e -> "error: #{inspect(e)}"
      end

    clickhouse_health =
      case Ecto.Adapters.SQL.query(Plausible.ClickhouseRepo, "SELECT 1", []) do
        {:ok, _} -> "ok"
        e -> "error: #{inspect(e)}"
      end

    cache_health =
      if postgres_health == "ok" and Plausible.Site.Cache.ready?() and
           Plausible.Shield.IPRuleCache.ready?() do
        "ok"
      end

    status =
      case {postgres_health, clickhouse_health, cache_health} do
        {"ok", "ok", "ok"} -> 200
        _ -> 500
      end

    put_status(conn, status)
    |> json(%{
      postgres: postgres_health,
      clickhouse: clickhouse_health,
      sites_cache: cache_health
    })
  end

  def info(conn, _params) do
    build =
      :plausible
      |> Application.get_env(:runtime_metadata)
      |> Keyword.take([:version, :commit, :created, :tags])
      |> Map.new()

    geo_database = Plausible.Geo.database_type() || "(not configured)"

    json(conn, %{
      geo_database: geo_database,
      build: build
    })
  end

  defp find_first_invalid_changeset(dropped) do
    Enum.find_value(dropped, nil, fn dropped_event ->
      case dropped_event.drop_reason do
        {:error, %Ecto.Changeset{} = changeset} -> changeset
        _ -> false
      end
    end)
  end
end
