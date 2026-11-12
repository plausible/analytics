defmodule Plausible.Factory.BillingModeStrategy do
  @moduledoc """
  ExMachina insert strategy. With `BILLING_SUBSCRIPTIONS=1` it turns
  Classic subscriptions into Paddle Billing ones on insert, so the whole
  test suite can run against Billing subscriptions.

  `free_10k` and manual subscriptions stay Classic, because Billing has no
  equivalent.
  """
  use ExMachina.Strategy, function_name: :insert

  alias Plausible.Billing.{EnterprisePlan, PaddleBilling, PaddleClassic, Plans}
  alias Plausible.Repo

  import Ecto.Query, only: [from: 2]

  @classic_only_plan_ids ["free_10k", "manual-subscription"]

  def enabled?, do: System.get_env("BILLING_SUBSCRIPTIONS") == "1"

  def handle_insert(record, opts) do
    record
    |> convert()
    |> ExMachina.EctoStrategy.handle_insert(opts)
    |> link_team()
  end

  def handle_insert(record, opts, insert_opts) do
    record
    |> convert()
    |> ExMachina.EctoStrategy.handle_insert(opts, insert_opts)
    |> link_team()
  end

  defp convert(record) do
    if enabled?(), do: do_convert(record), else: record
  end

  defp do_convert(%PaddleClassic.Subscription{paddle_plan_id: plan_id} = subscription)
       when plan_id not in @classic_only_plan_ids do
    replace_existing(subscription)
    n = System.unique_integer([:positive])

    %PaddleBilling.Subscription{
      billing_subscription_id: "sub_#{n}",
      billing_customer_id: "ctm_#{n}",
      billing_product_id: "pro_test",
      billing_price_id: billing_price_id(plan_id),
      status: subscription.status,
      next_bill_amount: subscription.next_bill_amount,
      next_bill_date: subscription.next_bill_date,
      last_bill_date: subscription.last_bill_date,
      currency_code: subscription.currency_code,
      team: subscription.team,
      team_id: subscription.team_id,
      inserted_at: subscription.inserted_at,
      updated_at: subscription.updated_at
    }
  end

  defp do_convert(%EnterprisePlan{billing_price_id: nil, paddle_plan_id: plan_id} = plan)
       when plan_id not in @classic_only_plan_ids do
    %{plan | billing_price_id: billing_price_id(plan_id)}
  end

  defp do_convert(record), do: record

  defp replace_existing(%{team_id: team_id}) when is_integer(team_id) do
    Repo.delete_all(from s in PaddleBilling.Subscription, where: s.team_id == ^team_id)
  end

  defp replace_existing(%{team: %{id: team_id}}) when is_integer(team_id) do
    replace_existing(%{team_id: team_id})
  end

  defp replace_existing(_), do: :ok

  defp billing_price_id(paddle_plan_id) do
    case Plans.find(paddle_plan_id) do
      %{monthly_product_id: ^paddle_plan_id} = plan -> plan.billing_monthly_price_id
      %{} = plan -> plan.billing_yearly_price_id
      nil -> nil
    end || "pri_#{paddle_plan_id}"
  end

  defp link_team(%PaddleBilling.Subscription{team_id: team_id, billing_customer_id: id} = s) do
    Plausible.Teams.Team
    |> Repo.get!(team_id)
    |> Ecto.Changeset.change(billing_customer_id: id)
    |> Repo.update!()

    s
  end

  defp link_team(record), do: record
end
