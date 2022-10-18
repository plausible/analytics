defimpl FunWithFlags.Actor, for: BitString do
  def id(str) do
    str
  end
end

defmodule PlausibleWeb.Api.ExternalController do
  use PlausibleWeb, :controller
  require Logger

  def event(conn, _params) do
    with {:ok, ingestion_request} <- Plausible.Ingestion.Request.build(conn),
         _ <- Sentry.Context.set_extra_context(%{request: ingestion_request}),
         :ok <- Plausible.Ingestion.Event.build_and_buffer(ingestion_request) do
      conn |> put_status(202) |> text("ok")
    else
      :skip ->
        conn |> put_status(202) |> text("ok")

      {:error, :invalid_json} ->
        conn
        |> put_status(400)
        |> json(%{errors: %{request: "Unable to parse request body as json"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        conn |> put_status(400) |> json(%{errors: errors})
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

    status =
      case {postgres_health, clickhouse_health} do
        {"ok", "ok"} -> 200
        _ -> 500
      end

    put_status(conn, status)
    |> json(%{
      postgres: postgres_health,
      clickhouse: clickhouse_health
    })
  end

  def info(conn, _params) do
    build =
      :plausible
      |> Application.get_env(:runtime_metadata)
      |> Keyword.take([:version, :commit, :created, :tags])
      |> Map.new()

    geo_database =
      case Geolix.metadata(where: :geolocation) do
        %{database_type: type} ->
          type

        _ ->
          "(not configured)"
      end

    json(conn, %{
      geo_database: geo_database,
      build: build
    })
  end
end
