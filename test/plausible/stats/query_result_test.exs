defmodule Plausible.Stats.QueryResultTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.{Query, QueryResult, QueryOptimizer}

  setup do
    user = insert(:user)

    site =
      insert(:site,
        members: [user],
        inserted_at: ~N[2020-01-01T00:00:00],
        stats_start_date: ~D[2020-01-01]
      )

    {:ok, site: site}
  end

  test "serializing query to JSON keeps keys ordered" do
    site = insert(:site)

    {:ok, query} =
      Query.build(
        site,
        :public,
        %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2024-01-01", "2024-02-01"],
          "include" => %{"imports" => true}
        },
        %{}
      )

    query = QueryOptimizer.optimize(query)

    query_result_json =
      QueryResult.from([], site, query, %{})
      |> Jason.encode!(pretty: true)
      |> String.replace(site.domain, "dummy.site")

    assert query_result_json == """
           {
             "results": [],
             "meta": {
               "imports_included": false,
               "imports_skip_reason": "no_imported_data"
             },
             "query": {
               "site_id": "dummy.site",
               "metrics": [
                 "pageviews"
               ],
               "date_range": [
                 "2024-01-01T00:00:00+00:00",
                 "2024-02-01T23:59:59+00:00"
               ],
               "filters": [],
               "dimensions": [],
               "order_by": [
                 [
                   "pageviews",
                   "desc"
                 ]
               ],
               "include": {
                 "imports": true
               },
               "pagination": {
                 "offset": 0,
                 "limit": 10000
               }
             }
           }\
           """
  end
end
