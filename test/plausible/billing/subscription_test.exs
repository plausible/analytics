defmodule Plausible.Billing.SubscriptionTest do
  use Plausible.DataCase, async: true
  @moduletag :skip_extra_billing_run
  use Plausible.Teams.Test

  alias Plausible.Billing.PaddleBilling
  alias Plausible.Billing.PaddleClassic
  alias Plausible.Billing.Subscription
  alias Plausible.Teams

  describe "current subscription of a team" do
    test "is the latest Classic subscription when the team has no billing customer" do
      team = new_team()

      insert(:subscription,
        team: team,
        paddle_plan_id: "old",
        inserted_at: ~N[2026-01-01 00:00:00]
      )

      insert(:subscription,
        team: team,
        paddle_plan_id: "new",
        inserted_at: ~N[2026-02-01 00:00:00]
      )

      assert %Subscription{type: :classic, paddle_plan_id: "new"} =
               Teams.with_subscription(team).subscription
    end

    # Skipped until billing_interval is set by the schema (paddle-billing-interfaces)
    @tag :skip
    test "is the Billing subscription when the team has a billing customer" do
      team = new_team()
      insert(:subscription, team: team, paddle_plan_id: "classic")
      team = set_billing_customer_id(team, "ctm_1")
      insert(:billing_subscription, team: team, billing_customer_id: "ctm_1", status: :active)

      assert %Subscription{type: :billing, billing_customer_id: "ctm_1", status: :active} =
               Teams.with_subscription(team).subscription
    end
  end

  describe "Teams.delete/1" do
    # Skipped until billing_interval is set by the schema (paddle-billing-interfaces)
    @tag :skip
    test "removes every Classic and Billing subscription and event of the team" do
      team = new_team() |> set_billing_customer_id("ctm_1")

      insert(:subscription,
        team: team,
        status: :deleted,
        inserted_at: ~N[2026-01-01 00:00:00]
      )

      insert(:subscription,
        team: team,
        status: :deleted,
        inserted_at: ~N[2026-02-01 00:00:00]
      )

      insert(:billing_subscription, team: team, billing_customer_id: "ctm_1", status: :deleted)

      Repo.insert!(%PaddleBilling.SubscriptionEvent{
        team_id: team.id,
        billing_event_id: "evt_1",
        billing_subscription_id: "sub_1",
        billing_customer_id: "ctm_1",
        billing_product_id: "pro_1",
        billing_price_id: "pri_1",
        next_bill_amount: "10.00",
        next_bill_date: Date.utc_today(),
        currency_code: "EUR",
        status: :active,
        original_event_type: :"subscription.created",
        original_event: %{},
        occurred_at: NaiveDateTime.utc_now()
      })

      assert {:ok, :deleted} = Teams.delete(team)

      refute Repo.exists?(from s in PaddleClassic.Subscription, where: s.team_id == ^team.id)
      refute Repo.exists?(from s in PaddleBilling.Subscription, where: s.team_id == ^team.id)
      refute Repo.exists?(from e in PaddleBilling.SubscriptionEvent, where: e.team_id == ^team.id)
    end
  end

  defp new_team() do
    {:ok, team} = Teams.get_or_create(new_user())
    team
  end

  defp set_billing_customer_id(team, customer_id) do
    team |> Ecto.Changeset.change(billing_customer_id: customer_id) |> Repo.update!()
  end
end
