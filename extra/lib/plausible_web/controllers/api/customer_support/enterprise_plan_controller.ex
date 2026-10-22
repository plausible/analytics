defmodule PlausibleWeb.Api.CustomerSupport.EnterprisePlanController do
  @moduledoc """
  Creates a custom (enterprise) plan for a team, as the "Save Custom Plan"
  button in the CS admin does. Insert only: there is no endpoint to update
  or delete a plan.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Billing.{EnterprisePlan, Subscription}
  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @plan_fields ~w(paddle_plan_id billing_interval monthly_pageview_limit site_limit
                  team_member_limit hourly_api_request_limit features)

  def create(conn, params) do
    H.run_team_action(conn, params, "enterprise_plan_created", fn team ->
      # Same rule as the CS admin's "New Custom Plan" button.
      with :ok <-
             H.guard(
               not Subscription.manual_subscription?(team.subscription),
               "The team has a manual subscription. Edit its existing plan in the CS admin instead."
             ),
           {:ok, plan} <-
             %EnterprisePlan{team_id: team.id}
             |> EnterprisePlan.create_changeset(Map.take(params, @plan_fields))
             |> Repo.insert() do
        {:ok, plan, plan_json(plan)}
      end
    end)
  end

  defp plan_json(plan) do
    %{
      id: plan.id,
      team_id: plan.team_id,
      paddle_plan_id: plan.paddle_plan_id,
      billing_interval: plan.billing_interval,
      monthly_pageview_limit: plan.monthly_pageview_limit,
      site_limit: plan.site_limit,
      team_member_limit: plan.team_member_limit,
      hourly_api_request_limit: plan.hourly_api_request_limit,
      features: Enum.map(plan.features, &Atom.to_string(&1.name()))
    }
  end
end
