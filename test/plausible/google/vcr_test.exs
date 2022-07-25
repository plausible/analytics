defmodule Plausible.Google.Api.VCRTest do
  use Plausible.DataCase, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch
  require Ecto.Query
  import Plausible.TestUtils

  setup [:create_user, :create_site]

  defp get_insert_count do
    Plausible.ClickhouseRepo.aggregate(
      from(ql in "query_log",
        prefix: "system",
        where: ql.query_kind == "Insert" and ql.is_initial_query == true
      ),
      :count
    )
  end

  test "imports page views from Google Analytics", %{site: site} do
    use_cassette "google_analytics_import#1", match_requests_on: [:request_body] do
      inserts_before_importing = get_insert_count()
      before_importing_timestamp = DateTime.utc_now()

      access_token = "***"
      view_id = "54297898"
      date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

      assert :ok == Plausible.Google.Api.import_analytics(site, date_range, view_id, access_token)

      total_seconds = DateTime.diff(DateTime.utc_now(), before_importing_timestamp, :second)
      total_inserts = get_insert_count() - inserts_before_importing

      assert total_inserts / total_seconds > 1.0,
             "should not call Clickhouse more than 1 time per second"

      assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
    end
  end
end
