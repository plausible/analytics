defmodule PlausibleWeb.Api.ExternalStatsController.QueryConsolidatedViewTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  @moduletag :ee_only

  setup [:create_user, :create_team, :create_site, :create_api_key, :use_api_key]

  test "simple aggregate query across all consolidated site_ids", %{
    team: team,
    site: site,
    conn: conn
  } do
    another_site = new_site(team: team)
    cv = new_consolidated_view(team)

    cv
    |> Ecto.Changeset.change(%{native_stats_start_at: ~N[2020-01-01 12:00:00]})
    |> Plausible.Repo.update!()

    populate_stats(site, [build(:pageview)])
    populate_stats(another_site, [build(:pageview)])

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => cv.domain,
        "date_range" => "all",
        "metrics" => ["visitors"]
      })

    assert %{"results" => [%{"metrics" => [2]}]} = json_response(conn, 200)
  end
end
