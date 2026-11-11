defmodule PlausibleWeb.Api.CustomerSupport.EnterprisePlanController do
  @moduledoc """
  Creates a custom (enterprise) plan for a team, or updates one of its
  existing plans, as "Save Custom Plan" and the plan's edit (pencil) form in
  the CS admin do. There is no endpoint to delete a plan.
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
               "The team has a manual subscription. Update its existing plan instead."
             ),
           {:ok, plan} <-
             %EnterprisePlan{team_id: team.id}
             |> EnterprisePlan.create_changeset(Map.take(params, @plan_fields))
             |> Repo.insert() do
        {:ok, plan, plan_json(plan)}
      end
    end)
  end

  @doc """
  Updates one of the team's plans: limits, interval and features. The Paddle
  plan id never changes (subscriptions are linked to the plan by it), the
  same as the CS admin's edit form. This is how a pay-by-invoice customer's
  terms change once they have a manual subscription.
  """
  def update(conn, params) do
    H.run_team_action(conn, params, "enterprise_plan_updated", fn team ->
      with {:ok, plan} <- fetch_plan(team, params["plan_id"]),
           {:ok, plan} <-
             plan
             |> EnterprisePlan.update_changeset(
               Map.take(params, @plan_fields -- ["paddle_plan_id"])
             )
             |> Repo.update() do
        {:ok, plan, plan_json(plan)}
      end
    end)
  end

  defp fetch_plan(team, plan_id) do
    with {:ok, id} <- H.parse_id(plan_id),
         %EnterprisePlan{} = plan <- Repo.get_by(EnterprisePlan, id: id, team_id: team.id) do
      {:ok, plan}
    else
      _ -> {:error, :not_found, "The team has no plan with this id"}
    end
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
