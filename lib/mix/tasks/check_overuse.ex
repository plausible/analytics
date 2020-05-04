defmodule Mix.Tasks.CheckOveruse do
  use Mix.Task
  use Plausible.Repo
  require Logger

  # coveralls-ignore-start

  def run(args) do
    Application.ensure_all_started(:plausible)
    Logger.configure(level: :error)
    execute(args)
  end

  def execute(_args \\ []) do
    active_users =
      Repo.all(
        from u in Plausible.Auth.User,
          join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          where: s.status == "active",
          select: {u, s}
      )

    for {user, subscription} <- active_users do
      IO.puts("Checking #{user.email}...")
      usage = Plausible.Billing.usage(user)
      allowance = Plausible.Billing.Plans.allowance(subscription)

      if usage > allowance do
        IO.puts("Overuse: #{user.email}")
        IO.puts("Usage: #{usage}")
        IO.puts("Allowance: #{allowance}")
      end
    end
  end
end
