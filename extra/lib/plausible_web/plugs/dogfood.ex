defmodule PlausibleWeb.Plugs.Dogfood do
  @moduledoc """
  Assigns `:current_plan` once per request so the dogfood tracker doesn't
  preload the subscription on every layout render.
  """

  @behaviour Plug

  import Plug.Conn

  alias Plausible.Billing.{EnterprisePlan, Plan, Plans}
  alias Plausible.Teams

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{assigns: %{current_user: %{}, current_team: team}} = conn, _opts) do
    assign(conn, :current_plan, current_plan(team))
  end

  def call(conn, _opts), do: conn

  defp current_plan(nil), do: "no_subscription"

  defp current_plan(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %Plan{kind: kind} -> Atom.to_string(kind)
      %EnterprisePlan{} -> "enterprise"
      :free_10k -> "free_10k"
      nil -> "no_subscription"
    end
  end
end
