defmodule Plausible.Workers.CleanUserSessions do
  @moduledoc """
  Job removing expired user sessions. A grace period is applied.
  """

  use Plausible.Repo
  use Oban.Worker, queue: :clean_user_sessions

  @grace_period Duration.new!(day: -7)

  @spec grace_period_duration() :: Duration.t()
  def grace_period_duration(), do: @grace_period

  @impl Oban.Worker
  def perform(_job) do
    grace_cutoff =
      NaiveDateTime.utc_now(:second)
      |> NaiveDateTime.shift(@grace_period)

    Repo.delete_all(
      from us in Plausible.Auth.UserSession,
        where: us.timeout_at < ^grace_cutoff
    )

    :ok
  end
end
