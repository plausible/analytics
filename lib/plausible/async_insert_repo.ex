defmodule Plausible.AsyncInsertRepo do
  @moduledoc """
  Clickhouse access with async inserts enabled
  """

  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.ClickHouse

  defmacro __using__(_) do
    quote do
      alias Plausible.AsyncInsertRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end
end
