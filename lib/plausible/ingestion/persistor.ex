defmodule Plausible.Ingestion.Persistor do
  @moduledoc """
  Registers and persists sessions and events.
  """

  def persist_event(event, previous_user_id, opts) do
    {backend_override, opts} = Keyword.pop(opts, :backend)

    backend(backend_override).persist_event(event, previous_user_id, opts)
  end

  defp backend(nil) do
    :plausible
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:backend)
  end

  defp backend(override), do: override
end
