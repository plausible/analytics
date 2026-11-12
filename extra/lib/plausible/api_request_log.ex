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
  """
  @spec record(Entry.attrs()) :: :ok
  def record(attrs) do
    attrs
    |> Entry.new()
    |> WriteBuffer.insert()
  end
end
