defmodule Plausible.SentryFilter do
  @behaviour Sentry.EventFilter

  def exclude_exception?(%Sentry.CrashError{}, _source), do: true
  def exclude_exception?(%Phoenix.NotAcceptableError{}, _), do: true

  def exclude_exception?(exception, source) do
    Sentry.DefaultEventFilter.exclude_exception?(exception, source)
  end
end
