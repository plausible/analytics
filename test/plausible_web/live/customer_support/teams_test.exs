defmodule PlausibleWeb.Live.CustomerSupport.TeamsTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    alias Plausible.Auth.SSO

    require Plausible.Billing.Subscription.Status

    defp open_team(id, qs \\ []) do
      Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, id, qs)
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        team = team_of(user)
        new_site(owner: user)
        add_member(team, role: :editor)

        {:ok, _lv, html} = live(conn, open_team(team.id))
        text = text(html)

        assert text =~ team.name
        assert text =~ "Sites (2/10)"
        assert text =~ "Members (1/10)"
      end

      test "renders unlimited limits", %{conn: conn, user: user} do
        owner = new_user(team: [inserted_at: ~N[2021-01-01 00:00:00]])
        subscribe_to_enterprise_plan(owner, team_member_limit: :unlimited)
        team = team_of(owner)
        add_member(team, user: user, role: :editor)
        new_site(owner: owner)

        {:ok, _lv, html} = live(conn, open_team(team.id))
        text = text(html)

        assert text =~ team.name
        assert text =~ "Sites (1/unlimited)"
        assert text =~ "Members (1/unlimited)"
      end

      test "delete team", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, lv, _html} = live(conn, open_team(team.id))

        lv
        |> element(~s|button[phx-click="delete-team"]|)
        |> render_click()

        assert_redirect(lv, Routes.customer_support_path(PlausibleWeb.Endpoint, :index))

        refute Plausible.Repo.get(Plausible.Teams.Team, team.id)
      end

      test "delete team with active subscription", %{conn: conn, user: user} do
        user = subscribe_to_growth_plan(user)
        team = team_of(user)
        {:ok, lv, _html} = live(conn, open_team(team.id))

        lv
        |> element(~s|button[phx-click="delete-team"]|)
        |> render_click()

        text = lv |> render() |> text()

        assert text =~ "The team has an active subscription which must be canceled first"

        assert Plausible.Repo.get(Plausible.Teams.Team, team.id)
      end

      test "grace period handling", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _, html} = live(conn, open_team(team.id))
        refute text(html) =~ "Lock"
        refute text(html) =~ "Unlock"

        Plausible.Teams.start_grace_period(team)

        {:ok, lv, html} = live(conn, open_team(team.id))

        assert element_exists?(html, ~s|a[phx-click="lock"]|)
        assert element_exists?(html, ~s|a[phx-click="unlock"]|)

        refute Plausible.Repo.reload!(team).locked

        lv |> element(~s|a[phx-click="lock"]|) |> render_click()

        team = Plausible.Repo.reload!(team)
        assert team.locked
        assert team.grace_period.is_over

        lv |> element(~s|a[phx-click="unlock"]|) |> render_click()

        team = Plausible.Repo.reload!(team)
        refute team.locked
        refute team.grace_period
      end

      test "refund lock handling", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _lv, html} = live(conn, open_team(team.id))
        refute text(html) =~ "Refund Lock"
        refute text(html) =~ "Locked"

        subscribe_to_growth_plan(user,
          status: Plausible.Billing.Subscription.Status.deleted()
        )

        {:ok, lv, html} = live(conn, open_team(team.id))

        assert text(html) =~ "Refund Lock"
        lv |> element(~s|a[phx-click="refund-lock"]|) |> render_click()

        assert text(render(lv)) =~ "Locked"

        team = Plausible.Repo.reload!(team)
        assert team.locked
        refute team.grace_period

        assert Date.diff(
                 Plausible.Teams.with_subscription(team).subscription.next_bill_date,
                 Date.utc_today()
               ) == -1

        # make sure this team doesn't unlock automatically
        Plausible.Workers.LockSites.perform(nil)
        team = Plausible.Repo.reload!(team)
        assert team.locked
      end

      test "404", %{conn: conn} do
        assert_raise Ecto.NoResultsError, fn ->
          {:ok, _lv, _html} = live(conn, open_team(9999))
        end
      end
    end

    describe "billing" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders custom plan form", %{conn: conn, user: user} do
        lv = open_custom_plan(conn, team_of(user))
        html = render(lv)

        assert element_exists?(
                 html,
                 ~s|form#save-plan[phx-submit="save-plan"][phx-change="estimate-cost"]|
               )
      end

      test "estimates the price", %{conn: conn, user: user} do
        lv = open_custom_plan(conn, team_of(user))

        lv
        |> element(~s|form#save-plan|)
        |> render_change(%{
          "enterprise_plan" => %{
            "billing_interval" => "yearly",
            "monthly_pageview_limit" => "20000000",
            "site_limit" => "1000",
            "team_member_limit" => "30",
            "hourly_api_request_limit" => "1000",
            "features[]" => %{
              "stats_api" => "false",
              "outbound_links" => "false",
              "form_submissions" => "false",
              "file_downloads" => "false",
              "funnels" => "false",
              "props" => "false",
              "shared_segments" => "false",
              "revenue_goals" => "false",
              "site_segments" => "false",
              "shared_links" => "true",
              "sites_api" => "true"
            }
          }
        })

        html = render(lv)
        assert text_of_attr(html, ~s|#cost-estimate|, "value") == "12380.00"
      end

      test "saves custom plan", %{conn: conn, user: user} do
        lv = open_custom_plan(conn, team_of(user))

        lv
        |> element(~s|form#save-plan|)
        |> render_change(%{
          "enterprise_plan" => %{
            "paddle_plan_id" => "1111",
            "billing_interval" => "yearly",
            "monthly_pageview_limit" => "20000000",
            "site_limit" => "1000",
            "team_member_limit" => "30",
            "hourly_api_request_limit" => "1000",
            "features[]" => %{
              "stats_api" => "false",
              "outbound_links" => "false",
              "form_submissions" => "false",
              "file_downloads" => "false",
              "funnels" => "false",
              "props" => "false",
              "shared_segments" => "false",
              "revenue_goals" => "false",
              "site_segments" => "false",
              "shared_links" => "true",
              "sites_api" => "true",
              "sso" => "false"
            }
          }
        })

        lv |> element("form#save-plan") |> render_submit()
        html = render(lv)
        assert text(html) =~ "Plan saved"

        team_id = team_of(user).id

        assert [
                 %Plausible.Billing.EnterprisePlan{
                   billing_interval: :yearly,
                   features: [
                     Plausible.Billing.Feature.SharedLinks,
                     Plausible.Billing.Feature.SitesAPI
                   ],
                   hourly_api_request_limit: 1000,
                   monthly_pageview_limit: 20_000_000,
                   paddle_plan_id: "1111",
                   site_limit: 1000,
                   team_id: ^team_id,
                   team_member_limit: 30
                 }
               ] = Plausible.Repo.all(Plausible.Billing.EnterprisePlan)
      end

      test "handles unlimited team members", %{conn: conn, user: user} do
        user |> subscribe_to_enterprise_plan(team_member_limit: :unlimited)
        lv = open_custom_plan(conn, team_of(user))

        html = render(lv)

        assert text_of_attr(html, ~s|input[name="enterprise_plan[team_member_limit]"]|, "value") ==
                 "unlimited"

        lv
        |> element(~s|form#save-plan|)
        |> render_change(%{
          "enterprise_plan" => %{
            "paddle_plan_id" => "1111",
            "billing_interval" => "yearly",
            "monthly_pageview_limit" => "20000000",
            "site_limit" => "1000",
            "team_member_limit" => "unlimited",
            "hourly_api_request_limit" => "1000"
          }
        })

        lv |> element("form#save-plan") |> render_submit()
        html = render(lv)
        assert text(html) =~ "Plan saved"
      end

      test "displays existing custom plan with edit button", %{conn: conn, user: user} do
        team = team_of(user)

        plan =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "existing-plan-123",
            billing_interval: :yearly,
            monthly_pageview_limit: 5_000_000,
            site_limit: 200,
            team_member_limit: 25,
            hourly_api_request_limit: 2000,
            features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels]
          )

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: "billing"))
        html = render(lv)

        assert text(html) =~ "existing-plan-123"
        assert text(html) =~ "yearly"
        assert text(html) =~ "5,000,000"
        assert text(html) =~ "200"
        assert text(html) =~ "25"
        assert text(html) =~ "2,000"

        assert element_exists?(html, ~s|button[phx-click="edit-plan"][phx-value-id="#{plan.id}"]|)
      end

      test "edit plan loads existing values into form", %{conn: conn, user: user} do
        team = team_of(user)

        plan =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "edit-test-plan",
            billing_interval: :monthly,
            monthly_pageview_limit: 10_000_000,
            site_limit: 300,
            team_member_limit: 50,
            hourly_api_request_limit: 5000,
            features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.Funnels]
          )

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))

        lv
        |> element(~s|button[phx-click="edit-plan"][phx-value-id="#{plan.id}"]|)
        |> render_click()

        html = render(lv)

        assert element_exists?(html, ~s|form#save-plan[phx-submit="update-plan"]|)

        assert text_of_attr(html, ~s|input[name="enterprise_plan[paddle_plan_id]"]|, "value") ==
                 "edit-test-plan"

        assert text_of_element(
                 html,
                 ~s|select[name="enterprise_plan[billing_interval]"] option[selected="selected"]|
               ) ==
                 "monthly"

        assert text_of_attr(
                 html,
                 ~s|input[name="enterprise_plan[monthly_pageview_limit]"]|,
                 "value"
               ) == "10000000"

        assert text_of_attr(html, ~s|input[name="enterprise_plan[site_limit]"]|, "value") == "300"

        assert text_of_attr(html, ~s|input[name="enterprise_plan[team_member_limit]"]|, "value") ==
                 "50"

        assert text_of_attr(
                 html,
                 ~s|input[name="enterprise_plan[hourly_api_request_limit]"]|,
                 "value"
               ) == "5000"

        assert element_exists?(
                 html,
                 ~s|input[name="enterprise_plan[features[]][stats_api]"][checked="checked"]|
               )

        assert element_exists?(
                 html,
                 ~s|input[name="enterprise_plan[features[]][funnels]"][checked="checked"]|
               )

        refute element_exists?(
                 html,
                 ~s|input[name="enterprise_plan[features[]][revenue_goals]"][checked="checked"]|
               )

        assert text(html) =~ "Update Plan"
        refute text(html) =~ "Save Custom Plan"
      end

      test "successfully updates existing plan", %{conn: conn, user: user} do
        team = team_of(user)

        plan =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "original-plan",
            billing_interval: :monthly,
            monthly_pageview_limit: 1_000_000,
            site_limit: 100,
            team_member_limit: 10,
            hourly_api_request_limit: 1000,
            features: [Plausible.Billing.Feature.StatsAPI]
          )

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))

        lv
        |> element(~s|button[phx-click="edit-plan"][phx-value-id="#{plan.id}"]|)
        |> render_click()

        lv
        |> element(~s|form#save-plan|)
        |> render_change(%{
          "enterprise_plan" => %{
            "paddle_plan_id" => "updated-plan-456",
            "billing_interval" => "yearly",
            "monthly_pageview_limit" => "15000000",
            "site_limit" => "500",
            "team_member_limit" => "100",
            "hourly_api_request_limit" => "8000",
            "features[]" => %{
              "stats_api" => "true",
              "funnels" => "true",
              "props" => "false",
              "revenue_goals" => "false",
              "site_segments" => "false",
              "shared_links" => "false",
              "sites_api" => "false",
              "sso" => "false"
            }
          }
        })

        lv |> element("form#save-plan") |> render_submit()

        html = render(lv)
        assert text(html) =~ "Plan updated"

        updated_plan = Plausible.Repo.reload!(plan)
        assert updated_plan.paddle_plan_id == "updated-plan-456"
        assert updated_plan.billing_interval == :yearly
        assert updated_plan.monthly_pageview_limit == 15_000_000
        assert updated_plan.site_limit == 500
        assert updated_plan.team_member_limit == 100
        assert updated_plan.hourly_api_request_limit == 8000

        feature_names = Enum.map(updated_plan.features, & &1.name())
        assert :stats_api in feature_names
        assert :funnels in feature_names
        refute :shared_links in feature_names

        refute element_exists?(html, ~s|form#save-plan|)

        assert text(html) =~ "updated-plan-456"
        assert text(html) =~ "yearly"
        assert text(html) =~ "15,000,000"
        assert text(html) =~ "500"
        assert text(html) =~ "100"
        assert text(html) =~ "8,000"
      end

      test "handles validation errors when updating plan", %{conn: conn, user: user} do
        team = team_of(user)

        plan =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "valid-plan",
            billing_interval: :monthly,
            monthly_pageview_limit: 1_000_000,
            site_limit: 100,
            team_member_limit: 10,
            hourly_api_request_limit: 1000
          )

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))

        lv
        |> element(~s|button[phx-click="edit-plan"][phx-value-id="#{plan.id}"]|)
        |> render_click()

        lv
        |> element(~s|form#save-plan|)
        |> render_submit(%{
          "enterprise_plan" => %{
            "paddle_plan_id" => "",
            "billing_interval" => "monthly",
            "monthly_pageview_limit" => "1000000",
            "site_limit" => "100",
            "team_member_limit" => "10",
            "hourly_api_request_limit" => "1000"
          }
        })

        html = render(lv)

        assert text(html) =~ "Error updating plan"
        assert element_exists?(html, ~s|form#save-plan|)

        unchanged_plan = Plausible.Repo.reload!(plan)
        assert unchanged_plan.paddle_plan_id == "valid-plan"
      end

      test "cancel edit returns to plan list", %{conn: conn, user: user} do
        team = team_of(user)

        plan = insert(:enterprise_plan, team: team)

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))

        lv
        |> element(~s|button[phx-click="edit-plan"][phx-value-id="#{plan.id}"]|)
        |> render_click()

        html = render(lv)
        assert element_exists?(html, ~s|form#save-plan|)

        lv |> element(~s|button[phx-click="hide-plan-form"]|) |> render_click()

        html = render(lv)
        refute element_exists?(html, ~s|form#save-plan|)
        assert element_exists?(html, ~s|button#new-custom-plan|)
      end

      test "multiple plans can be displayed and edited independently", %{conn: conn, user: user} do
        team = team_of(user)

        plan1 =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "plan-1",
            monthly_pageview_limit: 1_000_000
          )

        plan2 =
          insert(:enterprise_plan,
            team: team,
            paddle_plan_id: "plan-2",
            monthly_pageview_limit: 5_000_000
          )

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))
        html = render(lv)

        assert text(html) =~ "plan-1"
        assert text(html) =~ "plan-2"
        assert text(html) =~ "1,000,000"
        assert text(html) =~ "5,000,000"

        assert element_exists?(
                 html,
                 ~s|button[phx-click="edit-plan"][phx-value-id="#{plan1.id}"]|
               )

        assert element_exists?(
                 html,
                 ~s|button[phx-click="edit-plan"][phx-value-id="#{plan2.id}"]|
               )

        lv
        |> element(~s|button[phx-click="edit-plan"][phx-value-id="#{plan2.id}"]|)
        |> render_click()

        html = render(lv)

        assert text_of_attr(html, ~s|input[name="enterprise_plan[paddle_plan_id]"]|, "value") ==
                 "plan-2"

        assert text_of_attr(
                 html,
                 ~s|input[name="enterprise_plan[monthly_pageview_limit]"]|,
                 "value"
               ) == "5000000"
      end

      defp open_custom_plan(conn, team) do
        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))
        render(lv)
        lv |> element("button#new-custom-plan") |> render_click()
        lv
      end
    end

    describe "sso" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "sso tab normally won't render", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _lv, html} = live(conn, open_team(team.id))

        refute element_exists?(html, ~s|a[href="?tab=sso"]|)
      end

      test "tab renders when there's sso integration", %{conn: conn, user: user} do
        team = team_of(user)

        SSO.initiate_saml_integration(team)

        {:ok, _lv, html} = live(conn, open_team(team.id))

        assert element_exists?(html, ~s|a[href="?tab=sso"]|)
      end

      test "sso tab displays domains and policy/idp config", %{conn: conn, user: user} do
        team = team_of(user)

        integration = SSO.initiate_saml_integration(team)

        SSO.Domains.add(integration, "sso1.example.com")
        SSO.Domains.add(integration, "sso2.example.com")

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :sso))

        text = lv |> render() |> text()

        assert text =~ "sso1.example.com"
        assert text =~ "sso2.example.com"
        assert text =~ "configured? false"
        assert text =~ "sso_session_timeout_minutes 360"
      end

      test "delete domain", %{conn: conn, user: user} do
        team = team_of(user)
        integration = SSO.initiate_saml_integration(team)
        {:ok, domain} = SSO.Domains.add(integration, "sso1.example.com")
        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :sso))

        lv |> element("button#remove-sso-domain-#{domain.identifier}") |> render_click()
        refute render(lv) =~ "sso1.example.com"
      end

      test "deprovisioning users", %{conn: conn, user: user} do
        team = team_of(user) |> Plausible.Teams.complete_setup()
        integration = SSO.initiate_saml_integration(team)
        {:ok, sso_domain} = SSO.Domains.add(integration, "example.com")

        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok, :standard, team, user} =
          SSO.provision_user(%SSO.Identity{
            id: Ecto.UUID.generate(),
            integration_id: integration.identifier,
            name: user.name,
            email: user.email,
            expires_at: NaiveDateTime.add(NaiveDateTime.utc_now(:second), 6, :hour)
          })

        # need to re-authenticate for SSO to take effect
        {:ok, conn: conn} = log_in(%{user: user, conn: conn})

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :members))

        html = render(lv)

        assert text(html) =~ "SSO membership"
        lv |> element("#deprovision-sso-user-#{user.id}") |> render_click()

        assert Plausible.Repo.reload!(user).type == :standard
      end

      test "removing integration", %{conn: conn, user: user} do
        team = team_of(user)

        SSO.initiate_saml_integration(team)

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :sso))

        assert {:error, {:live_redirect, %{to: to}}} =
                 lv |> element("button#remove-sso-integration") |> render_click()

        assert to == Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, team.id)
      end
    end

    describe "audit" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "audit tab is present", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _lv, html} = live(conn, open_team(team.id))
        assert element_exists?(html, ~s|a[href="?tab=audit"]|)
      end

      test "shows audit entries", %{conn: conn, user: user} do
        team = team_of(user)

        entry =
          %Plausible.Audit.Entry{
            name: "Reveal Test",
            entity: "Plausible.Teams.Team",
            entity_id: to_string(team.id),
            change: %{"foo" => "bar"},
            team_id: team.id,
            datetime: NaiveDateTime.utc_now()
          }
          |> Plausible.Repo.insert!()

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :audit))

        html = render(lv)

        assert html =~ "Reveal Test"

        html =
          lv
          |> element(~s|button[phx-click="reveal-audit-entry"][phx-value-id="#{entry.id}"]|)
          |> render_click()

        assert text_of_element(html, ~s|textarea|) ==
                 "{ &amp;quot;foo&amp;quot;: &amp;quot;bar&amp;quot; }"
      end

      test "shows audit entries when user id does not exists", %{conn: conn, user: user} do
        team = team_of(user)

        %Plausible.Audit.Entry{
          name: "Reveal Test",
          entity: "Plausible.Auth.User",
          entity_id: "666111",
          team_id: team.id,
          datetime: NaiveDateTime.utc_now(),
          user_id: 666_111,
          actor_type: :user
        }
        |> Plausible.Repo.insert!()

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :audit))

        text = lv |> render() |> text()

        assert text =~ "(N/A) (N/A)"
      end

      test "paginates audit entries", %{conn: conn, user: user} do
        team = team_of(user)

        now = NaiveDateTime.utc_now()

        for i <- 1..8 do
          %Plausible.Audit.Entry{
            name: "Entry (#{i})",
            entity: "Plausible.Teams.Team",
            entity_id: to_string(team.id),
            team_id: team.id,
            datetime: NaiveDateTime.shift(now, second: i)
          }
          |> Plausible.Repo.insert!()
        end

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :audit, limit: 3))
        text = lv |> render() |> text()

        for i <- 4..8, do: refute(text =~ "Entry (#{i})")
        for i <- 1..3, do: assert(text =~ "Entry (#{i})")

        lv |> element("button#next-page") |> render_click()
        text = lv |> render() |> text()

        for i <- 4..6, do: assert(text =~ "Entry (#{i})")
        for i <- 1..3, do: refute(text =~ "Entry (#{i})")
        for i <- 7..8, do: refute(text =~ "Entry (#{i})")

        lv |> element("button#prev-page") |> render_click()
        text = lv |> render() |> text()

        for i <- 4..8, do: refute(text =~ "Entry (#{i})")
        for i <- 1..3, do: assert(text =~ "Entry (#{i})")
      end
    end
  end
end
