defmodule Plausible.ApiRequestLog do
  @moduledoc """
  Log of the API requests made with a credential, kept to measure API usage
  per team for billing.

  See `Plausible.ApiRequestLog.Entry` for what each request records.
  """

  alias Plausible.ApiRequestLog.Entry
  alias Plausible.ApiRequestLog.WriteBuffer

  @doc """
  Records one API request. Writes are batched and asynchronous.

  Does nothing when the `:record_api_requests` flag is off for the team.
  """
  @spec record(Entry.attrs()) :: :ok
  def record(%{team: team} = attrs) do
    if FunWithFlags.enabled?(:record_api_requests, for: team) do
      attrs
      |> Entry.new()
      |> WriteBuffer.insert()
    else
      :ok
    end
  end
end
