defmodule PlausibleWeb.AdminControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test

  alias Plausible.Repo

  describe "GET /crm/teams/team/:team_id/usage" do
    setup [:create_user, :log_in, :create_team]

    @tag :ee_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/teams/team/1/usage")
      assert response(conn, 403) == "Not allowed"
    end

    @tag :ee_only
    test "returns usage data as a standalone page", %{conn: conn, user: user, team: team} do
      patch_env(:super_admin_user_ids, [user.id])
      conn = get(conn, "/crm/teams/team/#{team.id}/usage")
      assert response(conn, 200) =~ "<html"
    end

    @tag :ee_only
    test "returns usage data in embeddable form when requested", %{
      conn: conn,
      user: user,
      team: team
    } do
      patch_env(:super_admin_user_ids, [user.id])
      conn = get(conn, "/crm/teams/team/#{team.id}/usage?embed=true")
      refute response(conn, 200) =~ "<html"
    end
  end

  describe "GET /crm/sites/site" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "pagination works correctly when multiple memberships per site present", %{
      conn: conn,
      user: user
    } do
      patch_env(:super_admin_user_ids, [user.id])

      s1 = new_site(inserted_at: ~N[2024-01-01 00:00:00])
      for _ <- 1..3, do: add_guest(s1, role: :viewer)
      s2 = new_site(inserted_at: ~N[2024-01-02 00:00:00])
      for _ <- 1..3, do: add_guest(s2, role: :viewer)
      s3 = new_site(inserted_at: ~N[2024-01-03 00:00:00])
      for _ <- 1..3, do: add_guest(s3, role: :viewer)

      conn1 = get(conn, "/crm/sites/site", %{"limit" => "2"})
      page1_html = html_response(conn1, 200)

      assert page1_html =~ s3.domain
      assert page1_html =~ s2.domain
      refute page1_html =~ s1.domain

      conn2 = get(conn, "/crm/sites/site", %{"page" => "2", "limit" => "2"})
      page2_html = html_response(conn2, 200)

      refute page2_html =~ s3.domain
      refute page2_html =~ s2.domain
      assert page2_html =~ s1.domain
    end
  end

  describe "POST /crm/sites/site/:site_id" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "resets stats start date on native stats start time change", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      site =
        new_site(
          public: false,
          stats_start_date: ~D[2022-03-14],
          native_stats_start_at: ~N[2024-01-22 14:28:00]
        )

      params = %{
        "site" => %{
          "domain" => site.domain,
          "timezone" => site.timezone,
          "public" => "false",
          "native_stats_start_at" => "2024-02-12 12:00:00",
          "ingest_rate_limit_scale_seconds" => site.ingest_rate_limit_scale_seconds,
          "ingest_rate_limit_threshold" => site.ingest_rate_limit_threshold
        }
      }

      conn = put(conn, "/crm/sites/site/#{site.id}", params)
      assert redirected_to(conn, 302) == "/crm/sites/site"

      site = Repo.reload!(site)

      refute site.public
      assert site.native_stats_start_at == ~N[2024-02-12 12:00:00]
      assert site.stats_start_date == nil
    end
  end

  describe "GET /crm/billing/user/:user_id/current_plan" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/billing/user/0/current_plan")
      assert response(conn, 403) == "Not allowed"
    end

    @tag :ee_only
    test "returns empty state for non-existent user", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      conn = get(conn, "/crm/billing/user/0/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns empty state for user without subscription", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      conn = get(conn, "/crm/billing/user/#{user.id}/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns empty state for user with subscription with non-existent paddle plan ID", %{
      conn: conn,
      user: user
    } do
      patch_env(:super_admin_user_ids, [user.id])

      subscribe_to_plan(user, "does-not-exist")

      conn = get(conn, "/crm/billing/user/#{user.id}/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns plan data for user with subscription", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      subscribe_to_plan(user, "857104")

      conn = get(conn, "/crm/billing/user/#{user.id}/current_plan")

      assert json_response(conn, 200) == %{
               "features" => ["goals"],
               "monthly_pageview_limit" => 10_000_000,
               "site_limit" => 10,
               "team_member_limit" => 3
             }
    end
  end
end
