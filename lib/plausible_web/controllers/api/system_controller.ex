defmodule PlausibleWeb.Api.SystemController do
  use PlausibleWeb, :controller

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

  def liveness(conn, _params) do
    json(conn, %{ok: true})
  end

  def readiness(conn, _params) do
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
end
