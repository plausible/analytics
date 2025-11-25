defmodule Plausible.Ingestion.Persistor.TelemetryHandler do
  @moduledoc """
  Sets up telemetry for remote calls to persistor via `Finch.Telemetry` events.

  Emits persistor specific telemetry events for tracking metrics.
  """

  @finch_request_event [:finch, :request, :stop]
  @finch_connect_event [:finch, :connect, :stop]
  @finch_send_event [:finch, :send, :stop]
  @finch_receive_event [:finch, :recv, :stop]

  @persistor_request_event [:persistor, :remote, :request]
  @persistor_connect_event [:persistor, :remote, :connect]
  @persistor_send_event [:persistor, :remote, :send]
  @persistor_receive_event [:persistor, :remote, :receive]

  @telemetry_events [
    @finch_request_event,
    @finch_connect_event,
    @finch_send_event,
    @finch_receive_event
  ]

  @telemetry_handler &__MODULE__.handle_event/4

  def request_event(), do: @persistor_request_event
  def connect_event(), do: @persistor_connect_event
  def send_event(), do: @persistor_send_event
  def receive_event(), do: @persistor_receive_event

  @spec install() :: :ok
  def install() do
    if persistor_backend() in [
         Plausible.Ingestion.Persistor.Remote,
         Plausible.Ingestion.Persistor.EmbeddedWithRelay
       ] do
      persistor_host =
        persistor_url()
        |> URI.parse()
        |> Map.fetch!(:host)

      persistor_count = persistor_count()

      if is_binary(persistor_host) do
        :ok =
          :telemetry.attach_many(
            "persistor-remote-finch-metrics",
            @telemetry_events,
            @telemetry_handler,
            %{remote_host: persistor_host, pool_size: persistor_count}
          )
      else
        :ok
      end
    else
      :ok
    end
  end

  @spec handle_event([atom()], any(), map(), any()) :: :ok
  def handle_event(
        @finch_request_event,
        %{duration: duration},
        %{request: request, result: result},
        config
      ) do
    if request.host == config.remote_host do
      result =
        case result do
          {:ok, %Finch.Response{status: status}} when status >= 200 and status < 300 ->
            "ok"

          {:ok, %Finch.Response{}} ->
            "bad_status"

          {:ok, _} ->
            "stream"

          {:error, %{reason: :timeout}} ->
            "timeout_error"

          {:error, _} ->
            "unknown_error"
        end

      :telemetry.execute(
        @persistor_request_event,
        %{duration: duration},
        %{result: result, path: normalize_path(request.path)}
      )
    end

    :ok
  end

  def handle_event(
        @finch_connect_event,
        %{duration: duration},
        %{host: host} = meta,
        config
      ) do
    if host == config.remote_host do
      :telemetry.execute(
        @persistor_connect_event,
        %{duration: duration},
        %{status: if(meta[:error], do: "error", else: "ok")}
      )
    end

    :ok
  end

  def handle_event(
        @finch_send_event,
        %{duration: duration},
        %{request: request} = meta,
        config
      ) do
    if request.host == config.remote_host do
      :telemetry.execute(
        @persistor_send_event,
        %{duration: duration},
        %{status: if(meta[:error], do: "error", else: "ok")}
      )
    end

    :ok
  end

  def handle_event(
        @finch_receive_event,
        %{duration: duration},
        %{request: request} = meta,
        config
      ) do
    if request.host == config.remote_host do
      status = meta[:status] || 0

      :telemetry.execute(
        @persistor_receive_event,
        %{duration: duration},
        %{
          status: if(meta[:error] || status < 200 || status > 299, do: "error", else: "ok")
        }
      )
    end

    :ok
  end

  defp normalize_path(path) do
    if path == "/event" do
      "/event"
    else
      "unknown"
    end
  end

  defp persistor_url() do
    :plausible
    |> Application.fetch_env!(Plausible.Ingestion.Persistor.Remote)
    |> Keyword.fetch!(:url)
  end

  defp persistor_backend() do
    :plausible
    |> Application.fetch_env!(Plausible.Ingestion.Persistor)
    |> Keyword.fetch!(:backend)
  end

  defp persistor_count() do
    :plausible
    |> Application.fetch_env!(Plausible.Ingestion.Persistor.Remote)
    |> Keyword.fetch!(:count)
  end
end
