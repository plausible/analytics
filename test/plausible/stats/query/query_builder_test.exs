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
  @date_range_day %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_7d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-28], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_10d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-25], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_30d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-05], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_month %DateTimeRange{
    first: DateTime.new!(~D[2021-05-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_3mo %DateTimeRange{
    first: DateTime.new!(~D[2021-02-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_6mo %DateTimeRange{
    first: DateTime.new!(~D[2020-11-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_year %DateTimeRange{
    first: DateTime.new!(~D[2021-01-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-12-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_12mo %DateTimeRange{
    first: DateTime.new!(~D[2020-05-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
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

    for operation <- [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not] do
      test "case_sensitive modifier is not valid for #{operation}", %{site: site} do
        assert {:error, error} =
                 QueryBuilder.build(site, %ParsedQueryParams{
                   metrics: [:visitors],
                   input_date_range: :all,
                   filters: [
                     [unquote(operation), "event:page", ["a"], %{case_insensitive: true}]
                   ]
                 })

        assert error =~ "Invalid filters."
        assert error =~ "case_sensitive modifier is not allowed with pattern operators"
        assert error =~ Atom.to_string(unquote(operation))
      end
    end

    test "prohibits case_sensitive modifier with pattern operator in a complex filter tree", %{
      site: site
    } do
      assert {:error, error} =
               QueryBuilder.build(site, %ParsedQueryParams{
                 metrics: [:visitors],
                 input_date_range: :all,
                 filters: [
                   [
                     :or,
                     [
                       [
                         :and,
                         [
                           [:is, "visit:city_name", ["London"]],
                           [:not, [:is, "visit:country_name", ["Canada"]]]
                         ]
                       ],
                       [:matches, "event:page", ["a"], %{case_insensitive: true}]
                     ]
                   ]
                 ]
               })

      assert error =~ "Invalid filters."
      assert error =~ "case_sensitive modifier is not allowed with pattern operators"
      assert error =~ ":matches"
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

    test "utc_time_range construction respects relative_date", %{site: site} do
      relative_date = @now |> DateTime.to_date()

      # Replace the fixed now. Otherwise this test could pass ignoring relative_date
      Plausible.Stats.Query.Test.fix_now(DateTime.utc_now(:second))

      for {date_range_shortcut, expected_utc_time_range} <- [
            {:day, @date_range_day},
            {{:last_n_days, 7}, @date_range_7d},
            {{:last_n_days, 10}, @date_range_10d},
            {{:last_n_days, 30}, @date_range_30d},
            {:month, @date_range_month},
            {{:last_n_months, 3}, @date_range_3mo},
            {{:last_n_months, 6}, @date_range_6mo},
            {{:last_n_months, 12}, @date_range_12mo},
            {:year, @date_range_year}
          ] do
        assert {:ok, query} =
                 QueryBuilder.build(site, %ParsedQueryParams{
                   metrics: [:visitors],
                   relative_date: relative_date,
                   input_date_range: date_range_shortcut
                 })

        assert query.utc_time_range == expected_utc_time_range
      end
    end
  end
end
