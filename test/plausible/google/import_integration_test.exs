defmodule Plausible.Google.Api.ImportIntegrationTest do
  use Plausible.DataCase, async: false
  use Plausible.Test.Support.HTTPMocker

  require Ecto.Query

  setup [:create_user, :create_site]

  @tag :slow
  test "imports page views from Google Analytics", %{site: site} do
    mock_http_with("google_analytics_import#1.json")

    view_id = "54297898"
    date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

    future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
    auth = {"***", "refresh_token", future}

    assert :ok == Plausible.Google.Api.import_analytics(site, date_range, view_id, auth)
    assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
  end
end
