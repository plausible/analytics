defmodule Plausible.Google.Api.VCRTest do
  use Plausible.DataCase, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch
  require Ecto.Query

  import Mox

  setup [:create_user, :create_site]
  # We need real HTTP Client for VCR tests
  # setup_patch_env(:http_impl, Plausible.HTTPClient)

  # @tag :slow
  test "imports page views from Google Analytics", %{site: site} do
    # use_cassette "google_analytics_import#1", match_requests_on: [:request_body] do
    #
    mocks =
      Jason.decode!(File.read!("fixture/http_mocks/google_analytics_import#1.json"))

    mocks =
      Enum.into(mocks, %{}, &{{&1["url"], &1["request_body"]}, &1})

    stub(
      Plausible.HTTPClient.Mock,
      :post,
      fn url, _, params, _ ->
        params = params |> Jason.encode!() |> Jason.decode!()
        assert mock = Map.get(mocks, {url, params})

        {:ok,
         %Finch.Response{
           status: 200,
           headers: [{"content-type", "application/json"}],
           body: mock["response_body"]
         }}
      end
    )

    view_id = "54297898"
    date_range = Date.range(~D[2011-01-01], ~D[2022-07-19])

    future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()
    auth = {"***", "refresh_token", future}

    assert :ok == Plausible.Google.Api.import_analytics(site, date_range, view_id, auth)
    assert 1_495_150 == Plausible.Stats.Clickhouse.imported_pageview_count(site)
    # end
  end
end
