defmodule Plausible.DataMigration.PostgresRepo do
  @moduledoc """
  Ecto.Repo for Posrtgres data migrations, to be started manually,
  outside of the main application supervision tree.
  """
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.Postgres

  def start(url, opts \\ []) when is_binary(url) do
    default_config = Plausible.Repo.config()

    start_link(
      url: url,
      queue_target: 500,
      queue_interval: 2000,
      pool_size: opts[:pool_size] || 1,
      ssl: opts[:ssl] || default_config[:ssl],
      ssl_opts: opts[:ssl_opts] || default_config[:ssl_opts]
    )
  end
end
