defmodule Neatmetrics.Repo do
  use Ecto.Repo,
    otp_app: :neatmetrics,
    adapter: Ecto.Adapters.Postgres

  defmacro __using__(_) do
    quote do
      alias Neatmetrics.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end
end
