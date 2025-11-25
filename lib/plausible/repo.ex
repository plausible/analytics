defmodule Plausible.Repo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 24

  use Plausible.Audit.Repo

  defmacro __using__(_) do
    quote do
      alias Plausible.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end
end
