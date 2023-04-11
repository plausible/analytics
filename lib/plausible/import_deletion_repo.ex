defmodule Plausible.ImportDeletionRepo do
  @moduledoc """
  A dedicated repo for import related mutations
  """

  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.ClickHouse

  defmacro __using__(_) do
    quote do
      alias Plausible.ImportDeletionRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end
end
