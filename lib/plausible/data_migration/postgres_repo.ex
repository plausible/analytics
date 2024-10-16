defmodule Plausible.DataMigration.PostgresRepo do
  @moduledoc """
  Ecto.Repo for Posrtgres data migrations, to be started manually,
  outside of the main application supervision tree.
  """
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.Postgres

  def start(url) when is_binary(url) do
    start_link(
      url: url,
      queue_target: 500,
      queue_interval: 2000,
      pool_size: 1
    )
  end
end
