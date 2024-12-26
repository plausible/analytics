defmodule Plausible.DataMigration.ClickhouseRepo do
  @moduledoc """
  Ecto.Repo for Clickhouse data migrations, to be started manually,
  outside of the main application supervision tree.
  """
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.ClickHouse

  def start(url, max_threads) when is_binary(url) and is_integer(max_threads) do
    default_config = Plausible.IngestRepo.config()

    start_link(
      url: url,
      queue_target: 500,
      queue_interval: 2000,
      pool_size: 1,
      settings: [
        max_insert_threads: max_threads,
        send_progress_in_http_headers: 1
      ],
      transport_opts: Keyword.fetch!(default_config, :transport_opts)
    )
  end
end
