defimpl FunWithFlags.Actor, for: BitString do
  def id(str) do
    str
  end
end

defmodule PlausibleWeb.Api.ExternalController do
  use PlausibleWeb, :controller
  use Plausible
  require Logger

  alias Plausible.Ingestion

  def event(conn, _params) do
    with {:ok, request} <- Ingestion.Request.build(conn),
         _ <- Sentry.Context.set_extra_context(%{request: request}) do
      case Ingestion.Event.build_and_buffer(request) do
        {:ok, %{dropped: [], buffered: _buffered}} ->
          on_ee do
            Ingestion.Analyzer.maybe_record(request, conn.req_headers, nil)
          end

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
            on_ee do
              Ingestion.Analyzer.maybe_record(
                request,
                conn.req_headers,
                List.first(dropped).drop_reason
              )
            end

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

  defp find_first_invalid_changeset(dropped) do
    Enum.find_value(dropped, nil, fn dropped_event ->
      case dropped_event.drop_reason do
        {:error, %Ecto.Changeset{} = changeset} -> changeset
        _ -> false
      end
    end)
  end
end
