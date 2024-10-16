defmodule Plausible.DataMigration.PostgresRepo do
  @moduledoc """
  Ecto.Repo for Posrtgres data migrations, to be started manually,
  outside of the main application supervision tree.
  """
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.Postgres

  def start(url, pool_size \\ 1) when is_binary(url) do
    default_config = Plausible.Repo.config()

    start_link(
      url: url,
      queue_target: 500,
      queue_interval: 2000,
      pool_size: pool_size,
      ssl: default_config[:ssl],
      ssl_opts: default_config[:ssl_opts]
    )
  end
end
