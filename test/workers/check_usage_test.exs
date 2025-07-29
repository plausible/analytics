defmodule Plausible.Workers.CheckUsageTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test
  import Double

  alias Plausible.Workers.CheckUsage

  require Plausible.Billing.Subscription.Status

  setup [:create_user, :create_site]
  @paddle_id_10k "558018"
  @date_range Date.range(Timex.today(), Timex.today())

  @accepted_status_values [
    Plausible.Billing.Subscription.Status.active(),
    Plausible.Billing.Subscription.Status.past_due(),
    Plausible.Billing.Subscription.Status.deleted()
  ]

  test "ignores user without subscription" do
    CheckUsage.perform(nil)

    assert_no_emails_delivered()
  end

  test "operates on the current subscription",
       %{
         user: user
       } do
    usage_stub =
      Plausible.Teams.Billing
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    subscribe_to_plan(
      user,
      @paddle_id_10k,
      last_bill_date: Date.shift(Date.utc_today(), day: -1),
      status: :active
    )

    subscribe_to_plan(
      user,
      "wont-exist-should-crash",
      last_bill_date: Date.shift(Date.utc_today(), day: -1),
      inserted_at: DateTime.shift(DateTime.utc_now(), day: -2),
      status: :deleted
    )

    CheckUsage.perform(nil, usage_stub)

    assert_email_delivered_with(
      to: [user],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )
  end

  test "sends more than one email", %{user: user} do
    usage_stub =
      Plausible.Teams.Billing
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    user2 = new_user()
    new_site(owner: user2)

    for u <- [user, user2] do
      subscribe_to_plan(
        u,
        @paddle_id_10k,
        last_bill_date: Date.shift(Date.utc_today(), day: -1),
        next_bill_date: Date.shift(Date.utc_today(), day: +5),
        status: :active
      )
    end

    CheckUsage.perform(nil, usage_stub)

    assert_email_delivered_with(
      to: [user],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )

    assert_email_delivered_with(
      to: [user2],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )
  end

  test "sends emails to billing members if available", %{user: user} do
    usage_stub =
      Plausible.Teams.Billing
      |> stub(:monthly_pageview_usage, fn _user ->
        %{
          penultimate_cycle: %{date_range: @date_range, total: 11_000},
          last_cycle: %{date_range: @date_range, total: 11_000}
        }
      end)

    user2 = new_user()
    user3 = new_user()
    new_site(owner: user)
    team = team_of(user)

    add_member(team, user: user2, role: :billing)
    add_member(team, user: user3, role: :viewer)

    subscribe_to_plan(
      user,
      @paddle_id_10k,
      last_bill_date: Date.shift(Date.utc_today(), day: -1),
      next_bill_date: Date.shift(Date.utc_today(), day: +5),
      status: :active
    )

    CheckUsage.perform(nil, usage_stub)

    assert_email_delivered_with(
      to: [user],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )

    assert_email_delivered_with(
      to: [user2],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )

    refute_email_delivered_with(
      to: [user3],
      subject: "[Action required] You have outgrown your Plausible subscription tier"
    )
  end

  test "ignores user with paused subscription", %{user: user} do
    subscribe_to_plan(
      user,
      @paddle_id_10k,
      last_bill_date: Timex.shift(Timex.today(), days: -1),
      status: Plausible.Billing.Subscription.Status.paused()
    )

    CheckUsage.perform(nil)

    assert_no_emails_delivered()
  end

  for status <- @accepted_status_values do
    describe "#{status} subscription, regular customers" do
      test "ignores user with subscription but no usage", %{user: user} do
        subscribe_to_plan(user, @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil)

        assert_no_emails_delivered()
        assert Repo.reload(team_of(user)).grace_period == nil
      end

      test "does not send an email if account has been over the limit for one billing month", %{
        user: user
      } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 9_000},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(user, @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_no_emails_delivered()
        assert Repo.reload(team_of(user)).grace_period == nil
      end

      test "does not send an email if account is over the limit by less than 10%", %{
        user: user
      } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 10_999},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(user, @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_no_emails_delivered()
        assert Repo.reload(team_of(user)).grace_period == nil
      end

      test "sends an email when an account is over their limit for two consecutive billing months",
           %{
             user: user
           } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(
          user,
          @paddle_id_10k,
          last_bill_date: Date.shift(Date.utc_today(), day: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_email_delivered_with(
          to: [user],
          subject: "[Action required] You have outgrown your Plausible subscription tier"
        )

        assert Repo.reload(team_of(user)).grace_period.end_date ==
                 Timex.shift(Timex.today(), days: 7)
      end

      test "sends an email suggesting enterprise plan when usage is greater than 10M ", %{
        user: user
      } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000_000},
              last_cycle: %{date_range: @date_range, total: 11_000_000}
            }
          end)

        subscribe_to_plan(
          user,
          @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_delivered_email_matches(%{html_body: html_body})

        assert html_body =~
                 "Your usage exceeds our standard plans, so please reply back to this email for a tailored quote"
      end

      test "skips checking users who already have a grace period", %{user: user} do
        %{grace_period: existing_grace_period} = Plausible.Teams.start_grace_period(team_of(user))

        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(user, @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_no_emails_delivered()
        assert Repo.reload(team_of(user)).grace_period.id == existing_grace_period.id
      end

      test "recommends a plan to upgrade to", %{
        user: user
      } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(
          user,
          @paddle_id_10k,
          last_bill_date: Timex.shift(Timex.today(), days: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)

        assert_delivered_email_matches(%{
          html_body: html_body
        })

        assert html_body =~ "We recommend you upgrade to the 100k pageviews/month plan"
      end

      test "clears grace period when plan is applicable again", %{user: user} do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000},
              last_cycle: %{date_range: @date_range, total: 11_000}
            }
          end)

        subscribe_to_plan(
          user,
          @paddle_id_10k,
          last_bill_date: Date.shift(Date.utc_today(), day: -1),
          status: unquote(status)
        )

        CheckUsage.perform(nil, usage_stub)
        assert user |> team_of() |> Repo.reload() |> Plausible.Teams.GracePeriod.active?()

        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 11_000},
              last_cycle: %{date_range: @date_range, total: 9_000}
            }
          end)

        CheckUsage.perform(nil, usage_stub)
        refute user |> team_of() |> Repo.reload() |> Plausible.Teams.GracePeriod.active?()
      end
    end
  end

  for status <- @accepted_status_values do
    describe "#{status} subscription, enterprise customers" do
      test "skips checking enterprise users who already have a grace period", %{user: user} do
        %{grace_period: existing_grace_period} =
          Plausible.Teams.start_manual_lock_grace_period(team_of(user))

        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
              last_cycle: %{date_range: @date_range, total: 1_100_000}
            }
          end)

        subscribe_to_enterprise_plan(user,
          monthly_pageview_limit: 1_000_000,
          subscription: [
            last_bill_date: Timex.shift(Timex.today(), days: -1),
            status: unquote(status)
          ]
        )

        CheckUsage.perform(nil, usage_stub)

        assert_no_emails_delivered()
        assert Repo.reload(team_of(user)).grace_period.id == existing_grace_period.id
      end

      test "checks billable pageview usage for enterprise customer, sends usage information to enterprise@plausible.io",
           %{
             user: user
           } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
              last_cycle: %{date_range: @date_range, total: 1_100_000}
            }
          end)

        subscribe_to_enterprise_plan(
          user,
          monthly_pageview_limit: 1_000_000,
          subscription: [
            last_bill_date: Timex.shift(Timex.today(), days: -1),
            status: unquote(status)
          ]
        )

        CheckUsage.perform(nil, usage_stub)

        assert_email_delivered_with(
          to: [{nil, "enterprise@plausible.io"}],
          subject: "#{user.email} has outgrown their enterprise plan"
        )
      end

      test "will only check usage if enterprise plan matches subscription's paddle plan id",
           %{
             user: user
           } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
              last_cycle: %{date_range: @date_range, total: 1_100_000}
            }
          end)

        subscribe_to_enterprise_plan(
          user,
          monthly_pageview_limit: 1_000_000,
          subscription: [
            last_bill_date: Timex.shift(Timex.today(), days: -1),
            status: unquote(status),
            # non-matching ID
            paddle_plan_id: @paddle_id_10k
          ]
        )

        CheckUsage.perform(nil, usage_stub)

        refute_email_delivered_with(
          to: [{nil, "enterprise@plausible.io"}],
          subject: "#{user.email} has outgrown their enterprise plan"
        )
      end

      test "checks site limit for enterprise customer, sends usage information to enterprise@plausible.io",
           %{
             user: user
           } do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 1},
              last_cycle: %{date_range: @date_range, total: 1}
            }
          end)

        subscribe_to_enterprise_plan(user,
          site_limit: 2,
          subscription: [
            last_bill_date: Timex.shift(Timex.today(), days: -1),
            status: unquote(status)
          ]
        )

        new_site(owner: user)
        new_site(owner: user)
        new_site(owner: user)

        CheckUsage.perform(nil, usage_stub)

        assert_email_delivered_with(
          to: [{nil, "enterprise@plausible.io"}],
          subject: "#{user.email} has outgrown their enterprise plan"
        )
      end

      test "starts grace period when plan is outgrown", %{user: user} do
        usage_stub =
          Plausible.Teams.Billing
          |> stub(:monthly_pageview_usage, fn _user ->
            %{
              penultimate_cycle: %{date_range: @date_range, total: 1_100_000},
              last_cycle: %{date_range: @date_range, total: 1_100_000}
            }
          end)

        subscribe_to_enterprise_plan(
          user,
          monthly_pageview_limit: 1_000_000,
          subscription: [
            last_bill_date: Timex.shift(Timex.today(), days: -1),
            status: unquote(status)
          ]
        )

        CheckUsage.perform(nil, usage_stub)
        assert user |> team_of() |> Repo.reload() |> Plausible.Teams.GracePeriod.active?()
      end
    end
  end

  describe "timing" do
    test "checks usage one day after the last_bill_date", %{
      user: user
    } do
      usage_stub =
        Plausible.Teams.Billing
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      subscribe_to_plan(
        user,
        @paddle_id_10k,
        last_bill_date: Date.shift(Date.utc_today(), day: -1)
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
        Plausible.Teams.Billing
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      subscribe_to_plan(user, @paddle_id_10k, last_bill_date: ~D[2021-03-28])

      CheckUsage.perform(nil, usage_stub, ~D[2021-03-28])

      assert_no_emails_delivered()
    end

    test "for yearly subscriptions, checks usage multiple months + one day after the last_bill_date",
         %{
           user: user
         } do
      usage_stub =
        Plausible.Teams.Billing
        |> stub(:monthly_pageview_usage, fn _user ->
          %{
            penultimate_cycle: %{date_range: @date_range, total: 11_000},
            last_cycle: %{date_range: @date_range, total: 11_000}
          }
        end)

      subscribe_to_plan(
        user,
        @paddle_id_10k,
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
