defmodule Plausible.Workers.RotateSalts do
  use Plausible.Repo
  use Oban.Worker, queue: :rotate_salts

  @impl Oban.Worker
  def perform(_job) do
    Plausible.Session.Salts.rotate()
  end
end
