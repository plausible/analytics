defmodule Plausible.Billing.DevSubscriptions do
  @moduledoc """
  Module for conveniently handling subscriptions in the :dev environment.
  """

  import Ecto.Query

  alias Plausible.{Repo, Billing}
  alias Plausible.Billing.{Plan, EnterprisePlan, DevPaddleApiMock}
  alias PlausibleWeb.Router.Helpers, as: Routes

  def create_after_1s(team_id, plan_id) do
    Task.start(fn ->
      Process.sleep(1000)
      create(team_id, plan_id)
    end)
  end

  def create(team_id, plan_id, opts \\ []) do
    plan_or_enterprise_plan = get_plan_or_enterprise_plan(plan_id)

    if plan_or_enterprise_plan do
      if Keyword.get(opts, :clean_existing, true) do
        delete(team_id)
      end

      %{
        "event_time" => to_string(NaiveDateTime.utc_now(:second)),
        "alert_name" => "subscription_created",
        "passthrough" => "ee:true;user:0;team:#{team_id}",
        "email" => "",
        "subscription_id" => Ecto.UUID.generate(),
        "subscription_plan_id" => plan_id,
        "update_url" => Routes.dev_subscription_path(PlausibleWeb.Endpoint, :update_form),
        "cancel_url" => Routes.dev_subscription_path(PlausibleWeb.Endpoint, :cancel_form),
        "status" => "active",
        "next_bill_date" => next_bill_date(plan_or_enterprise_plan, plan_id),
        "unit_price" => "#{to_string(DevPaddleApiMock.all_prices()[plan_id])}.00",
        "currency" => "EUR"
      }
      |> Plausible.Billing.subscription_created()

      {:ok, Repo.reload(get_team_subscription(team_id))}
    else
      {:error, "Plan with id '#{plan_id}' not found."}
    end
  end

  def update(team_id, new_status) do
    if subscription = get_team_subscription(team_id) do
      current_plan_id = subscription.paddle_plan_id
      current_plan = get_plan_or_enterprise_plan(current_plan_id)

      next_bill_date =
        case new_status do
          "active" -> next_bill_date(current_plan, current_plan_id)
          "past_due" -> Date.utc_today() |> Date.shift(day: 5) |> Date.to_iso8601()
          "paused" -> subscription.next_bill_date |> Date.to_iso8601()
        end

      %{
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => current_plan_id,
        "update_url" => subscription.update_url,
        "cancel_url" => subscription.cancel_url,
        "old_status" => to_string(subscription.status),
        "status" => new_status,
        "next_bill_date" => next_bill_date,
        "new_unit_price" => "#{to_string(DevPaddleApiMock.all_prices()[current_plan_id])}.00",
        "currency" => "EUR"
      }
      |> Plausible.Billing.subscription_updated()

      :ok
    else
      {:error, :no_subscription}
    end
  end

  def delete(team_id, opts \\ []) do
    delete_enterprise? = Keyword.get(opts, :delete_enterprise?, false)

    if subscription = get_team_subscription(team_id) do
      Repo.delete(subscription)

      if delete_enterprise? do
        Plausible.Repo.delete_all(from(e in EnterprisePlan, where: e.team_id == ^team_id))
      end

      :ok
    else
      {:error, :no_subscription}
    end
  end

  def cancel(team_id, opts \\ []) do
    set_expired? = Keyword.get(opts, :set_expired?, false)

    if subscription = get_team_subscription(team_id) do
      %{"subscription_id" => subscription.paddle_subscription_id, "status" => "deleted"}
      |> Billing.subscription_cancelled()

      subscription = Repo.reload!(subscription)

      if set_expired? do
        subscription
        |> Ecto.Changeset.change(%{next_bill_date: Date.utc_today() |> Date.add(-1)})
        |> Repo.update()
      else
        {:ok, subscription}
      end
    else
      {:error, :no_subscription}
    end
  end

  defp get_plan_or_enterprise_plan(plan_id) do
    Billing.Plans.find(plan_id) || Repo.get_by(EnterprisePlan, paddle_plan_id: plan_id)
  end

  defp get_team_subscription(team_id) do
    Plausible.Teams.Team
    |> Plausible.Repo.get(team_id)
    |> Plausible.Teams.with_subscription()
    |> Map.get(:subscription)
  end

  defp next_bill_date(%EnterprisePlan{} = plan, _) do
    if plan.billing_interval == :monthly, do: next_month(), else: next_year()
  end

  defp next_bill_date(%Plan{} = plan, plan_id) do
    if plan_id == plan.monthly_product_id, do: next_month(), else: next_year()
  end

  defp next_month(), do: Date.utc_today() |> Date.shift(month: 1) |> Date.to_iso8601()
  defp next_year(), do: Date.utc_today() |> Date.shift(year: 1) |> Date.to_iso8601()
end
