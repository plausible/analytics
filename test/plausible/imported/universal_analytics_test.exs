defmodule Plausible.Imported.UniversalAnalyticsTest do
  use Plausible.DataCase, async: true
  use Plausible.Test.Support.HTTPMocker

  alias Plausible.Imported.UniversalAnalytics

  setup [:create_user, :create_new_site]

  @tag :slow
  test "imports page views from Google Analytics", %{site: site} do
    mock_http_with("google_analytics_import#1.json")

    view_id = "54297898"
    date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

    future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
    auth = {"***", "refresh_token", future}

    assert :ok ==
             UniversalAnalytics.import(site, date_range: date_range, view_id: view_id, auth: auth)

    assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
  end
end
