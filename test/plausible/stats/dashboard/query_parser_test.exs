defmodule Plausible.Stats.Dashboard.QueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.Dashboard.QueryParser
  alias Plausible.Stats.ParsedQueryParams

  @base_params %{
    "period" => "28d",
    "comparison" => nil,
    "match_day_of_week" => true,
    "date" => nil,
    "from" => nil,
    "to" => nil,
    "compare_from" => nil,
    "compare_to" => nil,
    "filters" => [],
    "with_imported" => true,
    "include_imports_meta" => false,
    "dimensions" => [],
    "metrics" => ["visitors"]
  }

  describe "period -> input_date_range" do
    for period <- [:realtime, :day, :month, :year, :all] do
      test "parses #{period} period" do
        params = Map.merge(@base_params, %{"period" => Atom.to_string(unquote(period))})
        {:ok, parsed} = parse(params)
        assert_matches %ParsedQueryParams{input_date_range: ^unquote(period)} = parsed
      end
    end

    for i <- [7, 28, 30, 91] do
      test "parses #{i}d period" do
        params = Map.merge(@base_params, %{"period" => "#{unquote(i)}d"})
        {:ok, parsed} = parse(params)

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_days, ^unquote(i)}
                       } = parsed
      end
    end

    for i <- [6, 12] do
      test "parses #{i}mo period" do
        params = Map.merge(@base_params, %{"period" => "#{unquote(i)}mo"})
        {:ok, parsed} = parse(params)

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_months, ^unquote(i)}
                       } =
                         parsed
      end
    end

    test "parses custom period" do
      params =
        Map.merge(@base_params, %{
          "period" => "custom",
          "from" => "2021-01-01",
          "to" => "2021-03-05"
        })

      {:ok, parsed} = parse(params)

      assert %ParsedQueryParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
             } = parsed
    end
  end

  describe "date -> relative_date" do
    test "parses a valid iso8601 date string" do
      params = Map.merge(@base_params, %{"date" => "2021-05-05"})
      {:ok, parsed} = parse(params)
      assert %ParsedQueryParams{relative_date: ~D[2021-05-05]} = parsed
    end

    test "nil is accepted" do
      params = Map.merge(@base_params, %{"date" => nil})
      {:ok, parsed} = parse(params)
      assert %ParsedQueryParams{relative_date: nil} = parsed
    end

    test "errors when invalid date" do
      params = Map.merge(@base_params, %{"date" => "2021-13-32"})
      {:error, :invalid_date} = parse(params)
    end
  end

  describe "with_imported -> include.imports" do
    test "true -> true" do
      params = Map.merge(@base_params, %{"with_imported" => true})
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == true
    end

    test "invalid -> true" do
      params = Map.merge(@base_params, %{"with_imported" => "foo"})
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == true
    end

    test "false -> false" do
      params = Map.merge(@base_params, %{"with_imported" => false})
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == false
    end
  end

  describe "comparison -> include.compare" do
    for mode <- [:previous_period, :year_over_year] do
      test "parses #{mode} mode" do
        params = Map.merge(@base_params, %{"comparison" => "#{unquote(mode)}"})
        {:ok, parsed} = parse(params)
        assert parsed.include.compare == unquote(mode)
      end
    end

    test "parses custom date range mode" do
      params =
        Map.merge(@base_params, %{
          "comparison" => "custom",
          "compare_from" => "2021-01-01",
          "compare_to" => "2021-04-30"
        })

      {:ok, parsed} = parse(params)
      assert parsed.include.compare == {:date_range, ~D[2021-01-01], ~D[2021-04-30]}
    end

    test "falls back to nil when comparison param is invalid" do
      params = Map.merge(@base_params, %{"comparison" => "invalid_mode"})
      {:ok, parsed} = parse(params)
      assert parsed.include.compare == nil
    end
  end

  describe "match_day_of_week -> include.compare_match_day_of_week" do
    test "true -> true" do
      params = Map.merge(@base_params, %{"match_day_of_week" => true})
      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == true
    end

    test "invalid -> true" do
      params = Map.merge(@base_params, %{"match_day_of_week" => "foo"})
      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == true
    end

    test "false -> false" do
      params = Map.merge(@base_params, %{"match_day_of_week" => false})
      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == false
    end
  end

  describe "filters" do
    test "parses valid filters" do
      params =
        Map.merge(@base_params, %{
          "filters" => [
            ["contains", "exit_page", ["/:dashboard"]],
            ["is", "source", ["Bing"]],
            ["is_not", "props:theme", ["system", "(none)"]]
          ]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [
               [:contains, "visit:exit_page", ["/:dashboard"]],
               [:is, "visit:source", ["Bing"]],
               [:is_not, "event:props:theme", ["system", "(none)"]]
             ]
    end

    test "parses city filter with multiple clauses" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "city", ["2988507", "2950159"]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "visit:city", [2_988_507, 2_950_159]]]
    end

    test "parses a segment filter" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "segment", ["123"]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "segment", [123]]]
    end
  end
end
