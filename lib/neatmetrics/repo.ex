defmodule Neatmetrics.Repo do
  use Ecto.Repo,
    otp_app: :neatmetrics,
    adapter: Ecto.Adapters.Postgres
end
