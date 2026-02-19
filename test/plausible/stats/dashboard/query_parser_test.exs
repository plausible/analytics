defmodule Plausible.Stats.Dashboard.QueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.Dashboard.QueryParser
  alias Plausible.Stats.{ParsedQueryParams, QueryError}

  @base_params %{
    "date_range" => "28d",
    "relative_date" => nil,
    "filters" => [],
    "dimensions" => [],
    "metrics" => ["visitors"],
    "include" => %{
      "imports" => true,
      "imports_meta" => false,
      "compare" => nil,
      "compare_match_day_of_week" => true
    }
  }

  describe "input_date_range" do
    test "is required" do
      params = Map.drop(@base_params, ["date_range"])
      assert {:error, %QueryError{code: :invalid_date_range}} = parse(params)
    end

    for period <- [:realtime, :day, :month, :year, :all] do
      test "parses #{period} date_range" do
        params = Map.merge(@base_params, %{"date_range" => Atom.to_string(unquote(period))})
        {:ok, parsed} = parse(params)
        assert_matches %ParsedQueryParams{input_date_range: ^unquote(period)} = parsed
      end
    end

    for i <- [7, 28, 30, 91] do
      test "parses #{i}d date_range" do
        params = Map.merge(@base_params, %{"date_range" => "#{unquote(i)}d"})
        {:ok, parsed} = parse(params)

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_days, ^unquote(i)}
                       } = parsed
      end
    end

    test "parses 24h period" do
      params = Map.merge(@base_params, %{"date_range" => "24h"})
      {:ok, parsed} = parse(params)
      assert_matches %ParsedQueryParams{input_date_range: :"24h"} = parsed
    end

    for i <- [6, 12] do
      test "parses #{i}mo date_range" do
        params = Map.merge(@base_params, %{"date_range" => "#{unquote(i)}mo"})
        {:ok, parsed} = parse(params)

        assert_matches %ParsedQueryParams{
                         input_date_range: {:last_n_months, ^unquote(i)}
                       } =
                         parsed
      end
    end

    test "parses custom date_range" do
      params = Map.merge(@base_params, %{"date_range" => ["2021-01-01", "2021-03-05"]})
      {:ok, parsed} = parse(params)

      assert %ParsedQueryParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
             } = parsed
    end
  end

  describe "relative_date" do
    test "parses a valid iso8601 date string" do
      params = Map.merge(@base_params, %{"relative_date" => "2021-05-05"})
      {:ok, parsed} = parse(params)
      assert %ParsedQueryParams{relative_date: ~D[2021-05-05]} = parsed
    end

    test "nil is accepted" do
      params = Map.merge(@base_params, %{"relative_date" => nil})
      {:ok, parsed} = parse(params)
      assert %ParsedQueryParams{relative_date: nil} = parsed
    end

    test "errors when invalid date" do
      params = Map.merge(@base_params, %{"relative_date" => "2021-13-32"})
      {:error, %QueryError{code: :invalid_relative_date}} = parse(params)
    end
  end

  describe "include.imports" do
    test "true -> true" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => true}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == true
    end

    test "invalid -> true" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => "foo"}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == true
    end

    test "false -> false" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => false}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == false
    end
  end

  describe "include.compare" do
    for mode <- [:previous_period, :year_over_year] do
      test "parses #{mode} mode" do
        params = %{
          @base_params
          | "include" => %{@base_params["include"] | "compare" => "#{unquote(mode)}"}
        }

        {:ok, parsed} = parse(params)
        assert parsed.include.compare == unquote(mode)
      end
    end

    test "parses custom date range mode" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => ["2021-01-01", "2021-04-30"]}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare == {:date_range, ~D[2021-01-01], ~D[2021-04-30]}
    end

    test "fails with invalid custom dates" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => ["2021-13-01", "2021-04-30"]}
      }

      assert {:error, %QueryError{code: :invalid_include}} = parse(params)
    end

    test "fails with random invalid compare value" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => "foo"}
      }

      assert {:error, %QueryError{code: :invalid_include}} = parse(params)
    end

    test "compare is nil if not provided" do
      params = %{
        @base_params
        | "include" => Map.drop(@base_params["include"], ["compare"])
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare == nil
    end
  end

  describe "include.compare_match_day_of_week" do
    test "true -> true" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => true}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == true
    end

    test "invalid -> true" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => "foo"}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == true
    end

    test "false -> false" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => false}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == false
    end
  end

  describe "filters" do
    test "parses valid filters" do
      params =
        Map.merge(@base_params, %{
          "filters" => [
            ["has_not_done", ["is", "event:goal", ["Signup"]]],
            ["contains", "visit:exit_page", ["/:dashboard"]],
            ["is", "visit:source", ["Bing"]],
            ["is_not", "event:props:theme", ["system", "(none)"]]
          ]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [
               [:has_not_done, [:is, "event:goal", ["Signup"]]],
               [:contains, "visit:exit_page", ["/:dashboard"]],
               [:is, "visit:source", ["Bing"]],
               [:is_not, "event:props:theme", ["system", "(none)"]]
             ]
    end

    test "parses city filter with multiple clauses" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "visit:city", ["2988507", "2950159"]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "visit:city", ["2988507", "2950159"]]]
    end

    test "parses a segment filter" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "segment", [123]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "segment", [123]]]
    end
  end

  describe "metrics" do
    test "valid metrics" do
      params = Map.merge(@base_params, %{"metrics" => ["visitors", "group_conversion_rate"]})
      assert {:ok, parsed} = parse(params)
      assert parsed.metrics == [:visitors, :group_conversion_rate]
    end

    test "at least one metric required" do
      params = Map.merge(@base_params, %{"metrics" => []})
      assert {:error, %QueryError{code: :invalid_metrics}} = parse(params)
    end
  end
end
