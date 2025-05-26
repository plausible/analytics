defmodule PlausibleWeb.Live.CustomerSupport.TeamsTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

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
            "monthly_pageview_limit" => "20,000,000",
            "site_limit" => "1,000",
            "team_member_limit" => "30",
            "hourly_api_request_limit" => "1,000",
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
        assert text_of_attr(html, ~s|#cost-estimate|, "value") == "10880.00"
      end

      test "saves custom plan", %{conn: conn, user: user} do
        lv = open_custom_plan(conn, team_of(user))

        lv
        |> element(~s|form#save-plan|)
        |> render_change(%{
          "enterprise_plan" => %{
            "paddle_plan_id" => "1111",
            "billing_interval" => "yearly",
            "monthly_pageview_limit" => "20,000,000",
            "site_limit" => "1,000",
            "team_member_limit" => "30",
            "hourly_api_request_limit" => "1,000",
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

        lv |> element("form#save-plan") |> render_submit()
        html = render(lv)
        assert text(html) =~ "Plan saved"

        team_id = team_of(user).id

        assert [
                 %Plausible.Billing.EnterprisePlan{
                   billing_interval: :yearly,
                   features: [
                     Plausible.Billing.Feature.Teams,
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

      defp open_custom_plan(conn, team) do
        {:ok, lv, _html} = live(conn, open_team(team.id, tab: :billing))
        render(lv)
        lv |> element("button#new-custom-plan") |> render_click()
        lv
      end
    end
  end
end
