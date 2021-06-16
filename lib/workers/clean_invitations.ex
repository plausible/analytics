defmodule Plausible.Workers.CleanInvitations do
  use Plausible.Repo
  use Oban.Worker, queue: :clean_invitations

  @impl Oban.Worker
  def perform(_job) do
    Repo.delete_all(
      from i in Plausible.Auth.Invitation,
        where: i.inserted_at < fragment("now() - INTERVAL '48 hours'")
    )

    :ok
  end
end
