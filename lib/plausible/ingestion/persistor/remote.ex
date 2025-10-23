defmodule Plausible.Ingestion.Persistor.Remote do
  @moduledoc """
  Remote implementation of session and event persistence.
  """

  require Logger

  @max_transient_retries 3

  def persist_event(ingest_event, previous_user_id, opts) do
    event = ingest_event.clickhouse_event
    session_attrs = ingest_event.clickhouse_session_attrs

    site_id = event.site_id
    current_user_id = event.user_id
    override_url = Keyword.get(opts, :url)

    headers = [
      {"x-site-id", site_id},
      {"x-current-user-id", current_user_id},
      {"x-previous-user-id", previous_user_id}
    ]

    case request(override_url, event, session_attrs, headers) do
      {:ok, %{status: 200, body: event_payload}} ->
        case decode_payload(event_payload) do
          {:ok, event} ->
            {:ok, %{ingest_event | clickhouse_event: event}}

          {:error, decode_error} ->
            log_error(site_id, current_user_id, previous_user_id, decode_error)
            {:error, :persist_decode_error}
        end

      {:ok, %{body: "no_session_for_engagement"}} ->
        {:error, :no_session_for_engagement}

      {:ok, %{body: error}} ->
        log_error(site_id, current_user_id, previous_user_id, error)
        {:error, decode_error(error)}

      {:error, %{reason: :timeout}} ->
        {:error, :persist_timeout}

      {:error, error} ->
        log_error(site_id, current_user_id, previous_user_id, error)

        {:error, :persist_error}
    end
  end

  def telemetry_request_duration() do
    [:plausible, :remote_ingest, :request, :duration]
  end

  def telemetry_decode_duration() do
    [:plausible, :remote_ingest, :decode, :duration]
  end

  defp request(override_url, event, session_attrs, headers) do
    Plausible.PromEx.Plugins.PlausibleMetrics.measure_duration(
      telemetry_request_duration(),
      fn ->
        Req.post(persistor_url(override_url),
          finch: Plausible.Finch,
          body: encode_payload(event, session_attrs),
          headers: headers,
          retry: &handle_transient_error/2,
          max_retries: @max_transient_retries
        )
      end
    )
  end

  defp handle_transient_error(_request, %Req.HTTPError{protocol: :http2, reason: :disconnected}) do
    true
  end

  defp handle_transient_error(_request, %Req.HTTPError{protocol: :http2, reason: :unprocessed}) do
    true
  end

  defp handle_transient_error(_reqeust, _response), do: false

  defp encode_payload(event, session_attrs) do
    event_data =
      event
      |> Map.from_struct()
      |> Map.delete(:__meta__)

    {event_data, session_attrs}
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp decode_payload(payload) do
    Plausible.PromEx.Plugins.PlausibleMetrics.measure_duration(
      telemetry_decode_duration(),
      fn ->
        case Base.decode64(payload, padding: false) do
          {:ok, data} ->
            event_data = :erlang.binary_to_term(data)
            event = struct(Plausible.ClickhouseEventV2, event_data)

            {:ok, event}

          _ ->
            {:error, :invalid_web_encoding}
        end
      end
    )
  catch
    _, _ ->
      {:error, :invalid_payload}
  end

  defp decode_error("no_session_for_engagement"), do: :no_session_for_engagement
  defp decode_error("lock_timeout"), do: :lock_timeout
  defp decode_error(_), do: :persist_error

  defp persistor_url(nil) do
    Keyword.fetch!(Application.fetch_env!(:plausible, __MODULE__), :url)
  end

  defp persistor_url(url) when is_binary(url) do
    url
  end

  defp log_error(site_id, current_user_id, previous_user_id, error) do
    Logger.warning(
      "Persisting event for (#{site_id};#{current_user_id},#{previous_user_id}) failed: #{inspect(error)}"
    )
  end
end
