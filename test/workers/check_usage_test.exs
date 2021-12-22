defmodule Plausible.Workers.CheckUsageTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Double
  import Plausible.TestUtils
  alias Plausible.Workers.CheckUsage

  setup [:create_user, :create_site]
  @paddle_id_10k "558018"

  test "ignores user without subscription" do
    CheckUsage.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with subscription but no usage", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period == nil
  end

  test "does not send an email if account has been over the limit for one billing month", %{
    user: user
  } do
    billing_stub =
      Plausible.Billing
      |> stub(:last_two_billing_cycles, fn _user ->
        {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
      end)
      |> stub(:last_two_billing_months_usage, fn _user -> {9_000, 11_000} end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, billing_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period == nil
  end

  test "does not send an email if account is over the limit by less than 10%", %{
    user: user
  } do
    billing_stub =
      Plausible.Billing
      |> stub(:last_two_billing_cycles, fn _user ->
        {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
      end)
      |> stub(:last_two_billing_months_usage, fn _user -> {10_999, 11_000} end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, billing_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period == nil
  end

  test "sends an email when an account is over their limit for two consecutive billing months", %{
    user: user
  } do
    billing_stub =
      Plausible.Billing
      |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
      |> stub(:last_two_billing_cycles, fn _user ->
        {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, billing_stub)

    assert_email_delivered_with(
      to: [user],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )

    assert Repo.reload(user).grace_period.end_date == Timex.shift(Timex.today(), days: 7)
  end

  test "skips checking users who already have a grace period", %{user: user} do
    Plausible.Auth.User.start_grace_period(user, 12_000) |> Repo.update()

    billing_stub =
      Plausible.Billing
      |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
      |> stub(:last_two_billing_cycles, fn _user ->
        {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, billing_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period.allowance_required == 12_000
  end

  test "reccommends a plan to upgrade to", %{
    user: user
  } do
    billing_stub =
      Plausible.Billing
      |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
      |> stub(:last_two_billing_cycles, fn _user ->
        {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, billing_stub)

    assert_delivered_email_matches(%{
      html_body: html_body
    })

    # Should find 2 visiors
    assert html_body =~ ~s(Based on that we recommend you select the 100k/mo plan.)
  end

  describe "enterprise customers" do
    test "checks billable pageview usage for enterprise customer, sends usage information to enterprise@plausible.io",
         %{
           user: user
         } do
      billing_stub =
        Plausible.Billing
        |> stub(:last_two_billing_months_usage, fn _user -> {1_100_000, 1_100_000} end)
        |> stub(:last_two_billing_cycles, fn _user ->
          {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
        end)

      enterprise_plan = insert(:enterprise_plan, user: user, monthly_pageview_limit: 1_000_000)

      insert(:subscription,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, billing_stub)

      assert_email_delivered_with(
        to: [{nil, "enterprise@plausible.io"}],
        subject: "#{user.email} has outgrown their enterprise plan"
      )
    end

    test "checks site limit for enterprise customer, sends usage information to enterprise@plausible.io",
         %{
           user: user
         } do
      billing_stub =
        Plausible.Billing
        |> stub(:last_two_billing_months_usage, fn _user -> {1, 1} end)
        |> stub(:last_two_billing_cycles, fn _user ->
          {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
        end)

      enterprise_plan = insert(:enterprise_plan, user: user, site_limit: 2)

      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])

      insert(:subscription,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, billing_stub)

      assert_email_delivered_with(
        to: [{nil, "enterprise@plausible.io"}],
        subject: "#{user.email} has outgrown their enterprise plan"
      )
    end
  end

  describe "timing" do
    test "checks usage one day after the last_bill_date", %{
      user: user
    } do
      billing_stub =
        Plausible.Billing
        |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
        |> stub(:last_two_billing_cycles, fn _user ->
          {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, billing_stub)

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] You have outgrown your Plausible subscription tier"
      )
    end

    test "does not check exactly one month after last_bill_date", %{
      user: user
    } do
      billing_stub =
        Plausible.Billing
        |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
        |> stub(:last_two_billing_cycles, fn _user ->
          {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: ~D[2021-03-28]
      )

      CheckUsage.perform(nil, billing_stub, ~D[2021-03-28])

      assert_no_emails_delivered()
    end

    test "for yearly subscriptions, checks usage multiple months + one day after the last_bill_date",
         %{
           user: user
         } do
      billing_stub =
        Plausible.Billing
        |> stub(:last_two_billing_months_usage, fn _user -> {11_000, 11_000} end)
        |> stub(:last_two_billing_cycles, fn _user ->
          {Date.range(Timex.today(), Timex.today()), Date.range(Timex.today(), Timex.today())}
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: ~D[2021-06-29]
      )

      CheckUsage.perform(nil, billing_stub, ~D[2021-08-30])

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] You have outgrown your Plausible subscription tier"
      )
    end
  end
end
