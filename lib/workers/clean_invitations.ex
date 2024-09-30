defmodule Plausible.Workers.CleanInvitations do
  use Plausible.Repo
  use Oban.Worker, queue: :clean_invitations

  @cutoff Duration.new!(hour: -48)

  @impl Oban.Worker
  def perform(_job) do
    cutoff_time =
      NaiveDateTime.utc_now(:second)
      |> NaiveDateTime.shift(@cutoff)

    Repo.delete_all(
      from i in Plausible.Auth.Invitation,
        where: i.inserted_at < ^cutoff_time
    )

    :ok
  end
end
