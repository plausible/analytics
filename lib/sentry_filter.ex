defmodule Plausible.SentryFilter do
  @moduledoc """
  Sentry callbacks for filtering and grouping events
  """
  @behaviour Sentry.EventFilter

  def exclude_exception?(%Phoenix.NotAcceptableError{}, _), do: true
  def exclude_exception?(%Plug.CSRFProtection.InvalidCSRFTokenError{}, _), do: true
  def exclude_exception?(%Plug.Static.InvalidPathError{}, _), do: true

  def exclude_exception?(exception, source) do
    Sentry.DefaultEventFilter.exclude_exception?(exception, source)
  end

  @spec before_send(Sentry.Event.t()) :: Sentry.Event.t()
  def before_send(event)

  def before_send(
        %{exception: [%{type: "Clickhousex.Error"}], original_exception: %{code: code}} = event
      )
      when is_atom(code) do
    %{event | fingerprint: ["clickhouse", "db_connection", to_string(code)]}
  end

  def before_send(%{event_source: :logger, message: "Clickhousex.Protocol " <> _} = event) do
    %{event | fingerprint: ["clickhouse", "db_connection", "protocol_error"]}
  end

  def before_send(
        %{
          exception: [%{type: "DBConnection.ConnectionError"}],
          original_exception: %{reason: reason}
        } = event
      ) do
    %{event | fingerprint: ["db_connection", reason]}
  end

  def before_send(%{extra: %{request: %Plausible.Ingestion.Request{}}} = event) do
    %{event | fingerprint: ["ingestion_request"]}
  end

  def before_send(event) do
    event
  end
end
