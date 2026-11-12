defmodule Plausible.Billing.BillingSubscriptionTest do
  @moduledoc """
  Everything that accepts a subscription must work the same for a Paddle
  Billing subscription (`type: :billing`) as for a Paddle Classic one.
  """

  use Plausible.DataCase
  use Bamboo.Test
  import Double
  import Phoenix.LiveViewTest, only: [render_component: 2]

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.PaddleBilling
  alias Plausible.Billing.Plans
  alias Plausible.Billing.SiteLocker
  alias Plausible.Billing.Subscription
  alias Plausible.Billing.Subscriptions
  alias Plausible.Teams
  alias Plausible.Workers.{CheckUsage, LockSites, NotifyAnnualRenewal}

  @moduletag :ee_only

  @date_range Date.range(Date.utc_today(), Date.utc_today())

  defp plan(generation, kind, limit) do
    Enum.find(
      Plans.all(),
      &(&1.generation == generation and &1.kind == kind and &1.monthly_pageview_limit == limit)
    )
  end

  defp growth_10k(), do: plan(4, :growth, 10_000)

  defp yesterday(), do: Date.shift(Date.utc_today(), day: -1)

  describe "static plan definitions" do
    test "every plan has Billing ids that are unique" do
      ids =
        Enum.flat_map(Plans.all(), fn plan ->
          [plan.billing_monthly_price_id, plan.billing_yearly_price_id]
          |> Enum.reject(&is_nil/1)
        end)

      assert ids != []
      assert ids == Enum.uniq(ids)
    end
  end

  describe "Plans" do
    test "resolves a regular plan from the monthly and the yearly price" do
      plan = growth_10k()

      monthly =
        subscription_of(new_user() |> subscribe_to_billing_plan(plan.billing_monthly_price_id))

      yearly =
        subscription_of(new_user() |> subscribe_to_billing_plan(plan.billing_yearly_price_id))

      assert %{type: :billing} = monthly
      assert Plans.get_subscription_plan(monthly) == plan
      assert Plans.get_subscription_plan(yearly) == plan
      assert Plans.get_regular_plan(monthly) == plan
      assert Plans.subscription_interval(monthly) == "monthly"
      assert Plans.subscription_interval(yearly) == "yearly"
    end

    test "resolves nothing from an unknown product" do
      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan("pri_unknown", billing_product_id: "pro_unknown")
        )

      assert Plans.get_subscription_plan(subscription) == nil
      assert Plans.get_regular_plan(subscription) == nil
      assert Plans.subscription_interval(subscription) == "N/A"
    end

    test "resolves a regular plan from the product when the price is not in the catalogue" do
      plan = growth_10k()

      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan("pri_imported",
            billing_product_id: plan.billing_product_id
          )
        )

      assert Plans.get_subscription_plan(subscription) == plan
    end

    test "does not resolve an enterprise plan of another product" do
      user = new_user() |> subscribe_to_billing_enterprise_plan()
      team = team_of(user)
      subscription = subscription_of(team)
      enterprise_plan = Plans.get_enterprise_plan(subscription)

      other_product = %{subscription | billing_product_id: "pro_other"}

      assert Plans.get_enterprise_plan(other_product) == nil
      refute Plans.subscribed_to?(other_product, enterprise_plan)
    end

    test "resolves the enterprise plan of the team from the product" do
      user =
        new_user()
        |> subscribe_to_billing_enterprise_plan(billing_interval: :yearly)

      team = team_of(user)
      subscription = subscription_of(team)

      assert %Plausible.Billing.EnterprisePlan{} =
               enterprise_plan = Plans.get_subscription_plan(subscription)

      assert enterprise_plan.team_id == team.id
      assert Plans.subscription_interval(subscription) == :yearly
      assert Plans.subscribed_to?(subscription, enterprise_plan)
    end

    test "does not resolve an enterprise plan of another team sharing the product" do
      user = new_user() |> subscribe_to_billing_enterprise_plan()
      subscription = user |> team_of() |> subscription_of()

      other_team = new_user() |> team_of_new()

      insert(:enterprise_plan,
        team: other_team,
        billing_product_id: subscription.billing_product_id,
        billing_price_id: "pri_other"
      )

      assert %{team_id: team_id} = Plans.get_subscription_plan(subscription)
      assert team_id == subscription.team_id
    end

    test "resolves a Classic subscription as before" do
      user = new_user() |> subscribe_to_growth_plan()

      assert %Plausible.Billing.Plan{kind: :growth} =
               Plans.get_subscription_plan(subscription_of(user |> team_of()))
    end

    test "offers plans of the same generation, as for a Classic subscription" do
      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id)
        )

      assert Plans.growth_plans_for(subscription) |> Enum.map(& &1.generation) |> Enum.uniq() == [
               4
             ]
    end

    test "ignores an expired subscription when asked to" do
      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id,
            status: Subscription.Status.deleted(),
            next_bill_date: yesterday()
          )
        )

      assert Plans.get_regular_plan(subscription, only_non_expired: true) == nil
      assert Plans.get_regular_plan(subscription) == growth_10k()
    end

    test "tells the business tier" do
      business = plan(5, :business, 10_000)

      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(business.billing_monthly_price_id)
        )

      assert Plans.business_tier?(subscription)

      refute Plans.business_tier?(
               subscription_of(new_user() |> subscribe_to_growth_plan() |> team_of())
             )
    end
  end

  describe "Subscriptions" do
    test "tell active, expired, resumable and halted Billing subscriptions" do
      price = growth_10k().billing_monthly_price_id

      active = subscription_of(new_user() |> subscribe_to_billing_plan(price))

      past_due =
        subscription_of(new_user() |> subscribe_to_billing_plan(price, status: :past_due))

      paused = subscription_of(new_user() |> subscribe_to_billing_plan(price, status: :paused))

      cancelled_paid =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(price,
            status: :deleted,
            next_bill_date: Date.shift(Date.utc_today(), day: 5)
          )
        )

      cancelled_expired =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(price, status: :deleted, next_bill_date: yesterday())
        )

      assert Subscriptions.active?(active)
      assert Subscriptions.active?(past_due)
      refute Subscriptions.active?(paused)
      assert Subscriptions.active?(cancelled_paid)
      refute Subscriptions.active?(cancelled_expired)

      refute Subscriptions.expired?(cancelled_paid)
      assert Subscriptions.expired?(cancelled_expired)

      assert Subscriptions.resumable?(active)
      refute Subscriptions.resumable?(cancelled_paid)
      assert Subscriptions.halted?(paused)
      refute Subscriptions.halted?(active)
    end
  end

  describe "Teams.Billing" do
    test "takes limits and features from the regular plan" do
      plan = growth_10k()
      user = new_user() |> subscribe_to_billing_plan(plan.billing_monthly_price_id)
      team = team_of(user)

      assert Teams.Billing.monthly_pageview_limit(team) == plan.monthly_pageview_limit
      assert Teams.Billing.site_limit(team) == plan.site_limit
      assert Teams.Billing.team_member_limit(team) == plan.team_member_limit

      assert Teams.Billing.allowed_features_for(team) --
               (plan.features -- [Plausible.Billing.Feature.StatsAPI]) == []
    end

    test "takes limits from the enterprise plan" do
      user =
        new_user()
        |> subscribe_to_billing_enterprise_plan(
          monthly_pageview_limit: 7_000_000,
          site_limit: 77,
          team_member_limit: 7
        )

      team = team_of(user)

      assert Teams.Billing.monthly_pageview_limit(team) == 7_000_000
      assert Teams.Billing.site_limit(team) == 77
      assert Teams.Billing.team_member_limit(team) == 7
    end

    test "changing the plan of a Billing subscription is unsupported (remove once implemented)" do
      user = new_user() |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id)
      team = team_of(user)
      subscription = subscription_of(team)
      new_plan = plan(4, :growth, 100_000)

      assert {:error, :change_plan_unsupported} =
               Teams.Billing.change_plan(team, new_plan.monthly_product_id)

      assert Repo.reload!(subscription) == subscription
    end

    test "accepts traffic until after the next bill date" do
      user = new_user() |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id)
      team = team_of(user)

      assert Teams.accept_traffic_until(team) ==
               Date.shift(Date.utc_today(),
                 day: Teams.Team.subscription_accept_traffic_until_offset_days()
               )
    end
  end

  describe "SiteLocker" do
    test "unlocks a locked team with an active Billing subscription" do
      user = new_user() |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id)
      new_site(owner: user)
      team = team_of(user)
      Repo.update_all(from(t in Teams.Team, where: t.id == ^team.id), set: [locked: true])

      assert SiteLocker.update_for(team) == :unlocked
      refute Repo.reload!(team).locked
    end

    test "locks a team whose cancelled Billing subscription has expired" do
      user =
        new_user()
        |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id,
          status: Subscription.Status.deleted(),
          next_bill_date: yesterday()
        )

      new_site(owner: user)
      team = team_of(user)

      assert {:locked, _} = SiteLocker.update_for(team)
      assert Repo.reload!(team).locked
    end

    test "LockSites worker applies the same rules" do
      user = new_user() |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id)
      new_site(owner: user)
      team = team_of(user)
      Repo.update_all(from(t in Teams.Team, where: t.id == ^team.id), set: [locked: true])

      assert :ok = LockSites.perform(nil)
      refute Repo.reload!(team).locked
    end
  end

  describe "SubscriptionState" do
    test "adjusts the API limit to the enterprise plan of a Billing subscription" do
      user = new_user() |> subscribe_to_billing_enterprise_plan(hourly_api_request_limit: 12_345)
      team = team_of(user)
      subscription = Repo.get_by!(PaddleBilling.Subscription, team_id: team.id)

      assert team.hourly_api_request_limit != 12_345

      Plausible.Billing.SubscriptionState.apply_subscription_state(subscription)

      assert Repo.reload!(team).hourly_api_request_limit == 12_345
    end
  end

  describe "workers" do
    test "CheckUsage starts a grace period for a regular Billing subscriber over the limit" do
      user =
        new_user()
        |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id,
          last_bill_date: yesterday()
        )

      usage_stub =
        Teams.Billing
        |> stub(:monthly_pageview_usage, fn _team ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      CheckUsage.perform(nil, usage_stub)

      assert Repo.reload!(team_of(user)).grace_period
    end

    test "CheckUsage alerts about an enterprise Billing subscriber over the limit" do
      user =
        new_user()
        |> subscribe_to_billing_enterprise_plan(
          monthly_pageview_limit: 1_000_000,
          subscription: [last_bill_date: yesterday()]
        )

      usage_stub =
        Teams.Billing
        |> stub(:monthly_pageview_usage, fn _team ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
            last_cycle: %{date_range: @date_range, total: 1_100_000}
          }
        end)

      CheckUsage.perform(nil, usage_stub)

      assert_email_delivered_with(
        to: [{nil, "enterprise@plausible.io"}],
        subject: "#{team_of(user).name} has outgrown their enterprise plan"
      )
    end

    test "NotifyAnnualRenewal reminds yearly Billing subscribers only" do
      plan = growth_10k()
      due = Date.shift(Date.utc_today(), day: 7)

      yearly =
        new_user() |> subscribe_to_billing_plan(plan.billing_yearly_price_id, next_bill_date: due)

      _monthly =
        new_user()
        |> subscribe_to_billing_plan(plan.billing_monthly_price_id, next_bill_date: due)

      enterprise_yearly =
        new_user()
        |> subscribe_to_billing_enterprise_plan(
          billing_interval: :yearly,
          subscription: [next_bill_date: due]
        )

      _enterprise_monthly =
        new_user()
        |> subscribe_to_billing_enterprise_plan(
          billing_interval: :monthly,
          subscription: [next_bill_date: due]
        )

      NotifyAnnualRenewal.perform(nil)

      assert Enum.sort(delivered_recipients("Your Plausible subscription is up for renewal")) ==
               Enum.sort([yearly.email, enterprise_yearly.email])
    end

    test "scheduled deletion picks up a churned Billing subscription" do
      team = insert(:team)
      new_site(team: team)

      subscribe_to_billing_plan(team, growth_10k().billing_monthly_price_id,
        status: :deleted,
        next_bill_date: Date.shift(Date.utc_today(), day: -1)
      )

      assert Plausible.TeamDeletionSchedules.sync_eligible(Date.utc_today()) == 1

      assert %{category: :churned_subscription} =
               Repo.get_by!(Plausible.TeamDeletionSchedule, team_id: team.id)
    end
  end

  describe "notices" do
    test "a past due Billing subscription has no link to update billing info" do
      subscription =
        subscription_of(
          new_user()
          |> subscribe_to_billing_plan(growth_10k().billing_monthly_price_id, status: :past_due)
        )

      html =
        render_component(
          &PlausibleWeb.Components.Billing.Notice.subscription_past_due/1,
          subscription: subscription
        )

      assert html =~ "There was a problem with your latest payment"
      refute html =~ "Update billing info"
    end
  end

  defp team_of_new(user) do
    {:ok, team} = Teams.get_or_create(user)
    team
  end

  defp delivered_recipients(subject, acc \\ []) do
    receive do
      {:delivered_email, %{subject: ^subject, to: [{_name, email}]}} ->
        delivered_recipients(subject, [email | acc])
    after
      0 -> acc
    end
  end
end
