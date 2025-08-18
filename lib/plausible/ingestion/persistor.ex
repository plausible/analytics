defmodule Plausible.Ingestion.Persistor do
  @moduledoc """
  Registers and persists sessions.
  """

  require Logger

  def persist_event(event, session_attrs, previous_user_id) do
    site_id = event.site_id
    current_user_id = event.user_id

    headers = [
      {"x-site-id", site_id},
      {"x-current-user-id", current_user_id},
      {"x-previous-user-id", previous_user_id}
    ]

    payload =
      {event, session_attrs}
      |> :erlang.term_to_binary()
      |> Base.encode64(padding: false)

    result =
      case Req.post(persistor_url(), finch: Plausible.Finch, body: payload, headers: headers) do
        {:ok, %{body: "ok"}} ->
          :ok

        {:ok, resp} ->
          Logger.warning(
            "Persisting event for (#{site_id};#{current_user_id},#{previous_user_id}) failed: #{inspect(resp.body)}"
          )

          {:error, resp.body}

        {:error, error} ->
          Logger.warning(
            "Persisting event for (#{site_id};#{current_user_id},#{previous_user_id}) failed: #{inspect(error)}"
          )

          {:error, error}
      end

    result
  end

  def persistor_url do
    Keyword.fetch!(Application.fetch_env!(:plausible, :persistor), :url)
  end
end
