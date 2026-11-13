defmodule PlausibleWeb.Plugs.RecordApiRequestTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  @moduletag :ee_only

  on_ee do
    import ExUnit.CaptureLog

    alias Plausible.ApiRequestLog.Entry
    alias Plausible.ApiRequestLog.WriteBuffer
    alias PlausibleWeb.Plugs.RecordApiRequest

    setup [:create_user, :create_site]

    setup %{user: user} do
      team = team_of(user)
      api_key = insert(:api_key, user: user, team: team)
      FunWithFlags.enable(:record_api_requests, for_actor: team)

      conn =
        api_key
        |> api_conn()
        |> put_req_header("user-agent", "python-requests/2.32.3")

      {:ok, conn: conn, team: team, api_key: api_key}
    end

    describe "records a row" do
      test "for a Stats API v2 query", %{
        conn: conn,
        user: user,
        site: site,
        team: team,
        api_key: api_key
      } do
        started_at = DateTime.utc_now(:second)

        conn = post(conn, "/api/v2/query", v2_query(site))

        assert json_response(conn, 200)
        [request_id] = get_resp_header(conn, "x-request-id")

        assert [
                 %Entry{
                   timestamp: timestamp,
                   team_id: team_id,
                   user_id: user_id,
                   credential_type: "api_key",
                   credential_id: credential_id,
                   credential_label: credential_label,
                   interface: "rest",
                   operation: "POST /api/v2/query",
                   status: 200,
                   billable: true,
                   request_id: ^request_id,
                   user_agent: "python-requests/2.32.3"
                 }
               ] = recorded_entries(team)

        assert DateTime.compare(timestamp, started_at) != :lt
        assert team_id == team.id
        assert user_id == user.id
        assert credential_id == api_key.id
        assert credential_label == api_key.key_prefix
      end

      test "for each page of a query", %{conn: conn, site: site, team: team} do
        for offset <- [0, 1] do
          conn
          |> post(
            "/api/v2/query",
            v2_query(site, %{
              "dimensions" => ["event:page"],
              "pagination" => %{"limit" => 1, "offset" => offset}
            })
          )
          |> json_response(200)
        end

        assert [
                 %Entry{operation: "POST /api/v2/query", status: 200, billable: true},
                 %Entry{operation: "POST /api/v2/query", status: 200, billable: true}
               ] = recorded_entries(team)
      end

      test "that is not billable for a 400", %{conn: conn, site: site, team: team} do
        conn = post(conn, "/api/v2/query", v2_query(site, %{"metrics" => ["invalid"]}))

        assert json_response(conn, 400)
        assert [%Entry{status: 400, billable: false}] = recorded_entries(team)
      end

      test "that is not billable for a 402", %{conn: conn, site: site, team: team} do
        team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

        conn = get(conn, "/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 402)
        assert [%Entry{status: 402, billable: false}] = recorded_entries(team)
      end

      @tag :capture_log
      test "under the API key's own team when the key has no access to the site", %{
        conn: conn,
        team: team
      } do
        other_user = new_user()
        other_site = new_site(owner: other_user)
        other_team = team_of(other_user)
        FunWithFlags.enable(:record_api_requests, for_actor: other_team)

        conn = get(conn, "/api/v1/stats/aggregate", v1_aggregate(other_site))

        assert json_response(conn, 401)
        assert [%Entry{status: 401, billable: false}] = recorded_entries(team)
        assert recorded_entries(other_team) == []
      end

      test "with the route of a Stats API v1 request, without the query string", %{
        conn: conn,
        site: site,
        team: team
      } do
        conn = get(conn, "/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 200)

        assert [%Entry{operation: "GET /api/v1/stats/aggregate", status: 200, billable: true}] =
                 recorded_entries(team)
      end

      test "with the route pattern of a Sites API request", %{user: user, site: site, team: team} do
        subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.SitesAPI])
        api_key = insert(:api_key, user: user, team: team, scopes: ["sites:provision:*"])
        goal = insert(:goal, site: site, event_name: "Signup")

        conn =
          api_key
          |> api_conn()
          |> delete("/api/v1/sites/goals/#{goal.id}", %{"site_id" => site.domain})

        assert json_response(conn, 200)

        assert [%Entry{operation: "DELETE /api/v1/sites/goals/:goal_id", status: 200}] =
                 recorded_entries(team)
      end

      test "under the site's team for a legacy API key of a team member", %{
        user: user,
        site: site,
        team: team
      } do
        api_key = insert(:api_key, user: user)

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 200)
        api_key_id = api_key.id

        assert [%Entry{credential_id: ^api_key_id, status: 200, billable: true}] =
                 recorded_entries(team)
      end

      test "that is not billable for a 400 with a legacy API key of a team member", %{
        user: user,
        site: site,
        team: team
      } do
        api_key = insert(:api_key, user: user)

        conn =
          api_key
          |> api_conn()
          |> post("/api/v2/query", v2_query(site, %{"metrics" => ["invalid"]}))

        assert json_response(conn, 400)
        api_key_id = api_key.id

        assert [%Entry{credential_id: ^api_key_id, status: 400, billable: false}] =
                 recorded_entries(team)
      end

      test "under the site's team for a legacy API key on a Sites API request", %{
        user: user,
        site: site,
        team: team
      } do
        api_key = insert(:api_key, user: user)

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/sites/goals", %{"site_id" => site.domain})

        assert json_response(conn, 200)
        api_key_id = api_key.id

        assert [
                 %Entry{
                   credential_id: ^api_key_id,
                   operation: "GET /api/v1/sites/goals",
                   status: 200
                 }
               ] = recorded_entries(team)
      end

      @tag :capture_log
      test "under the site's team for a legacy API key of a guest", %{site: site, team: team} do
        guest = add_guest(site, role: :viewer)
        api_key = insert(:api_key, user: guest)

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 200)
        api_key_id = api_key.id

        assert [%Entry{credential_id: ^api_key_id, status: 200, billable: true}] =
                 recorded_entries(team)
      end

      @tag :capture_log
      test "that is not billable for a legacy API key of a super admin on a customer's site", %{
        site: site,
        team: team
      } do
        super_admin = new_user()
        patch_env(:super_admin_user_ids, [super_admin.id])
        api_key = insert(:api_key, user: super_admin)

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 200)
        api_key_id = api_key.id

        assert [%Entry{credential_id: ^api_key_id, status: 200, billable: false}] =
                 recorded_entries(team)
      end

      test "that is not billable for a team API key of a super admin", %{
        conn: conn,
        user: user,
        site: site,
        team: team
      } do
        patch_env(:super_admin_user_ids, [user.id])

        assert conn |> post("/api/v2/query", v2_query(site)) |> json_response(200)
        assert [%Entry{status: 200, billable: false}] = recorded_entries(team)
      end

      test "with an empty user agent when the header is missing", %{
        site: site,
        team: team,
        api_key: api_key
      } do
        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 200)
        assert [%Entry{user_agent: ""}] = recorded_entries(team)
      end
    end

    describe "records no row" do
      test "for an invalid API key", %{site: site, team: team} do
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer invalid")
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 401)
        assert recorded_entries(team) == []
      end

      test "for a 429", %{conn: conn, site: site, team: team} do
        team |> Ecto.Changeset.change(hourly_api_request_limit: 1) |> Repo.update!()

        assert conn |> get("/api/v1/stats/aggregate", v1_aggregate(site)) |> json_response(200)
        assert conn |> get("/api/v1/stats/aggregate", v1_aggregate(site)) |> json_response(429)

        assert [%Entry{status: 200}] = recorded_entries(team)
      end

      @tag :capture_log
      test "for a legacy API key on another team's site", %{site: site, team: team} do
        api_key = insert(:api_key, user: new_user())

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/stats/aggregate", v1_aggregate(site))

        assert json_response(conn, 401)
        assert recorded_entries(team) == []
        assert recorded_entries_of(api_key) == []
      end

      test "for a legacy API key without a site", %{user: user, team: team} do
        api_key = insert(:api_key, user: user)

        conn =
          api_key
          |> api_conn()
          |> get("/api/v1/sites")

        assert json_response(conn, 200)
        assert recorded_entries(team) == []
      end

      test "for the dashboard and the docs query", %{user: user, site: site, team: team} do
        {:ok, conn: conn} = log_in(%{user: user, conn: build_conn() |> prepare_conn()})

        assert conn |> get("/api/stats/#{site.domain}/current-visitors") |> json_response(200)
        assert conn |> post("/api/docs/query", v2_query(site)) |> json_response(200)

        assert recorded_entries(team) == []
      end

      test "when the flag is off for the team", %{conn: conn, site: site, team: team} do
        FunWithFlags.clear(:record_api_requests, for_actor: team)

        assert conn |> post("/api/v2/query", v2_query(site)) |> json_response(200)
        assert recorded_entries(team) == []
      end
    end

    describe "when recording fails" do
      test "sends the response and logs the error", %{team: team, api_key: api_key} do
        log =
          capture_log(fn ->
            conn =
              Plug.Test.conn(:get, "/api/v1/stats/aggregate")
              |> assign(:current_credential, api_key)
              |> RecordApiRequest.call([])
              |> send_resp(200, "ok")

            assert response(conn, 200) == "ok"
          end)

        assert log =~ "Failed to record API request"
        assert recorded_entries(team) == []
      end
    end

    defp api_conn(api_key) do
      put_req_header(build_conn(), "authorization", "Bearer #{api_key.key}")
    end

    defp v2_query(site, overrides \\ %{}) do
      Map.merge(
        %{"site_id" => site.domain, "metrics" => ["pageviews"], "date_range" => "all"},
        overrides
      )
    end

    defp v1_aggregate(site) do
      %{"site_id" => site.domain, "metrics" => "pageviews"}
    end

    defp recorded_entries(team) do
      WriteBuffer.flush()

      from(e in Entry, where: e.team_id == ^team.id)
      |> Plausible.ClickhouseRepo.all()
    end

    defp recorded_entries_of(api_key) do
      WriteBuffer.flush()

      from(e in Entry, where: e.credential_type == "api_key" and e.credential_id == ^api_key.id)
      |> Plausible.ClickhouseRepo.all()
    end
  end
end
