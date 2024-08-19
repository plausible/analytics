defmodule Plausible.Workers.LocationsSync do
  @moduledoc false

  use Plausible.Repo
  use Oban.Worker, queue: :locations_sync

  @impl Oban.Worker
  def perform(_job) do
    if Plausible.DataMigration.LocationsSync.out_of_date?() do
      Plausible.DataMigration.LocationsSync.run()
    end

    :ok
  end
end
