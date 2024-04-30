defmodule PlausibleWeb.AdminControllerTest do
  use PlausibleWeb.ConnCase, async: false

  alias Plausible.Repo

  describe "GET /crm/auth/user/:user_id/usage" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/auth/user/1/usage")
      assert response(conn, 403) == "Not allowed"
    end
  end

  describe "POST /crm/sites/site/:site_id" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "resets stats start date on native stats start time change", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      site =
        insert(:site,
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
end
