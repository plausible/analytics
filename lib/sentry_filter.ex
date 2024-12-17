defmodule Plausible.SentryFilter do
  @moduledoc """
  Sentry callbacks for filtering and grouping events
  """

  @spec before_send(Sentry.Event.t()) :: Sentry.Event.t()
  def before_send(event)

  def before_send(%{original_exception: %Phoenix.NotAcceptableError{}}), do: false
  def before_send(%{original_exception: %Plug.CSRFProtection.InvalidCSRFTokenError{}}), do: false
  def before_send(%{original_exception: %Plug.Static.InvalidPathError{}}), do: false

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
