defmodule PlausibleWeb.SettingsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Bamboo.Test
  use Plausible.Repo
  use Plausible.Teams.Test

  import Mox
  import Plausible.Test.Support.HTML
  import Ecto.Query

  require Plausible.Billing.Subscription.Status

  alias Plausible.Auth
  alias Plausible.Billing.Subscription

  @v3_plan_id "749355"
  @v4_plan_id "857097"
  @configured_enterprise_plan_paddle_plan_id "123"

  setup [:verify_on_exit!]

  describe "GET /billing/subscription" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "shows subscription", %{conn: conn, user: user} do
      subscribe_to_plan(user, "558018")
      conn = get(conn, Routes.settings_path(conn, :subscription))
      assert html_response(conn, 200) =~ "10k pageviews"
      assert html_response(conn, 200) =~ "monthly billing"
    end

    @tag :ee_only
    test "shows yearly subscription", %{conn: conn, user: user} do
      subscribe_to_plan(user, "590752")
      conn = get(conn, Routes.settings_path(conn, :subscription))
      assert html_response(conn, 200) =~ "100k pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    @tag :ee_only
    test "shows free subscription", %{conn: conn, user: user} do
      subscribe_to_plan(user, "free_10k")
      conn = get(conn, Routes.settings_path(conn, :subscription))
      assert html_response(conn, 200) =~ "10k pageviews"
      assert html_response(conn, 200) =~ "N/A billing"
    end

    @tag :ee_only
    test "shows enterprise plan subscription", %{conn: conn, user: user} do
      configure_enterprise_plan(user)

      conn = get(conn, Routes.settings_path(conn, :subscription))
      assert html_response(conn, 200) =~ "20M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    @tag :ee_only
    test "shows current enterprise plan subscription when user has a new one to upgrade to", %{
      conn: conn,
      user: user
    } do
      configure_enterprise_plan(user)

      subscribe_to_enterprise_plan(user,
        paddle_plan_id: "1234",
        monthly_pageview_limit: 10_000_000,
        billing_interval: :yearly,
        subscription?: false
      )

      conn = get(conn, Routes.settings_path(conn, :subscription))
      assert html_response(conn, 200) =~ "20M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    @tag :ee_only
    test "renders two links to '/billing/choose-plan` with the text 'Upgrade'", %{conn: conn} do
      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      upgrade_link_1 = find(doc, "#monthly-quota-box a")
      upgrade_link_2 = find(doc, "#upgrade-link-2")

      assert text(upgrade_link_1) == "Upgrade"
      assert text_of_attr(upgrade_link_1, "href") == Routes.billing_path(conn, :choose_plan)

      assert text(upgrade_link_2) == "Upgrade"
      assert text_of_attr(upgrade_link_2, "href") == Routes.billing_path(conn, :choose_plan)
    end

    @tag :ee_only
    test "renders a link to '/billing/choose-plan' with the text 'Change plan' + cancel link", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, @v3_plan_id)

      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-link-2")
      assert doc =~ "Cancel my subscription"

      change_plan_link = find(doc, "#monthly-quota-box a")

      assert text(change_plan_link) == "Change plan"
      assert text_of_attr(change_plan_link, "href") == Routes.billing_path(conn, :choose_plan)
    end

    test "/billing/choose-plan link does not show up when enterprise subscription is past_due", %{
      conn: conn,
      user: user
    } do
      configure_enterprise_plan(user, subscription: [status: Subscription.Status.past_due()])

      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-or-change-plan-link")
    end

    test "/billing/choose-plan link does not show up when enterprise subscription is paused", %{
      conn: conn,
      user: user
    } do
      configure_enterprise_plan(user, subscription: [status: Subscription.Status.paused()])

      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-or-change-plan-link")
    end

    @tag :ee_only
    test "renders two links to '/billing/choose-plan' with the text 'Upgrade' for a configured enterprise plan",
         %{conn: conn, user: user} do
      subscribe_to_enterprise_plan(user,
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
        monthly_pageview_limit: 20_000_000,
        billing_interval: :yearly,
        subscription?: false
      )

      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      upgrade_link_1 = find(doc, "#monthly-quota-box a")
      upgrade_link_2 = find(doc, "#upgrade-link-2")

      assert text(upgrade_link_1) == "Upgrade"

      assert text_of_attr(upgrade_link_1, "href") ==
               Routes.billing_path(conn, :choose_plan)

      assert text(upgrade_link_2) == "Upgrade"

      assert text_of_attr(upgrade_link_2, "href") ==
               Routes.billing_path(conn, :choose_plan)
    end

    @tag :ee_only
    test "links to '/billing/choose-plan' with the text 'Change plan' for a configured enterprise plan with an existing subscription + renders cancel button",
         %{conn: conn, user: user} do
      configure_enterprise_plan(user)

      doc =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-link-2")
      assert doc =~ "Cancel my subscription"

      change_plan_link = find(doc, "#monthly-quota-box a")

      assert text(change_plan_link) == "Change plan"

      assert text_of_attr(change_plan_link, "href") ==
               Routes.billing_path(conn, :choose_plan)
    end

    @tag :ee_only
    test "renders cancelled subscription notice", %{conn: conn, user: user} do
      subscribe_to_plan(
        user,
        @v4_plan_id,
        status: :deleted,
        next_bill_date: ~D[2023-01-01]
      )

      notice_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#global-subscription-cancelled-notice")

      assert notice_text =~ "Subscription cancelled"
      assert notice_text =~ "Upgrade your subscription to get access to your stats again"
    end

    @tag :ee_only
    test "renders cancelled subscription notice with some subscription days still left", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, @v4_plan_id,
        status: :deleted,
        next_bill_date: Date.shift(Date.utc_today(), day: 10)
      )

      notice_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#global-subscription-cancelled-notice")

      assert notice_text =~ "Subscription cancelled"
      assert notice_text =~ "You have access to your stats until"
      assert notice_text =~ "Upgrade your subscription to make sure you don't lose access"
    end

    @tag :ee_only
    test "renders cancelled subscription notice with a warning about losing grandfathering", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(
        user,
        @v3_plan_id,
        status: :deleted,
        next_bill_date: Date.shift(Date.utc_today(), day: 10)
      )

      notice_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#global-subscription-cancelled-notice")

      assert notice_text =~ "Subscription cancelled"
      assert notice_text =~ "You have access to your stats until"

      assert notice_text =~
               "by letting your subscription expire, you lose access to our grandfathered terms"
    end

    test "does not show invoice section for a user with no subscription", %{conn: conn} do
      conn = get(conn, Routes.settings_path(conn, :invoices))
      assert html_response(conn, 200) =~ "No invoices issued yet"
    end

    @tag :ee_only
    test "renders pageview usage for current, last, and penultimate billing cycles", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)

      populate_stats(site, [
        build(:event, name: "pageview", timestamp: Timex.shift(Timex.now(), days: -5)),
        build(:event, name: "customevent", timestamp: Timex.shift(Timex.now(), days: -20)),
        build(:event, name: "pageview", timestamp: Timex.shift(Timex.now(), days: -50)),
        build(:event, name: "customevent", timestamp: Timex.shift(Timex.now(), days: -50))
      ])

      last_bill_date = Timex.shift(Timex.today(), days: -10)

      subscribe_to_plan(user, @v4_plan_id, last_bill_date: last_bill_date, status: :deleted)

      html =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      assert text_of_element(html, "#billing_cycle_tab_current_cycle") =~
               Date.range(
                 last_bill_date,
                 Timex.shift(last_bill_date, months: 1, days: -1)
               )
               |> PlausibleWeb.TextHelpers.format_date_range()

      assert text_of_element(html, "#billing_cycle_tab_last_cycle") =~
               Date.range(
                 Timex.shift(last_bill_date, months: -1),
                 Timex.shift(last_bill_date, days: -1)
               )
               |> PlausibleWeb.TextHelpers.format_date_range()

      assert text_of_element(html, "#billing_cycle_tab_penultimate_cycle") =~
               Date.range(
                 Timex.shift(last_bill_date, months: -2),
                 Timex.shift(last_bill_date, months: -1, days: -1)
               )
               |> PlausibleWeb.TextHelpers.format_date_range()

      assert text_of_element(html, "#total_pageviews_current_cycle") =~
               "Total billable pageviews 1"

      assert text_of_element(html, "#pageviews_current_cycle") =~ "Pageviews 1"
      assert text_of_element(html, "#custom_events_current_cycle") =~ "Custom events 0"

      assert text_of_element(html, "#total_pageviews_last_cycle") =~
               "Total billable pageviews 1 / 10,000"

      assert text_of_element(html, "#pageviews_last_cycle") =~ "Pageviews 0"
      assert text_of_element(html, "#custom_events_last_cycle") =~ "Custom events 1"

      assert text_of_element(html, "#total_pageviews_penultimate_cycle") =~
               "Total billable pageviews 2 / 10,000"

      assert text_of_element(html, "#pageviews_penultimate_cycle") =~ "Pageviews 1"
      assert text_of_element(html, "#custom_events_penultimate_cycle") =~ "Custom events 1"
    end

    @tag :ee_only
    test "renders pageview usage per billing cycle for active subscribers", %{
      conn: conn,
      user: user
    } do
      assert_cycles_rendered = fn doc ->
        refute element_exists?(doc, "#total_pageviews_last_30_days")

        assert element_exists?(doc, "#total_pageviews_current_cycle")
        assert element_exists?(doc, "#total_pageviews_last_cycle")
        assert element_exists?(doc, "#total_pageviews_penultimate_cycle")
      end

      subscribe_to_plan(user, @v4_plan_id,
        status: :active,
        last_bill_date: Timex.shift(Timex.now(), months: -6)
      )

      subscription =
        user
        |> team_of()
        |> Plausible.Teams.with_subscription()
        |> Map.fetch!(:subscription)

      get(conn, Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_cycles_rendered.()

      # for a past_due subscription
      subscription =
        subscription
        |> Plausible.Billing.Subscription.changeset(%{status: :past_due})
        |> Repo.update!()

      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_cycles_rendered.()

      # for a deleted (but not expired) subscription
      subscription
      |> Plausible.Billing.Subscription.changeset(%{
        status: :deleted,
        next_bill_date: Timex.shift(Timex.now(), months: 6)
      })
      |> Repo.update!()

      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_cycles_rendered.()
    end

    @tag :ee_only
    test "penultimate cycle is disabled if there's no usage", %{conn: conn, user: user} do
      site = new_site(owner: user)

      populate_stats(site, [
        build(:event, name: "pageview", timestamp: Timex.shift(Timex.now(), days: -5)),
        build(:event, name: "customevent", timestamp: Timex.shift(Timex.now(), days: -20))
      ])

      last_bill_date = Timex.shift(Timex.today(), days: -10)

      subscribe_to_plan(user, @v4_plan_id, last_bill_date: last_bill_date)

      html =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      assert class_of_element(html, "#billing_cycle_tab_penultimate_cycle button") =~
               "pointer-events-none"

      assert text_of_element(html, "#billing_cycle_tab_penultimate_cycle") =~ "Not available"
    end

    @tag :ee_only
    test "last cycle tab is selected by default", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, @v4_plan_id, last_bill_date: Timex.shift(Timex.today(), days: -1))

      html =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)

      assert text_of_attr(find(html, "#monthly_pageview_usage_container"), "x-data") ==
               "{ tab: 'last_cycle' }"
    end

    @tag :ee_only
    test "renders last 30 days pageview usage for trials and non-active/free_10k subscriptions",
         %{
           conn: conn,
           user: user
         } do
      site = new_site(owner: user)

      populate_stats(site, [
        build(:event, name: "pageview", timestamp: Timex.shift(Timex.now(), days: -1)),
        build(:event, name: "customevent", timestamp: Timex.shift(Timex.now(), days: -10)),
        build(:event, name: "customevent", timestamp: Timex.shift(Timex.now(), days: -20))
      ])

      assert_usage = fn doc ->
        refute element_exists?(doc, "#total_pageviews_current_cycle")

        assert text_of_element(doc, "#total_pageviews_last_30_days") =~
                 "Total billable pageviews (last 30 days) 3"

        assert text_of_element(doc, "#pageviews_last_30_days") =~ "Pageviews 1"
        assert text_of_element(doc, "#custom_events_last_30_days") =~ "Custom events 2"
      end

      # for a trial user
      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_usage.()

      subscribe_to_plan(user, @v4_plan_id,
        status: :deleted,
        last_bill_date: ~D[2022-01-01],
        next_bill_date: ~D[2022-02-01]
      )

      subscription =
        user
        |> team_of()
        |> Plausible.Teams.with_subscription()
        |> Map.fetch!(:subscription)

      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_usage.()

      # for a paused subscription
      subscription =
        subscription
        |> Plausible.Billing.Subscription.changeset(%{status: :paused})
        |> Repo.update!()

      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_usage.()

      # for a free_10k subscription (without a `last_bill_date`)
      Repo.delete!(subscription)

      user
      |> team_of()
      |> Plausible.Billing.Subscription.free()
      |> Repo.insert!()

      conn
      |> get(Routes.settings_path(conn, :subscription))
      |> html_response(200)
      |> assert_usage.()
    end

    @tag :ee_only
    test "renders sites usage and limit", %{conn: conn, user: user} do
      subscribe_to_plan(user, @v3_plan_id)
      new_site(owner: user)

      site_usage_row_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#site-usage-row")

      assert site_usage_row_text =~ "Owned sites 1 / 50"
    end

    @tag :ee_only
    test "renders team members usage and limit", %{conn: conn, user: user} do
      subscribe_to_plan(user, @v4_plan_id)

      team_member_usage_row_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#team-member-usage-row")

      assert team_member_usage_row_text =~ "Team members 0 / 3"
    end

    @tag :ee_only
    test "renders team member usage without limit if it's unlimited", %{conn: conn, user: user} do
      subscribe_to_plan(user, @v3_plan_id)

      team_member_usage_row_text =
        conn
        |> get(Routes.settings_path(conn, :subscription))
        |> html_response(200)
        |> text_of_element("#team-member-usage-row")

      assert team_member_usage_row_text == "Team members 0"
    end
  end

  describe "GET /billing/invoices" do
    setup [:create_user, :log_in]

    test "does not show invoice section for a free subscription", %{conn: conn, user: user} do
      new_site(owner: user)

      user
      |> team_of()
      |> Plausible.Billing.Subscription.free(%{currency_code: "EUR"})
      |> Repo.insert!()

      html =
        conn
        |> get(Routes.settings_path(conn, :invoices))
        |> html_response(200)

      assert html =~ "No invoices issued yet"
    end

    @tag :ee_only
    test "shows invoices for subscribed user", %{conn: conn, user: user} do
      subscribe_to_plan(user, "558018")

      html =
        conn
        |> get(Routes.settings_path(conn, :invoices))
        |> html_response(200)

      assert html =~ "Dec 24, 2020"
      assert html =~ "€11.11"
      assert html =~ "Nov 24, 2020"
      assert html =~ "$22.00"
    end

    @tag :ee_only
    test "shows message on failed invoice request'", %{conn: conn, user: user} do
      subscribe_to_plan(user, "558018", paddle_subscription_id: "invalid_subscription_id")

      html =
        conn
        |> get(Routes.settings_path(conn, :invoices))
        |> html_response(200)

      assert html =~ "Invoices"
      assert text(html) =~ "We couldn't retrieve your invoices"
    end
  end

  describe "GET /security" do
    setup [:create_user, :log_in]

    test "renders 2FA section in disabled state", %{conn: conn} do
      conn = get(conn, Routes.settings_path(conn, :security))

      assert html_response(conn, 200) =~ "Enable 2FA"
    end

    test "renders 2FA in enabled state", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = get(conn, Routes.settings_path(conn, :security))

      assert html_response(conn, 200) =~ "Disable 2FA"
    end

    test "renders active user sessions with an option to revoke them", %{conn: conn, user: user} do
      now = NaiveDateTime.utc_now(:second)
      seventy_minutes_ago = NaiveDateTime.shift(now, minute: -70)

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device", seventy_minutes_ago)
        |> Repo.insert!()

      conn = get(conn, Routes.settings_path(conn, :security))

      assert html = html_response(conn, 200)

      assert html =~ "Unknown"
      assert html =~ "Current session"
      assert html =~ "Just recently"
      assert html =~ "Some Device"
      assert html =~ "1 hour ago"
      assert html =~ Routes.settings_path(conn, :delete_session, another_session.id)
    end
  end

  describe "DELETE /security/user-sessions/:id" do
    setup [:create_user, :log_in]

    test "deletes session", %{conn: conn, user: user} do
      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      conn = delete(conn, Routes.settings_path(conn, :delete_session, another_session.id))

      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Session logged out successfully"

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :security) <> "#user-sessions"

      refute Repo.reload(another_session)
    end

    test "refuses deletion when not logged in" do
      another_session =
        insert(:user)
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      conn = build_conn()
      conn = delete(conn, Routes.settings_path(conn, :delete_session, another_session.id))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
      assert Repo.reload(another_session)
    end
  end

  describe "POST /preferences/name" do
    setup [:create_user, :log_in]

    test "updates user's name", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.settings_path(conn, :update_name), %{"user" => %{"name" => "New name"}})

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :preferences) <> "#update-name"

      user = Plausible.Repo.get(Plausible.Auth.User, user.id)
      assert user.name == "New name"
    end

    test "renders form with error if form validations fail", %{conn: conn} do
      conn = post(conn, Routes.settings_path(conn, :update_name), %{"user" => %{"name" => ""}})

      assert text(html_response(conn, 200)) =~ "can't be blank"
    end
  end

  describe "POST /security/password" do
    setup [:create_user, :log_in]

    test "updates the password and kills other sessions", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"
      new_password = "super-long-super-secret-999"

      another_session =
        user
        |> Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      original =
        user
        |> Auth.User.set_password(password)
        |> Repo.update!()

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password
          }
        })

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :security) <> "#update-password"

      current_hash = Repo.reload!(user).password_hash
      assert current_hash != original.password_hash
      assert Plausible.Auth.Password.match?(new_password, current_hash)

      assert [remaining_session] = Repo.preload(user, :sessions).sessions
      assert remaining_session.id != another_session.id
    end

    test "fails to update weak password", %{conn: conn} do
      password = "very-long-very-secret-123"
      new_password = "weak"

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "is too weak"
    end

    test "fails to update confirmation mismatch", %{conn: conn} do
      password = "very-long-very-secret-123"
      new_password = "super-long-super-secret-999"

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password <> "mismatch"
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "does not match confirmation"
    end

    test "updates the password when 2FA is enabled", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"
      new_password = "super-long-super-secret-999"

      original =
        user
        |> Auth.User.set_password(password)
        |> Repo.update!()

      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password,
            "two_factor_code" => code
          }
        })

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :security) <> "#update-password"

      current_hash = Repo.reload!(user).password_hash
      assert current_hash != original.password_hash
      assert Plausible.Auth.Password.match?(new_password, current_hash)
    end

    test "fails to update with wrong 2fa code", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"

      user =
        user
        |> Auth.User.set_password(password)
        |> Repo.update!()

      new_password = "super-long-super-secret-999"

      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password,
            "two_factor_code" => "111111"
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "invalid 2FA code"
    end

    test "fails to update with missing 2fa code", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"

      user =
        user
        |> Auth.User.set_password(password)
        |> Repo.update!()

      new_password = "super-long-super-secret-999"

      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => new_password,
            "old_password" => password,
            "password_confirmation" => new_password
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "invalid 2FA code"
    end

    test "fails to update with no input", %{conn: conn} do
      conn =
        post(conn, Routes.settings_path(conn, :update_password), %{
          "user" => %{
            "password" => "",
            "old_password" => "",
            "password_confirmation" => ""
          }
        })

      assert html = html_response(conn, 200)
      assert text(html) =~ "can't be blank"
    end
  end

  describe "POST /security/email" do
    setup [:create_user, :log_in]

    test "updates email and forces reverification", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"

      user
      |> Auth.User.set_password(password)
      |> Repo.update!()

      assert user.email_verified

      conn =
        post(conn, Routes.settings_path(conn, :update_email), %{
          "user" => %{"email" => "new" <> user.email, "password" => password}
        })

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate)

      updated_user = Repo.reload!(user)

      assert updated_user.email == "new" <> user.email
      assert updated_user.previous_email == user.email
      refute updated_user.email_verified

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == updated_user.email
      assert subject =~ "is your Plausible email verification code"
    end

    test "renders an error on third change attempt (allows 2 per hour)", %{conn: conn, user: user} do
      payload = %{
        "user" => %{"email" => "new" <> user.email, "password" => "badpass"}
      }

      resp1 =
        conn |> post(Routes.settings_path(conn, :update_email), payload) |> html_response(200)

      assert resp1 =~ "is invalid"
      refute resp1 =~ "too many requests, try again in an hour"

      resp2 =
        conn |> post(Routes.settings_path(conn, :update_email), payload) |> html_response(200)

      assert resp2 =~ "is invalid"
      refute resp2 =~ "too many requests, try again in an hour"

      resp3 =
        conn |> post(Routes.settings_path(conn, :update_email), payload) |> html_response(200)

      assert resp3 =~ "is invalid"
      assert resp3 =~ "too many requests, try again in an hour"
    end

    test "renders form with error on no fields filled", %{conn: conn} do
      conn = post(conn, Routes.settings_path(conn, :update_email), %{"user" => %{"email" => ""}})

      assert text(html_response(conn, 200)) =~ "can't be blank"
    end

    test "renders form with error on invalid password", %{conn: conn, user: user} do
      conn =
        post(conn, Routes.settings_path(conn, :update_email), %{
          "user" => %{"password" => "invalid", "email" => "new" <> user.email}
        })

      assert html_response(conn, 200) =~ "is invalid"
    end

    test "renders form with error on already taken email", %{conn: conn, user: user} do
      other_user = insert(:user)

      password = "very-long-very-secret-123"

      user
      |> Auth.User.set_password(password)
      |> Repo.update!()

      conn =
        post(conn, Routes.settings_path(conn, :update_email), %{
          "user" => %{"password" => password, "email" => other_user.email}
        })

      assert html_response(conn, 200) =~ "has already been taken"
    end

    test "renders form with error when email is identical with the current one", %{
      conn: conn,
      user: user
    } do
      password = "very-long-very-secret-123"

      user
      |> Auth.User.set_password(password)
      |> Repo.update!()

      conn =
        post(conn, Routes.settings_path(conn, :update_email), %{
          "user" => %{"password" => password, "email" => user.email}
        })

      assert html_response(conn, 200) =~ "can&#39;t be the same"
    end
  end

  describe "POST /security/email/cancel" do
    setup [:create_user, :log_in]

    test "cancels email reverification in progress", %{conn: conn, user: user} do
      user =
        user
        |> Ecto.Changeset.change(
          email_verified: false,
          email: "new" <> user.email,
          previous_email: user.email
        )
        |> Repo.update!()

      conn = post(conn, Routes.settings_path(conn, :cancel_update_email))

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :security) <> "#update-email"

      updated_user = Repo.reload!(user)

      assert updated_user.email_verified
      assert updated_user.email == user.previous_email
      refute updated_user.previous_email
    end

    test "fails to cancel reverification when previous email is already retaken", %{
      conn: conn,
      user: user
    } do
      user =
        user
        |> Ecto.Changeset.change(
          email_verified: false,
          email: "new" <> user.email,
          previous_email: user.email
        )
        |> Repo.update!()

      _other_user = insert(:user, email: user.previous_email)

      conn =
        post(conn, Routes.settings_path(conn, :cancel_update_email))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate_form)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Could not cancel email update"
    end

    test "crashes when previous email is empty on cancel (should not happen)", %{
      conn: conn,
      user: user
    } do
      user
      |> Ecto.Changeset.change(
        email_verified: false,
        email: "new" <> user.email,
        previous_email: nil
      )
      |> Repo.update!()

      assert_raise RuntimeError, ~r/Previous email is empty for user/, fn ->
        post(conn, Routes.settings_path(conn, :cancel_update_email))
      end
    end
  end

  describe "GET /settings/api-keys" do
    setup [:create_user, :log_in]

    test "handles user without a team gracefully", %{conn: conn} do
      conn = get(conn, Routes.settings_path(conn, :api_keys))

      assert html_response(conn, 200)
    end
  end

  describe "POST /settings/api-keys" do
    setup [:create_user, :log_in]

    test "can create an API key", %{conn: conn, user: user} do
      new_site(owner: user)

      conn =
        post(conn, Routes.settings_path(conn, :api_keys), %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      key = Plausible.Auth.ApiKey |> where(user_id: ^user.id) |> Repo.one()
      assert conn.status == 302
      assert key.name == "all your code are belong to us"
    end

    test "cannot create a duplicate API key", %{conn: conn, user: user} do
      new_site(owner: user)

      conn =
        post(conn, Routes.settings_path(conn, :api_keys), %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      conn2 =
        post(conn, Routes.settings_path(conn, :api_keys), %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      assert html_response(conn2, 200) =~ "has already been taken"
    end

    test "can't create api key into another site", %{conn: conn, user: me} do
      _my_site = new_site(owner: me)
      other_user = new_user()
      _other_site = new_site(owner: other_user)

      conn =
        post(conn, Routes.settings_path(conn, :api_keys), %{
          "api_key" => %{
            "user_id" => other_user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      assert conn.status == 302

      refute Plausible.Auth.ApiKey |> where(user_id: ^other_user.id) |> Repo.one()
    end
  end

  describe "DELETE /settings/api-keys/:id" do
    setup [:create_user, :log_in]
    alias Plausible.Auth.ApiKey

    test "can't delete api key that doesn't belong to me", %{conn: conn} do
      other_user = new_user()
      new_site(owner: other_user)

      assert {:ok, %ApiKey{} = api_key} =
               %ApiKey{user_id: other_user.id}
               |> ApiKey.changeset(%{"name" => "other user's key"})
               |> Repo.insert()

      conn = delete(conn, Routes.settings_path(conn, :delete_api_key, api_key.id))
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Could not find API Key to delete"
      assert Repo.get(ApiKey, api_key.id)
    end
  end

  describe "Team Settings" do
    setup [:create_user, :log_in]

    test "does not render team settings, when no team assigned", %{conn: conn} do
      conn = get(conn, Routes.settings_path(conn, :preferences))
      html = html_response(conn, 200)
      refute html =~ "Team Settings"
    end

    test "renders team settings, when team assigned", %{conn: conn, user: user} do
      {:ok, team} = Plausible.Teams.get_or_create(user)
      conn = get(conn, Routes.settings_path(conn, :preferences))
      html = html_response(conn, 200)
      assert html =~ "Team Settings"
      assert html =~ team.name
    end

    test "GET /settings/team/general", %{conn: conn, user: user} do
      {:ok, team} = Plausible.Teams.get_or_create(user)
      conn = get(conn, Routes.settings_path(conn, :team_general))
      html = html_response(conn, 200)
      assert html =~ "Team Name"
      assert html =~ "Change the name of your team"
      assert text_of_attr(html, "input#team_name", "value") == team.name
    end

    test "POST /settings/team/general/name", %{conn: conn, user: user} do
      {:ok, team} = Plausible.Teams.get_or_create(user)

      conn =
        post(conn, Routes.settings_path(conn, :update_team_name), %{
          "team" => %{"name" => "New Name"}
        })

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :team_general) <> "#update-name"

      assert Repo.reload!(team).name == "New Name"
    end

    test "POST /settings/team/general/name - changeset error", %{conn: conn, user: user} do
      {:ok, _team} = Plausible.Teams.get_or_create(user)

      conn =
        post(conn, Routes.settings_path(conn, :update_team_name), %{
          "team" => %{"name" => ""}
        })

      assert text(html_response(conn, 200)) =~ "can't be blank"
    end
  end

  defp configure_enterprise_plan(user, attrs \\ []) do
    subscribe_to_enterprise_plan(
      user,
      Keyword.merge(
        [
          paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
          monthly_pageview_limit: 20_000_000,
          billing_interval: :yearly
        ],
        attrs
      )
    )
  end
end
