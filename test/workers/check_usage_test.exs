defmodule Plausible.Workers.CheckUsageTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  import Double

  alias Plausible.Workers.CheckUsage

  setup [:create_user, :create_site]
  @paddle_id_10k "558018"
  @date_range Date.range(Timex.today(), Timex.today())

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
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 9_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period == nil
  end

  test "does not send an email if account is over the limit by less than 10%", %{
    user: user
  } do
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 10_999},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period == nil
  end

  test "sends an email when an account is over their limit for two consecutive billing months", %{
    user: user
  } do
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_email_delivered_with(
      to: [user],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )

    assert Repo.reload(user).grace_period.end_date == Timex.shift(Timex.today(), days: 7)
  end

  test "sends an email suggesting enterprise plan when usage is greater than 10M ", %{
    user: user
  } do
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000_000},
          last_cycle: %{date_range: @date_range, total: 11_000_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_delivered_email_matches(%{html_body: html_body})

    assert html_body =~
             "Your usage exceeds our standard plans, so please reply back to this email for a tailored quote"
  end

  test "skips checking users who already have a grace period", %{user: user} do
    %{grace_period: existing_grace_period} =
      user
      |> Plausible.Auth.GracePeriod.start_changeset()
      |> Repo.update!()

    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_no_emails_delivered()
    assert Repo.reload(user).grace_period.id == existing_grace_period.id
  end

  test "recommends a plan to upgrade to", %{
    user: user
  } do
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)

    assert_delivered_email_matches(%{
      html_body: html_body
    })

    assert html_body =~ "We recommend you upgrade to the 100k/mo plan"
  end

  test "clears grace period when plan is applicable again", %{user: user} do
    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    insert(:subscription,
      user: user,
      paddle_plan_id: @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1)
    )

    CheckUsage.perform(nil, usage_stub)
    assert user |> Repo.reload() |> Plausible.Auth.GracePeriod.active?()

    usage_stub =
      Plausible.Billing.Quota.Usage
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 9_000}
        }
      end)

    CheckUsage.perform(nil, usage_stub)
    refute user |> Repo.reload() |> Plausible.Auth.GracePeriod.active?()
  end

  describe "enterprise customers" do
    test "skips checking enterprise users who already have a grace period", %{user: user} do
      %{grace_period: existing_grace_period} =
        user
        |> Plausible.Auth.GracePeriod.start_manual_lock_changeset()
        |> Repo.update!()

      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
            last_cycle: %{date_range: @date_range, total: 1_100_000}
          }
        end)

      enterprise_plan = insert(:enterprise_plan, user: user, monthly_pageview_limit: 1_000_000)

      insert(:subscription,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, usage_stub)

      assert_no_emails_delivered()
      assert Repo.reload(user).grace_period.id == existing_grace_period.id
    end

    test "checks billable pageview usage for enterprise customer, sends usage information to enterprise@plausible.io",
         %{
           user: user
         } do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
            last_cycle: %{date_range: @date_range, total: 1_100_000}
          }
        end)

      enterprise_plan = insert(:enterprise_plan, user: user, monthly_pageview_limit: 1_000_000)

      insert(:subscription,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, usage_stub)

      assert_email_delivered_with(
        to: [{nil, "enterprise@plausible.io"}],
        subject: "#{user.email} has outgrown their enterprise plan"
      )
    end

    test "checks site limit for enterprise customer, sends usage information to enterprise@plausible.io",
         %{
           user: user
         } do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 1},
            last_cycle: %{date_range: @date_range, total: 1}
          }
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

      CheckUsage.perform(nil, usage_stub)

      assert_email_delivered_with(
        to: [{nil, "enterprise@plausible.io"}],
        subject: "#{user.email} has outgrown their enterprise plan"
      )
    end

    test "starts grace period when plan is outgrown", %{user: user} do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
            last_cycle: %{date_range: @date_range, total: 1_100_000}
          }
        end)

      enterprise_plan = insert(:enterprise_plan, user: user, monthly_pageview_limit: 1_000_000)

      insert(:subscription,
        user: user,
        paddle_plan_id: enterprise_plan.paddle_plan_id,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, usage_stub)
      assert user |> Repo.reload() |> Plausible.Auth.GracePeriod.active?()
    end
  end

  describe "timing" do
    test "checks usage one day after the last_bill_date", %{
      user: user
    } do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      CheckUsage.perform(nil, usage_stub)

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] You have outgrown your Plausible subscription tier"
      )
    end

    test "does not check exactly one month after last_bill_date", %{
      user: user
    } do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: ~D[2021-03-28]
      )

      CheckUsage.perform(nil, usage_stub, ~D[2021-03-28])

      assert_no_emails_delivered()
    end

    test "for yearly subscriptions, checks usage multiple months + one day after the last_bill_date",
         %{
           user: user
         } do
      usage_stub =
        Plausible.Billing.Quota.Usage
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      insert(:subscription,
        user: user,
        paddle_plan_id: @paddle_id_10k,
        last_bill_date: ~D[2021-06-29]
      )

      CheckUsage.perform(nil, usage_stub, ~D[2021-08-30])

      assert_email_delivered_with(
        to: [user],
        subject: "[Action required] You have outgrown your Plausible subscription tier"
      )
    end
  end
end
