defmodule Plausible.Stats.Dashboard.QueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.Dashboard.QueryParser
  alias Plausible.Stats.ParsedQueryParams

  @default_include default_include()

  @yesterday NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-1, :day)
  @before_yesterday @yesterday |> NaiveDateTime.add(-1, :day)

  test "parses an empty query string" do
    {:ok, parsed} = parse("", build(:site), %{})

    expected = %Plausible.Stats.ParsedQueryParams{
      input_date_range: {:last_n_days, 28},
      relative_date: nil,
      metrics: [],
      filters: [],
      dimensions: [],
      order_by: nil,
      pagination: nil,
      include: default_include()
    }

    assert parsed == expected
  end

  describe "period -> input_date_range" do
    for period <- [:realtime, :day, :month, :year, :all] do
      test "parses #{period} period" do
        {:ok, parsed} = parse("?period=#{Atom.to_string(unquote(period))}", build(:site), %{})
        assert_matches %ParsedQueryParams{input_date_range: ^unquote(period)} = parsed
      end

      test "parses #{period} period from user prefs" do
        {:ok, parsed} = parse("", build(:site), %{"period" => Atom.to_string(unquote(period))})
        assert_matches %ParsedQueryParams{input_date_range: ^unquote(period)} = parsed
      end
    end

    for i <- [7, 28, 30, 91] do
      test "parses #{i}d period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}d", build(:site), %{})

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_days, ^unquote(i)}
                       } = parsed
      end

      test "parses #{i}d period from user_prefs" do
        {:ok, parsed} = parse("", build(:site), %{"period" => "#{unquote(i)}d"})

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_days, ^unquote(i)}
                       } = parsed
      end
    end

    for i <- [6, 12] do
      test "parses #{i}mo period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}mo", build(:site), %{})

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_months, ^unquote(i)}
                       } =
                         parsed
      end

      test "parses #{i}mo period from user prefs" do
        {:ok, parsed} = parse("", build(:site), %{"period" => "#{unquote(i)}mo"})

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_months, ^unquote(i)}
                       } =
                         parsed
      end
    end

    test "parses custom period" do
      {:ok, parsed} = parse("?period=custom&from=2021-01-01&to=2021-03-05", build(:site), %{})

      assert %ParsedQueryParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
             } = parsed
    end

    test "falls back to last 28 days when site created before yesterday" do
      site = build(:site, native_stats_start_at: @before_yesterday)
      {:ok, parsed} = parse("", site, %{})
      assert %ParsedQueryParams{input_date_range: {:last_n_days, 28}} = parsed
    end

    test "falls back to :day for a recently created site" do
      site = build(:site, native_stats_start_at: @yesterday)
      {:ok, parsed} = parse("", site, %{})
      assert %ParsedQueryParams{input_date_range: :day} = parsed
    end

    test "falls back to valid user preference" do
      {:ok, parsed} = parse("", build(:site), %{"period" => "year"})
      assert %ParsedQueryParams{input_date_range: :year} = parsed
    end

    test "falls back to valid user preference when period in query string is invalid" do
      {:ok, parsed} = parse("?period=invalid", build(:site), %{"period" => "month"})
      assert %ParsedQueryParams{input_date_range: :month} = parsed
    end

    test "valid period param in query string takes precedence over valid user preference" do
      {:ok, parsed} = parse("?period=all", build(:site), %{"period" => "month"})
      assert %ParsedQueryParams{input_date_range: :all} = parsed
    end

    test "falls back to site default when both query string and user preference period are invalid" do
      site = build(:site, native_stats_start_at: @yesterday)
      {:ok, parsed} = parse("?period=invalid", site, %{"period" => "invalid"})
      assert %ParsedQueryParams{input_date_range: :day} = parsed
    end
  end

  describe "date -> relative_date" do
    test "parses a valid iso8601 date string" do
      {:ok, parsed} = parse("?date=2021-05-05", build(:site), %{})
      assert %ParsedQueryParams{relative_date: ~D[2021-05-05], include: @default_include} = parsed
    end

    test "errors when invalid date" do
      {:error, :invalid_date} = parse("?date=2021-13-32", build(:site), %{})
    end
  end

  describe "with_imported -> include.imports" do
    test "true -> true" do
      {:ok, parsed} = parse("?with_imported=true", build(:site), %{})
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "invalid -> true" do
      {:ok, parsed} = parse("?with_imported=foo", build(:site), %{})
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "false -> false" do
      {:ok, parsed} = parse("?with_imported=false", build(:site), %{})
      expected_include = Map.put(@default_include, :imports, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end
  end

  describe "comparison -> include.compare" do
    for mode <- [:previous_period, :year_over_year] do
      test "parses #{mode} mode" do
        {:ok, parsed} = parse("?comparison=#{unquote(mode)}", build(:site), %{})
        expected_include = Map.put(@default_include, :compare, unquote(mode))
        assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
      end

      test "parses #{mode} mode from user prefs" do
        {:ok, parsed} = parse("", build(:site), %{"comparison" => "#{unquote(mode)}"})
        expected_include = Map.put(@default_include, :compare, unquote(mode))
        assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
      end
    end

    test "parses custom date range mode" do
      {:ok, parsed} =
        parse(
          "?comparison=custom&compare_from=2021-01-01&compare_to=2021-04-30",
          build(:site),
          %{}
        )

      expected_include =
        Map.put(@default_include, :compare, {:date_range, ~D[2021-01-01], ~D[2021-04-30]})

      assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "custom comparison in query string takes precedence over user prefs" do
      {:ok, parsed} =
        parse(
          "?comparison=custom&compare_from=2021-01-01&compare_to=2021-04-30",
          build(:site),
          %{"comparison" => "year_over_year"}
        )

      expected_include =
        Map.put(@default_include, :compare, {:date_range, ~D[2021-01-01], ~D[2021-04-30]})

      assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "falls back to user preference when query string comparison param is invalid" do
      {:ok, parsed} =
        parse("?comparison=invalid_mode", build(:site), %{"comparison" => "previous_period"})

      expected_include =
        Map.put(@default_include, :compare, :previous_period)

      assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "comparison=off in query string skips stored comparison mode" do
      {:ok, parsed} =
        parse("?comparison=off", build(:site), %{"comparison" => "previous_period"})

      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "falls back to nil when comparison param in both query string and user prefs is invalid" do
      {:ok, parsed} =
        parse("?comparison=invalid_mode", build(:site), %{"comparison" => "invalid_mode"})

      assert %ParsedQueryParams{include: @default_include} = parsed
    end
  end

  describe "match_day_of_week -> include.compare_match_day_of_week" do
    test "true -> true" do
      {:ok, parsed} = parse("?match_day_of_week=true", build(:site), %{})
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "invalid -> true" do
      {:ok, parsed} = parse("?match_day_of_week=foo", build(:site), %{})
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "false -> false" do
      {:ok, parsed} = parse("?match_day_of_week=false", build(:site), %{})
      expected_include = Map.put(@default_include, :compare_match_day_of_week, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "'true' in query string takes precedence over 'false' in user prefs" do
      {:ok, parsed} =
        parse("?match_day_of_week=true", build(:site), %{"match_day_of_week" => "false"})

      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "'false' in query string takes precedence over 'true' in user prefs" do
      {:ok, parsed} =
        parse("?match_day_of_week=false", build(:site), %{"match_day_of_week" => "true"})

      expected_include = Map.put(@default_include, :compare_match_day_of_week, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "falls back to user pref when value in query string is invalid" do
      {:ok, parsed} =
        parse("?match_day_of_week=foo", build(:site), %{"match_day_of_week" => "false"})

      expected_include = Map.put(@default_include, :compare_match_day_of_week, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "falls back to 'true' when invalid values in both query string and user prefs" do
      {:ok, parsed} =
        parse("?match_day_of_week=foo", build(:site), %{"match_day_of_week" => "bar"})

      assert %ParsedQueryParams{include: @default_include} = parsed
    end
  end

  describe "filters" do
    test "parses valid filters" do
      {:ok, parsed} =
        parse(
          "?f=is,exit_page,/:dashboard&f=is,source,Bing&f=is,props:theme,system",
          build(:site),
          %{}
        )

      assert %ParsedQueryParams{
               filters: [
                 [:is, "visit:exit_page", ["/:dashboard"]],
                 [:is, "visit:source", ["Bing"]],
                 [:is, "event:props:theme", ["system"]]
               ],
               include: @default_include
             } = parsed
    end

    test "parses city filter with multiple clauses" do
      {:ok, parsed} =
        parse("?f=is,city,2988507,2950159", build(:site), %{})

      assert %ParsedQueryParams{
               filters: [[:is, "visit:city", [2_988_507, 2_950_159]]],
               include: @default_include
             } = parsed
    end

    test "parses a segment filter" do
      {:ok, parsed} = parse("?f=is,segment,123", build(:site), %{})

      assert %ParsedQueryParams{
               filters: [[:is, "segment", [123]]],
               include: @default_include
             } = parsed
    end

    test "errors when filter structure is wrong" do
      assert {:error, :invalid_filters} = parse("?f=is,page,/&f=what", build(:site), %{})
    end

    test "errors when city filter cannot be parsed to integer" do
      assert {:error, :invalid_filters} = parse("?f=is,city,Berlin", build(:site), %{})
    end

    test "errors when segment filter cannot be parsed to integer" do
      assert {:error, :invalid_filters} = parse("?f=is,segment,MySegment", build(:site), %{})
    end
  end
end
