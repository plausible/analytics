defmodule Plausible.Stats.DashboardQueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.DashboardQueryParser
  alias Plausible.Stats.ParsedQueryParams

  test "parses an empty query string" do
    {:ok, parsed} = parse("")

    expected = %Plausible.Stats.ParsedQueryParams{
      input_date_range: nil,
      relative_date: nil,
      metrics: nil,
      filters: [],
      dimensions: nil,
      order_by: nil,
      pagination: nil,
      include: nil
    }

    assert parsed == expected
  end

  describe "period -> input_date_range" do
    for period <- [:realtime, :day, :month, :year, :all] do
      test "parses #{period} period" do
        {:ok, parsed} = parse("?period=#{Atom.to_string(unquote(period))}")
        assert_matches %ParsedQueryParams{input_date_range: ^unquote(period)} = parsed
      end
    end

    for i <- [7, 28, 30, 91] do
      test "parses #{i}d period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}d")
        assert_matches %ParsedQueryParams{input_date_range: {:last_n_days, ^unquote(i)}} = parsed
      end
    end

    for i <- [6, 12] do
      test "parses #{i}mo period" do
        {:ok, parsed} = parse("?period=#{unquote(i)}mo")

        assert_matches %ParsedQueryParams{input_date_range: {:last_n_months, ^unquote(i)}} =
                         parsed
      end
    end

    test "parses custom period" do
      {:ok, parsed} = parse("?period=custom&from=2021-01-01&to=2021-03-05")

      assert %ParsedQueryParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
             } = parsed
    end

    test "defaults to nil when period param is invalid" do
      {:ok, parsed} = parse("?period=abcde")

      assert %ParsedQueryParams{
               input_date_range: nil
             } = parsed
    end
  end

  describe "date -> relative_date" do
    test "parses a valid iso8601 date string" do
      {:ok, parsed} = parse("?date=2021-05-05")
      assert %ParsedQueryParams{relative_date: ~D[2021-05-05]} = parsed
    end

    test "errors when invalid date" do
      {:error, :invalid_date} = parse("?date=2021-13-32")
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
               ]
             } = parsed
    end

    test "errors when filter decoding fails" do
      assert {:error, :invalid_filters} = parse("?f=is,page,/&f=what")
    end
  end
end
