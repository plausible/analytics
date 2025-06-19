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
      Routes.customer_support_resource_path(
        PlausibleWeb.Endpoint,
        :details,
        :teams,
        :team,
        id,
        qs
      )
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _lv, html} = live(conn, open_team(team.id))
        assert text(html) =~ team.name
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
            "features[]" => [
              "false",
              "false",
              "false",
              "teams",
              "false",
              "shared_links",
              "false",
              "false",
              "false",
              "false",
              "sites_api"
            ]
          }
        })

        html = render(lv)
        assert text_of_attr(html, ~s|#cost-estimate|, "value") == "10380.00"
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
            "features[]" => [
              "false",
              "false",
              "false",
              "false",
              "shared_links",
              "false",
              "false",
              "false",
              "false",
              "sites_api"
            ]
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

      test "sso tab displays domains", %{conn: conn, user: user} do
        team = team_of(user)

        integration = SSO.initiate_saml_integration(team)

        SSO.Domains.add(integration, "sso1.example.com")
        SSO.Domains.add(integration, "sso2.example.com")

        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :sso))

        html = render(lv)

        assert html =~ "sso1.example.com"
        assert html =~ "sso2.example.com"
      end

      test "delete domain", %{conn: conn, user: user} do
        team = team_of(user)
        integration = SSO.initiate_saml_integration(team)
        {:ok, domain} = SSO.Domains.add(integration, "sso1.example.com")
        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :sso))

        lv |> element("button#remove-domain-#{domain.identifier}") |> render_click()
        refute render(lv) =~ "sso1.example.com"
      end
    end
  end
end
