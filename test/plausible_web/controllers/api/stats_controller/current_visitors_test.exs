defmodule PlausibleWeb.Api.StatsController.CurrentVisitorsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/current-visitors" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique users in the last 5 minutes", %{conn: conn, site: site} do
      now = DateTime.utc_now()

      populate_stats(site, [
        build(:pageview, user_id: 123, timestamp: now |> DateTime.shift(minute: -3)),
        build(:pageview, user_id: 456, timestamp: now |> DateTime.shift(minute: -3)),
        build(:pageview, user_id: 123, timestamp: now |> DateTime.shift(minute: -1)),
        build(:pageview, user_id: 789, timestamp: now |> DateTime.shift(minute: -7)),
        build(:engagement, user_id: 789, timestamp: now |> DateTime.shift(minute: -3))
      ])

      conn = get(conn, "/api/stats/#{site.domain}/current-visitors")

      assert json_response(conn, 200) == 2
    end

    test "does not load site imports, subscription or owners", %{conn: conn, site: site} do
      attach_repo_query_listener()

      conn = get(conn, "/api/stats/#{site.domain}/current-visitors")

      assert json_response(conn, 200) == 0
      refute_received {:repo_query, "site_imports"}
      refute_received {:repo_query, "subscriptions"}
      refute_received {:repo_query, "team_memberships"}
    end

    on_ee do
      test "returns unique users across all sites of a consolidated view", %{
        conn: conn,
        site: site
      } do
        another_site = new_site(team: site.team)
        consolidated_view = new_consolidated_view(site.team)
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview, user_id: 123, timestamp: now |> DateTime.shift(minute: -1))
        ])

        populate_stats(another_site, [
          build(:pageview, user_id: 456, timestamp: now |> DateTime.shift(minute: -1))
        ])

        conn = get(conn, "/api/stats/#{consolidated_view.domain}/current-visitors")

        assert json_response(conn, 200) == 2
      end
    end
  end

  defp attach_repo_query_listener do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach(
      handler_id,
      [:plausible, :repo, :query],
      fn _event, _measurements, metadata, _config ->
        if self() == test_pid or test_pid in Process.get(:"$callers", []) do
          send(test_pid, {:repo_query, metadata.source})
        end
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
