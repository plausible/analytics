defmodule Plausible.Billing.PaddleBilling.WebhooksTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  use Bamboo.Test, shared: true

  @moduletag :ee_only

  import Plausible.Billing.PaddleBilling.WebhookFixtures

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.PaddleBilling.{SubscriptionEvent, WebhookFailure, Webhooks}
  alias Plausible.Billing.Plans
  alias Plausible.Billing.Subscription.Status

  alias Plausible.Teams

  @subscription_id "sub_01hv8x29kz0t586xy6zn1a62ny"
  @customer_id "ctm_01hv6y1jedq4p1n0yqn5ba3ky4"

  setup do
    user = new_user()
    {:ok, team} = Teams.get_or_create(user)
    {:ok, user: user, team: team}
  end

  describe "subscription.created" do
    test "stores the subscription for the team from custom data", %{team: team} do
      assert {:ok, :applied} = created(team)

      assert %{type: :billing} = subscription = Teams.with_subscription(team).subscription

      assert subscription.billing_subscription_id == @subscription_id
      assert subscription.billing_customer_id == @customer_id
      assert subscription.billing_product_id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription.billing_price_id == "pri_01gsz8x8sawmvhz1pv30nge1ke"
      assert subscription.status == Status.active()
      assert subscription.currency_code == "USD"
      assert subscription.next_bill_amount == "30.00"
      assert subscription.next_bill_date == ~D[2026-12-10]
      assert subscription.last_bill_date == ~D[2026-11-10]
    end

    @tag :skip_extra_billing_run
    test "makes the team's current subscription the Billing one", %{team: team} do
      insert(:subscription, team: team, paddle_plan_id: "classic-plan")

      assert Teams.with_subscription(team).subscription.type == :classic

      created(team)

      team = Teams.with_subscription(Repo.reload!(team))
      assert team.billing_customer_id == @customer_id
      assert team.subscription.type == :billing
      assert team.subscription.billing_subscription_id == @subscription_id
    end

    test "creates a personal team for the user given in custom data" do
      user = new_user()

      event =
        subscription_event("subscription.created",
          data: %{custom_data: %{"user_id" => user.id, "team_id" => 0}}
        )

      assert {:ok, :applied} = Webhooks.subscription_created(event)

      assert {:ok, personal_team} = Teams.get_by_owner(user)

      assert Teams.with_subscription(personal_team).subscription.billing_subscription_id ==
               @subscription_id
    end

    test "accepts ids sent as strings", %{team: team} do
      event =
        subscription_event("subscription.created",
          data: %{custom_data: %{"team_id" => "#{team.id}"}}
        )

      assert {:ok, :applied} = Webhooks.subscription_created(event)
    end

    test "lets the team accept traffic until after the next bill date", %{team: team} do
      created(team)

      assert Repo.reload!(team).accept_traffic_until ==
               Date.shift(~D[2026-12-10],
                 day: Teams.Team.subscription_accept_traffic_until_offset_days()
               )
    end

    test "removes the grace period", %{team: team} do
      Teams.start_grace_period(team)
      assert Repo.reload!(team).grace_period

      created(team)

      refute Repo.reload!(team).grace_period
    end

    test "records the event with its payload", %{team: team} do
      event = subscription_event("subscription.created", data: %{custom_data: custom_data(team)})
      assert {:ok, :applied} = Webhooks.subscription_created(event)

      assert %SubscriptionEvent{} =
               stored = Repo.get_by!(SubscriptionEvent, billing_event_id: event["event_id"])

      assert stored.team_id == team.id
      assert stored.original_event_type == :"subscription.created"
      assert stored.original_event == event
      assert stored.occurred_at == ~N[2026-11-10 10:00:00.000000]
      assert stored.status == Status.active()
    end

    test "replaces the previous subscription of the team", %{team: team} do
      created(team)

      assert {:ok, :applied} = created(team, id: "sub_second", customer_id: "ctm_second")

      assert %{billing_subscription_id: "sub_second", billing_customer_id: "ctm_second"} =
               Teams.with_subscription(team).subscription

      assert Repo.reload!(team).billing_customer_id == "ctm_second"
    end

    test "takes the interval from the price's billing cycle", %{team: team} do
      yearly = %{
        "id" => "pri_1",
        "product_id" => "pro_1",
        "unit_price" => %{"amount" => "3000", "currency_code" => "USD"},
        "billing_cycle" => %{"interval" => "year", "frequency" => 1}
      }

      created(team, items: [item(%{"price" => yearly})])

      subscription = Teams.with_subscription(team).subscription
      assert Plans.subscription_interval(subscription) == "yearly"
    end

    test "unlocks a locked team", %{team: team} do
      insert(:enterprise_plan,
        team: team,
        billing_product_id: "pro_ent",
        billing_price_id: "pri_ent"
      )

      team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

      assert {:ok, :applied} = created(team, items: [item(%{"price" => price("pro_ent")})])

      refute Repo.reload!(team).locked
    end

    test "sets the API request limit from the enterprise plan", %{team: team} do
      insert(:enterprise_plan,
        team: team,
        billing_product_id: "pro_ent",
        billing_price_id: "pri_ent",
        hourly_api_request_limit: 5000
      )

      assert {:ok, :applied} = created(team, items: [item(%{"price" => price("pro_ent")})])

      assert Repo.reload!(team).hourly_api_request_limit == 5000
    end

    test "rejects a billing cycle that is neither monthly nor yearly", %{team: team} do
      weekly = %{
        "id" => "pri_1",
        "product_id" => "pro_1",
        "unit_price" => %{"amount" => "3000", "currency_code" => "USD"},
        "billing_cycle" => %{"interval" => "week", "frequency" => 1}
      }

      assert {:error, {:unsupported_billing_cycle, _}} =
               created(team, items: [item(%{"price" => weekly})])
    end

    test "takes the amount from the override in the subscription's currency", %{team: team} do
      price = %{
        "id" => "pri_1",
        "product_id" => "pro_1",
        "unit_price" => %{"amount" => "3000", "currency_code" => "USD"},
        "unit_price_overrides" => [
          %{
            "country_codes" => ["DE"],
            "unit_price" => %{"amount" => "2750", "currency_code" => "EUR"}
          }
        ],
        "billing_cycle" => %{"interval" => "month", "frequency" => 1}
      }

      created(team, currency_code: "EUR", items: [item(%{"price" => price})])

      assert Teams.with_subscription(team).subscription.next_bill_amount == "27.50"
    end

    test "respects currencies without minor units and the item quantity", %{team: team} do
      price = %{
        "id" => "pri_1",
        "product_id" => "pro_1",
        "unit_price" => %{"amount" => "3000", "currency_code" => "JPY"},
        "billing_cycle" => %{"interval" => "month", "frequency" => 1}
      }

      created(team, currency_code: "JPY", items: [item(%{"price" => price, "quantity" => 2})])

      assert Teams.with_subscription(team).subscription.next_bill_amount == "6000"
    end

    test "ignores a duplicate delivery", %{team: team} do
      event = subscription_event("subscription.created", data: %{custom_data: custom_data(team)})

      assert {:ok, :applied} = Webhooks.subscription_created(event)
      assert {:ok, :duplicate} = Webhooks.subscription_created(event)

      assert Repo.aggregate(SubscriptionEvent, :count) == 1
      assert %{type: :billing} = Teams.with_subscription(team).subscription
    end

    test "does not create another personal team for a duplicate delivery", %{user: user} do
      event =
        subscription_event("subscription.created", data: %{custom_data: %{"user_id" => user.id}})

      assert {:ok, :applied} = Webhooks.subscription_created(event)
      teams_before = Repo.aggregate(Teams.Team, :count)

      assert {:ok, :duplicate} = Webhooks.subscription_created(event)
      assert Repo.aggregate(Teams.Team, :count) == teams_before
    end

    test "stores a scheduled cancellation as deleted until it takes effect", %{team: team} do
      created(team,
        scheduled_change: %{"action" => "cancel", "effective_at" => "2026-12-10T10:00:00Z"}
      )

      subscription = Teams.with_subscription(team).subscription
      assert subscription.status == Status.deleted()
      assert subscription.next_bill_date == ~D[2026-12-10]
    end

    test "rejects missing or unusable custom data" do
      for custom_data <- [nil, %{}, %{"team_id" => 0, "user_id" => 0}, %{"team_id" => "abc"}] do
        event = subscription_event("subscription.created", data: %{custom_data: custom_data})
        assert {:error, :invalid_custom_data} = Webhooks.subscription_created(event)
      end

      assert Repo.aggregate(Plausible.Billing.Subscription, :count) == 0
      assert Repo.aggregate(SubscriptionEvent, :count) == 0
    end

    test "keeps a failed event for inspection, without applying it" do
      event = subscription_event("subscription.created", data: %{custom_data: nil})

      assert {:error, :invalid_custom_data} = Webhooks.subscription_created(event)

      assert [failure] = Repo.all(WebhookFailure)
      assert failure.billing_event_id == event["event_id"]
      assert failure.event_type == "subscription.created"
      assert failure.payload == event
      assert failure.error == ":invalid_custom_data"
      assert Repo.aggregate(SubscriptionEvent, :count) == 0
    end

    test "keeps a malformed event that has no event id" do
      assert {:error, :invalid_event} = Webhooks.subscription_created(%{"foo" => "bar"})

      assert [%{billing_event_id: nil, payload: %{"foo" => "bar"}}] = Repo.all(WebhookFailure)
    end

    test "keeps nothing for applied events and duplicates", %{team: team} do
      event = subscription_event("subscription.created", data: %{custom_data: custom_data(team)})

      assert {:ok, :applied} = Webhooks.subscription_created(event)
      assert {:ok, :duplicate} = Webhooks.subscription_created(event)

      assert Repo.aggregate(WebhookFailure, :count) == 0
    end

    test "rejects unknown teams and users" do
      for custom_data <- [%{"team_id" => 999_999}, %{"user_id" => 999_999}] do
        event = subscription_event("subscription.created", data: %{custom_data: custom_data})
        assert {:error, error} = Webhooks.subscription_created(event)
        assert error in [:team_not_found, :user_not_found]
      end

      assert Repo.aggregate(Plausible.Billing.Subscription, :count) == 0
    end

    test "rejects unsupported statuses without storing anything", %{team: team} do
      assert {:error, {:unsupported_status, "trialing"}} = created(team, status: "trialing")

      refute Teams.with_subscription(team).subscription
      assert Repo.aggregate(SubscriptionEvent, :count) == 0
    end

    test "rejects malformed events" do
      assert {:error, :invalid_event} = Webhooks.subscription_created(%{"event_id" => "evt_1"})

      assert {:error, :invalid_event} =
               Webhooks.subscription_created(
                 subscription_event("subscription.created", data: %{items: []})
               )
    end
  end

  describe "subscription.updated" do
    setup %{team: team} do
      created(team)
      :ok
    end

    test "updates the subscription", %{team: team} do
      price = %{
        "id" => "pri_other",
        "product_id" => "pro_other",
        "unit_price" => %{"amount" => "9000", "currency_code" => "USD"},
        "billing_cycle" => %{"interval" => "year", "frequency" => 1}
      }

      assert {:ok, :applied} =
               updated(
                 items: [item(%{"price" => price})],
                 next_billed_at: "2027-11-10T10:00:00.000000Z",
                 current_billing_period: %{
                   "starts_at" => "2026-11-10T10:00:00.000000Z",
                   "ends_at" => "2027-11-10T10:00:00.000000Z"
                 }
               )

      subscription = Teams.with_subscription(team).subscription
      assert subscription.billing_price_id == "pri_other"
      assert subscription.billing_product_id == "pro_other"
      assert subscription.next_bill_amount == "90.00"
      assert subscription.next_bill_date == ~D[2027-11-10]
      assert subscription.last_bill_date == ~D[2026-11-10]
      assert Plans.subscription_interval(subscription) == "yearly"
    end

    test "moves accept_traffic_until along with the next bill date", %{team: team} do
      updated(next_billed_at: "2027-01-10T10:00:00.000000Z")

      assert Repo.reload!(team).accept_traffic_until ==
               Date.shift(~D[2027-01-10],
                 day: Teams.Team.subscription_accept_traffic_until_offset_days()
               )
    end

    for {paddle_status, status} <- [past_due: Status.past_due(), paused: Status.paused()] do
      test "maps #{paddle_status} to #{status}", %{team: team} do
        assert {:ok, :applied} = updated(status: unquote(to_string(paddle_status)))

        assert Teams.with_subscription(team).subscription.status == unquote(status)
      end
    end

    test "a scheduled cancellation keeps access until it takes effect and emails the team",
         %{user: user, team: team} do
      billing_member = new_user()
      add_member(team, user: billing_member, role: :billing)

      assert {:ok, :applied} =
               updated(
                 occurred_at: "2026-11-11T10:00:00.000000Z",
                 scheduled_change: %{
                   "action" => "cancel",
                   "effective_at" => "2026-12-10T10:00:00Z"
                 }
               )

      subscription = Teams.with_subscription(team).subscription
      assert subscription.status == Status.deleted()
      assert subscription.next_bill_date == ~D[2026-12-10]

      for recipient <- [user, billing_member] do
        assert_email_delivered_with(
          to: [nil: recipient.email],
          subject: "Where did Plausible fall short?"
        )
      end
    end

    test "emails about a cancellation only once", %{team: team} do
      cancel = %{"action" => "cancel", "effective_at" => "2026-12-10T10:00:00Z"}

      updated(occurred_at: "2026-11-11T10:00:00.000000Z", scheduled_change: cancel)
      assert_email_delivered_with(subject: "Where did Plausible fall short?")

      updated(occurred_at: "2026-11-12T10:00:00.000000Z", scheduled_change: cancel)
      refute_email_delivered_with(subject: "Where did Plausible fall short?")

      assert Teams.with_subscription(team).subscription.status == Status.deleted()
    end

    test "clearing the scheduled cancellation brings the subscription back to active", %{
      team: team
    } do
      cancel = %{"action" => "cancel", "effective_at" => "2026-12-10T10:00:00Z"}
      updated(occurred_at: "2026-11-11T10:00:00.000000Z", scheduled_change: cancel)

      updated(occurred_at: "2026-11-12T10:00:00.000000Z", scheduled_change: nil)

      subscription = Teams.with_subscription(team).subscription
      assert subscription.status == Status.active()
      assert subscription.next_bill_date == ~D[2026-12-10]
    end

    test "treats a scheduled pause as still active", %{team: team} do
      updated(scheduled_change: %{"action" => "pause", "effective_at" => "2026-12-10T10:00:00Z"})

      assert Teams.with_subscription(team).subscription.status == Status.active()
    end

    test "keeps a subscription deleted, valid until the date, once a scheduled cancellation takes effect",
         %{team: team} do
      cancel = %{"action" => "cancel", "effective_at" => "2026-12-10T10:00:00Z"}
      updated(occurred_at: "2026-11-11T10:00:00.000000Z", scheduled_change: cancel)

      assert {:ok, :applied} =
               updated(
                 occurred_at: "2026-12-10T10:00:05.000000Z",
                 status: "canceled",
                 next_billed_at: nil,
                 current_billing_period: nil,
                 scheduled_change: nil,
                 canceled_at: "2026-12-10T10:00:00.000000Z"
               )

      subscription = Teams.with_subscription(team).subscription
      assert subscription.status == Status.deleted()
      assert subscription.next_bill_date == ~D[2026-12-10]

      event = Repo.one!(from e in SubscriptionEvent, order_by: [desc: e.id], limit: 1)
      assert event.status == Status.deleted()
    end

    test "treats an immediate cancellation as deleted, valid until the cancellation date", %{
      team: team
    } do
      assert {:ok, :applied} =
               updated(
                 status: "canceled",
                 next_billed_at: nil,
                 current_billing_period: nil,
                 canceled_at: "2026-11-20T08:00:00.000000Z"
               )

      subscription = Teams.with_subscription(team).subscription
      assert subscription.status == Status.deleted()
      assert subscription.next_bill_date == ~D[2026-11-20]
    end

    test "locks a team with sites once the paid period is over", %{user: user, team: team} do
      team
      |> Ecto.Changeset.change(trial_expiry_date: Date.shift(Date.utc_today(), day: -10))
      |> Repo.update!()

      new_site(owner: user)

      assert {:ok, :applied} =
               updated(
                 occurred_at: "2026-11-11T10:00:00.000000Z",
                 status: "canceled",
                 next_billed_at: nil,
                 current_billing_period: nil,
                 canceled_at: "2026-11-11T10:00:00.000000Z"
               )

      assert Repo.reload!(team).locked
    end

    test "falls back to the event date when a paused subscription has no dates", %{team: team} do
      updated(
        status: "paused",
        next_billed_at: nil,
        current_billing_period: nil,
        occurred_at: "2026-11-15T10:00:00.000000Z"
      )

      assert Teams.with_subscription(team).subscription.next_bill_date == ~D[2026-11-15]
    end

    test "records but does not apply an event older than one already seen", %{team: team} do
      updated(occurred_at: "2026-11-12T10:00:00.000000Z", status: "past_due")

      assert {:ok, :stale} = updated(occurred_at: "2026-11-11T10:00:00.000000Z", status: "active")

      assert Teams.with_subscription(team).subscription.status == Status.past_due()
      assert Repo.aggregate(SubscriptionEvent, :count) == 3
    end

    test "ignores a duplicate delivery" do
      event = subscription_event("subscription.updated", data: %{status: "past_due"})

      assert {:ok, :applied} = Webhooks.subscription_updated(event)
      assert {:ok, :duplicate} = Webhooks.subscription_updated(event)

      assert Repo.aggregate(SubscriptionEvent, :count) == 2
    end

    test "fails for an unknown subscription and stores nothing, so that Paddle's retry can succeed" do
      events_before = Repo.aggregate(SubscriptionEvent, :count)
      event = subscription_event("subscription.updated", data: %{id: "sub_unknown"})

      assert {:error, :subscription_not_found} = Webhooks.subscription_updated(event)
      assert Repo.aggregate(SubscriptionEvent, :count) == events_before
    end
  end

  defp price(product_id) do
    %{
      "id" => "pri_ent",
      "product_id" => product_id,
      "unit_price" => %{"amount" => "3000", "currency_code" => "USD"},
      "billing_cycle" => %{"interval" => "month", "frequency" => 1}
    }
  end

  defp custom_data(team), do: %{"team_id" => team.id}

  defp created(team, data \\ []) do
    {occurred_at, data} = Keyword.pop(data, :occurred_at)
    data = data |> Map.new() |> Map.put(:custom_data, custom_data(team))

    "subscription.created"
    |> subscription_event(event_overrides(occurred_at, data))
    |> Webhooks.subscription_created()
  end

  defp updated(data) do
    {occurred_at, data} = Keyword.pop(data, :occurred_at)

    "subscription.updated"
    |> subscription_event(event_overrides(occurred_at, Map.new(data)))
    |> Webhooks.subscription_updated()
  end

  defp event_overrides(nil, data), do: [data: data]
  defp event_overrides(occurred_at, data), do: [data: data, occurred_at: occurred_at]
end
