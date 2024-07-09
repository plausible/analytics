defmodule Plausible.Workers.LocationsSync do
  use Plausible.Repo
  use Oban.Worker, queue: :update_locations

  @impl Oban.Worker
  def perform(_job) do
    if Plausible.DataMigration.LocationsSync.out_of_date?() do
      Plausible.DataMigration.LocationsSync.run()
    end

    :ok
  end
end
