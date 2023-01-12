defmodule Plausible.SentryFilter do
  @moduledoc """
  Sentry callbacks for filtering and grouping events
  """
  @behaviour Sentry.EventFilter

  def exclude_exception?(%Sentry.CrashError{}, _source), do: true
  def exclude_exception?(%Phoenix.NotAcceptableError{}, _), do: true

  def exclude_exception?(exception, source) do
    Sentry.DefaultEventFilter.exclude_exception?(exception, source)
  end

  @spec before_send(Sentry.Event.t()) :: Sentry.Event.t()
  def before_send(event)

  # https://hexdocs.pm/sentry/readme.html#fingerprinting
  def before_send(%{exception: [%{type: DBConnection.ConnectionError}]} = event) do
    %{event | fingerprint: ["ecto", "db_connection", "timeout"]}
  end

  def before_send(event) do
    event
  end
end
