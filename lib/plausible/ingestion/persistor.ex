defmodule Plausible.Ingestion.Persistor do
  @moduledoc """
  Registers and persists sessions and events.
  """

  @fallback_backend Plausible.Ingestion.Persistor.Embedded

  def persist_event(event, previous_user_id, opts) do
    {backend_override, opts} = Keyword.pop(opts, :backend)
    user_id = event.clickhouse_event.user_id

    backend(backend_override, user_id).persist_event(event, previous_user_id, opts)
  end

  defp backend(nil, user_id) do
    percent_enabled =
      :plausible
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:backend_percent_enabled)

    backend =
      :plausible
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:backend)

    cond do
      backend == @fallback_backend or percent_enabled >= 100 ->
        backend

      :erlang.phash2(user_id, 100) + 1 >= percent_enabled ->
        backend

      true ->
        @fallback_backend
    end
  end

  defp backend(override, _user_id), do: override
end
