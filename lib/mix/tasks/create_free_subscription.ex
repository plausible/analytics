defmodule Mix.Tasks.CreateFreeSubscription do
  use Mix.Task
  use Plausible.Repo
  require Logger
  alias Plausible.Billing.Subscription

  # coveralls-ignore-start

  def run([user_id]) do
    Application.ensure_all_started(:plausible)
    execute(user_id)
  end

  def run(_), do: IO.puts("Usage - mix create_free_subscription <user_id>")

  def execute(user_id) do
    user = Repo.get(Plausible.Auth.User, user_id)
    {:ok, team} = Plausible.Teams.get_or_create(user)

    Subscription.free(%{team_id: team.id})
    |> Repo.insert!()

    IO.puts("Created a free subscription for user: #{user.name}")
  end
end
