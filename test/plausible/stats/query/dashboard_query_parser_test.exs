defmodule Plausible.Stats.DashboardQueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.DashboardQueryParser
  alias Plausible.Stats.ParsedQueryParams

  @default_include default_include()

  test "parses an empty query string" do
    {:ok, parsed} = parse("")

    expected = %Plausible.Stats.ParsedQueryParams{
      input_date_range: nil,
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
        {:ok, parsed} = parse("?period=#{Atom.to_string(unquote(period))}")

        assert_matches %ParsedQueryParams{
                         input_date_range: ^unquote(period),
                         include: ^@default_include
                       } = parsed
      end
    end

    for i <- [7, 28, 30, 91] do
      test "parses #{i}d period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}d")

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_days, ^unquote(i)},
                         include: ^@default_include
                       } = parsed
      end
    end

    for i <- [6, 12] do
      test "parses #{i}mo period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}mo")

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_months, ^unquote(i)},
                         include: ^@default_include
                       } =
                         parsed
      end
    end

    test "parses custom period" do
      {:ok, parsed} = parse("?period=custom&from=2021-01-01&to=2021-03-05")

      assert %ParsedQueryParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]},
               include: @default_include
             } = parsed
    end

    test "defaults to nil when period param is invalid" do
      {:ok, parsed} = parse("?period=abcde")

      assert %ParsedQueryParams{
               input_date_range: nil,
               include: @default_include
             } = parsed
    end
  end

  describe "date -> relative_date" do
    test "parses a valid iso8601 date string" do
      {:ok, parsed} = parse("?date=2021-05-05")
      assert %ParsedQueryParams{relative_date: ~D[2021-05-05], include: @default_include} = parsed
    end

    test "errors when invalid date" do
      {:error, :invalid_date} = parse("?date=2021-13-32")
    end
  end

  describe "with_imported -> include.imports" do
    test "true -> true" do
      {:ok, parsed} = parse("?with_imported=true")
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "invalid -> true" do
      {:ok, parsed} = parse("?with_imported=foo")
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "false -> false" do
      {:ok, parsed} = parse("?with_imported=false")
      expected_include = Map.put(@default_include, :imports, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end
  end

  describe "comparison -> include.compare" do
    for mode <- [:previous_period, :year_over_year] do
      test "parses #{mode} mode" do
        {:ok, parsed} = parse("?comparison=#{unquote(mode)}")
        expected_include = Map.put(@default_include, :compare, unquote(mode))
        assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
      end
    end

    test "parses custom date range mode" do
      {:ok, parsed} = parse("?comparison=custom&compare_from=2021-01-01&compare_to=2021-04-30")

      expected_include =
        Map.put(@default_include, :compare, {:date_range, ~D[2021-01-01], ~D[2021-04-30]})

      assert_matches %ParsedQueryParams{include: ^expected_include} = parsed
    end

    test "invalid -> nil" do
      {:ok, parsed} = parse("?comparison=invalid_mode")
      assert %ParsedQueryParams{include: @default_include} = parsed
    end
  end

  describe "match_day_of_week -> include.compare_match_day_of_week" do
    test "true -> true" do
      {:ok, parsed} = parse("?match_day_of_week=true")
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "invalid -> true" do
      {:ok, parsed} = parse("?match_day_of_week=foo")
      assert %ParsedQueryParams{include: @default_include} = parsed
    end

    test "false -> false" do
      {:ok, parsed} = parse("?match_day_of_week=false")
      expected_include = Map.put(@default_include, :compare_match_day_of_week, false)
      assert %ParsedQueryParams{include: ^expected_include} = parsed
    end
  end

  describe "filters" do
    test "parses valid filters" do
      {:ok, parsed} =
        parse("?f=is,exit_page,/:dashboard&f=is,source,Bing&f=is,props:theme,system")

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
        parse("?f=is,city,2988507,2950159")

      assert %ParsedQueryParams{
               filters: [[:is, "visit:city", [2_988_507, 2_950_159]]],
               include: @default_include
             } = parsed
    end

    test "parses a segment filter" do
      {:ok, parsed} = parse("?f=is,segment,123")

      assert %ParsedQueryParams{
               filters: [[:is, "segment", [123]]],
               include: @default_include
             } = parsed
    end

    test "errors when filter structure is wrong" do
      assert {:error, :invalid_filters} = parse("?f=is,page,/&f=what")
    end

    test "errors when city filter cannot be parsed to integer" do
      assert {:error, :invalid_filters} = parse("?f=is,city,Berlin")
    end

    test "errors when segment filter cannot be parsed to integer" do
      assert {:error, :invalid_filters} = parse("?f=is,segment,MySegment")
    end
  end
end
