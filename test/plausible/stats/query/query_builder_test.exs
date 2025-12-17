defmodule Plausible.Stats.QueryBuilderTest do
  use Plausible.DataCase
  alias Plausible.Stats.{DateTimeRange, ParsedQueryParams, QueryBuilder, Query}

  @now DateTime.new!(~D[2021-05-05], ~T[12:30:00], "Etc/UTC")
  @date_range_realtime %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[12:25:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[12:30:05], "Etc/UTC")
  }
  @date_range_30m %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[12:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[12:30:05], "Etc/UTC")
  }

  setup [:create_user, :create_site]

  setup do
    Plausible.Stats.Query.Test.fix_now(@now)
    :ok
  end

  describe "filter validation" do
    test "event goal name is checked within behavioral filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %ParsedQueryParams{
        metrics: [:visitors],
        input_date_range: :all,
        filters: [[:has_done, [:is, "event:goal", ["Unknown"]]]]
      }

      assert {:error, error} = QueryBuilder.build(site, params)

      assert error ==
               "Invalid filters. The goal `Unknown` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end
  end

  describe "date range" do
    for {input_date_range, expected_utc_time_range} <- [
          {:realtime, @date_range_realtime},
          {:realtime_30m, @date_range_30m}
        ] do
      test "builds utc_time_range for #{input_date_range} input_date_range", %{site: site} do
        assert {:ok, query} =
                 QueryBuilder.build(site, %ParsedQueryParams{
                   metrics: [:visitors],
                   input_date_range: unquote(input_date_range)
                 })

        assert query.utc_time_range == unquote(Macro.escape(expected_utc_time_range))
      end
    end
  end
end
