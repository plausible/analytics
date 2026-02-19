defmodule PlausibleWeb.Api.StatsController.InternalQueryApiTest do
  use PlausibleWeb.ConnCase

  defp do_query_success(conn, site, params) do
    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  setup [:create_user, :log_in, :create_site]

  describe "aggregates (e.g. top stats)" do
    test "returns empty metrics when no data", %{conn: conn, site: site} do
      requested_metrics = [
        "visitors",
        "visits",
        "pageviews",
        "views_per_visit",
        "bounce_rate",
        "visit_duration"
      ]

      params = %{
        "date_range" => "all",
        "filters" => [],
        "metrics" => requested_metrics
      }

      response = do_query_success(conn, site, params)

      assert response["query"]["metrics"] == requested_metrics
      assert response["results"] == [%{"dimensions" => [], "metrics" => [0, 0, 0, 0.0, 0, 0]}]
    end

    test "returns information about imports with the imports_meta option", %{
      conn: conn,
      site: site
    } do
      params = %{
        "date_range" => "all",
        "filters" => [],
        "metrics" => ["visitors"],
        "include" => %{"imports" => false, "imports_meta" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["meta"] == %{
               "imports_included" => false,
               "imports_skip_reason" => "no_imported_data"
             }
    end

    test "drops time on page if unavailable", %{conn: conn, site: site} do
      site_import =
        insert(:site_import, site: site, start_date: ~D[2021-01-01], end_date: ~D[2022-01-01])

      site = Plausible.Sites.update_legacy_time_on_page_cutoff!(site, ~D[2023-01-01])

      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/"),
        build(:imported_pages, page: "/", date: ~D[2021-01-01])
      ])

      params = %{
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]],
        "metrics" => ["visitors", "time_on_page"],
        "include" => %{"imports" => true, "drop_unavailable_time_on_page" => true}
      }

      response = do_query_success(conn, site, params)

      assert response["meta"]["imports_included"]
      assert response["query"]["metrics"] == ["visitors"]
      assert response["results"] == [%{"dimensions" => [], "metrics" => [2]}]
    end
  end
end
