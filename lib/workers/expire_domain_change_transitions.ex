defmodule Plausible.Workers.ExpireDomainChangeTransitions do
  @moduledoc """
  Periodic worker that expires domain change transition period.
  Old domains are frozen for a given time, so users can still access them
  before redeploying their scripts and integrations.
  """
  use Plausible.Repo
  use Oban.Worker, queue: :domain_change_transition

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    {:ok, n} = Plausible.Site.Domain.expire_change_transitions()

    if n > 0 do
      Logger.warning("Expired #{n} from the domain change transition period.")
    end

    :ok
  end
end
