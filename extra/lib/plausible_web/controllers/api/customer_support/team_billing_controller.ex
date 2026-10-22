defmodule PlausibleWeb.Api.CustomerSupport.TeamBillingController do
  @moduledoc """
  Unlock, Lock, Refund Lock and Manual Subscribe, as on the CS admin team
  page, each refused unless the team is in the state the button expects.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Billing.EnterprisePlan
  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  def unlock(conn, params) do
    H.run_team_action(conn, params, "team_unlocked", fn team ->
      with {:ok, team} <- lock_result(Plausible.Teams.unlock(team)) do
        {:ok, team, %{locked: team.locked, grace_period: nil}}
      end
    end)
  end

  def lock(conn, params) do
    H.run_team_action(conn, params, "team_locked", fn team ->
      with {:ok, team} <- lock_result(Plausible.Teams.lock(team)) do
        {:ok, team, %{locked: team.locked, grace_period_ended: true}}
      end
    end)
  end

  def refund_lock(conn, params) do
    H.run_team_action(conn, params, "team_refund_locked", fn team ->
      with {:ok, team} <- lock_result(Plausible.Teams.refund_lock(team)) do
        {:ok, team, %{locked: team.locked, next_bill_date: team.subscription.next_bill_date}}
      end
    end)
  end

  def manual_subscription(conn, params) do
    H.run_team_action(conn, params, "team_manually_subscribed", fn team ->
      with {:ok, plan_id} <- plan_id(params),
           %EnterprisePlan{} = plan <-
             Repo.get_by(EnterprisePlan, id: plan_id, team_id: team.id) ||
               {:error, :guard, "The plan doesn't belong to this team"},
           {:ok, _} <- manual_subscribe(team, plan) do
        {:ok, team, %{manual_subscription: true, enterprise_plan_id: plan.id}}
      end
    end)
  end

  defp lock_result({:ok, team}), do: {:ok, team}

  defp lock_result({:error, :no_grace_period}),
    do: {:error, :guard, "The team has no grace period"}

  defp lock_result({:error, :subscription_not_cancelled}),
    do: {:error, :guard, "The subscription isn't cancelled"}

  defp lock_result({:error, :has_grace_period}),
    do: {:error, :guard, "The team has a grace period"}

  defp lock_result({:error, :already_locked}), do: {:error, :guard, "The team is already locked"}

  defp plan_id(params) do
    case H.parse_id(params["enterprise_plan_id"]) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :guard, "Parameter `enterprise_plan_id` is required"}
    end
  end

  defp manual_subscribe(team, plan) do
    case Plausible.Billing.create_manual_subscription(team, plan) do
      {:ok, result} ->
        {:ok, result}

      {:error, :already_manual} ->
        {:error, :guard, "The team already has a manual subscription"}

      {:error, :active_subscription} ->
        {:error, :guard, "The team has an active Paddle subscription"}

      {:error, :not_latest_plan} ->
        {:error, :guard, "Only the latest custom plan can be used"}

      {:error, :not_yearly} ->
        {:error, :guard, "Manual subscriptions need a yearly plan"}

      {:error, %Ecto.Changeset{}} = error ->
        error
    end
  end
end
