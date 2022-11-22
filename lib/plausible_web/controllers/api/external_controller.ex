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
    case Ingestion.Request.build(conn) do
      {:ok, request} ->
        Sentry.Context.set_extra_context(%{request: request})

        case Ingestion.Event.build_and_buffer(request) do
          {:ok, %{dropped: [], buffered: _buffered}} ->
            conn
            |> put_status(202)
            |> text("ok")

          {:ok, %{dropped: dropped, buffered: _}} ->
            first_invalid_changeset =
              Enum.find_value(dropped, nil, fn dropped_event ->
                case dropped_event.drop_reason do
                  {:error, %Ecto.Changeset{} = changeset} -> changeset
                  _ -> false
                end
              end)

            if first_invalid_changeset do
              user_facing_errors =
                Ecto.Changeset.traverse_errors(first_invalid_changeset, fn {msg, opts} ->
                  Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
                    opts
                    |> Keyword.get(String.to_existing_atom(key), key)
                    |> to_string()
                  end)
                end)

              conn
              |> put_resp_header("x-plausible-dropped", "#{Enum.count(dropped)}")
              |> put_status(400)
              |> json(%{errors: user_facing_errors})
            else
              conn
              |> put_resp_header("x-plausible-dropped", "#{Enum.count(dropped)}")
              |> put_status(202)
              |> text("ok")
            end
        end

      {:error, :invalid_json} ->
        conn
        |> put_status(400)
        |> json(%{errors: %{request: "Unable to parse request body as json"}})
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
